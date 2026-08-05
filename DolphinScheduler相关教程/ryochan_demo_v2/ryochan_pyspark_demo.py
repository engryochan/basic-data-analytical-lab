#!/usr/bin/env python3
"""ryochan_pyspark_demo.py

Modes
-----
smoke      lightweight connectivity check, no external I/O
s3         read + inspect a Parquet dataset from S3
starrocks  read + inspect a StarRocks table (READ ONLY, never writes)
ml         PCA -> KMeans -> XGBoost pipeline on a Parquet dataset from S3
all        run smoke + s3 + ml + starrocks in one Spark session

v2 changes vs. the original ryochan_pyspark_demo.py
-----------------------------------------------------
- `ml` is now its own explicit --mode value instead of being triggered
  implicitly whenever --s3-uri happens to be set alongside --mode smoke.
  The old code silently swapped the lightweight smoke test for the full
  ML pipeline under --mode all, which defeated the point of having a
  cheap smoke test.
- Corrected the XGBoost install note: xgboost>=1.7 ships the
  `xgboost.spark` module itself. There is no separate "xgboost-spark"
  package on PyPI.
- df_vec / df_pca are cached before the PCA/KMeans/XGBoost fan-out so the
  parquet read + VectorAssembler transform is not recomputed for every
  downstream .fit() call.
- Spark adaptive query execution (AQE) is enabled by default; override
  with --conf on the submit side if your cluster policy disagrees.
- run_starrocks() is documented as read-only. wm_live_risk is a
  colleague's reference schema -- do not add a write path against it.
"""
import argparse
import sys

from pyspark.sql import SparkSession, functions as F
from pyspark.ml.feature import VectorAssembler, PCA
from pyspark.ml.clustering import KMeans
from pyspark.ml.evaluation import MulticlassClassificationEvaluator
# xgboost>=1.7 ships the xgboost.spark module natively.
# Install with: pip install "xgboost>=1.7"
# (there is no separate "xgboost-spark" package on PyPI -- do not search
# for or try to install one, it does not exist)
from xgboost.spark import SparkXGBClassifier

REQUIRED_STARROCKS_KEYS = (
    "starrocks.fe.http.url",
    "starrocks.fe.jdbc.url",
    "starrocks.table.identifier",
    "starrocks.user",
    "starrocks.password",
)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--mode",
        choices=("smoke", "s3", "starrocks", "ml", "all"),
        default="smoke",
    )
    parser.add_argument("--s3-uri")
    parser.add_argument("--starrocks-properties")
    args = parser.parse_args()
    if args.mode in ("s3", "ml", "all") and not args.s3_uri:
        parser.error("--s3-uri is required for s3/ml/all")
    if args.mode in ("starrocks", "all") and not args.starrocks_properties:
        parser.error("--starrocks-properties is required for starrocks/all")
    return args


def read_properties(path):
    properties = {}
    with open(path, "r", encoding="utf-8") as source:
        for line in source:
            # Python's default text-mode open() already normalises
            # \r\n / \r / \n to \n (universal newlines), so this rstrip
            # is defensive rather than strictly required.
            line = line.rstrip("\r\n")
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                continue
            if "=" not in line:
                raise ValueError("StarRocks property must contain '='")
            raw_key, value = line.split("=", 1)
            key = raw_key.strip()
            if not key:
                raise ValueError("StarRocks property key must not be empty")
            if key in properties:
                raise ValueError("Duplicate StarRocks property key: {}".format(key))
            properties[key] = value
    unexpected = [key for key in properties if key not in REQUIRED_STARROCKS_KEYS]
    if unexpected:
        raise ValueError(
            "Unexpected StarRocks properties: {}".format(", ".join(unexpected))
        )
    missing = [key for key in REQUIRED_STARROCKS_KEYS if key not in properties]
    if missing:
        raise ValueError(
            "Missing required StarRocks properties: {}".format(", ".join(missing))
        )
    return properties


def inspect_frame(label, frame):
    print(label)
    frame.printSchema()
    print(frame.count())
    frame.show(10, truncate=True)


def run_machine_learning(spark, s3_uri):
    """PCA -> KMeans -> XGBoost demo pipeline.

    Assumes Parquet data at s3_uri has an 'id' and 'label' column plus
    numeric feature columns.
    """
    df = spark.read.parquet(s3_uri)
    df.printSchema()

    feature_cols = [c for c in df.columns if c not in ("id", "label")]

    assembler = VectorAssembler(inputCols=feature_cols, outputCol="features_vec")
    # Cached once: PCA.fit(), KMeans.fit(), and the later XGBoost .fit()
    # all derive from df_vec/df_pca. Without caching, Spark's lazy
    # evaluation re-reads the parquet and re-runs the assembler for
    # every one of those actions.
    df_vec = assembler.transform(df).cache()
    df_vec.count()  # materialise the cache before the fan-out below

    pca = PCA(k=5, inputCol="features_vec", outputCol="pca_features")
    pca_model = pca.fit(df_vec)
    df_pca = pca_model.transform(df_vec).cache()
    print("=== PCA Model Explained Variance ===")
    print(pca_model.explainedVariance)

    kmeans = KMeans(featuresCol="pca_features", k=3)
    kmeans_model = kmeans.fit(df_pca)
    df_cluster = kmeans_model.transform(df_pca)
    print("=== K-Means Cluster Centers ===")
    print(kmeans_model.clusterCenters())

    xgb = SparkXGBClassifier(
        features_col="pca_features",
        label_col="label",
        max_depth=6,
        n_estimators=50,
        num_workers=2,  # XGBoost trains in parallel across Spark tasks
    )
    train_data, test_data = df_cluster.randomSplit([0.8, 0.2], seed=42)
    xgb_model = xgb.fit(train_data)

    predictions = xgb_model.transform(test_data)
    evaluator = MulticlassClassificationEvaluator(
        labelCol="label", predictionCol="prediction", metricName="accuracy"
    )
    accuracy = evaluator.evaluate(predictions)
    print("=== XGBoost Test Accuracy ===")
    print(accuracy)

    df_vec.unpersist()
    df_pca.unpersist()


def run_smoke(spark):
    frame = spark.range(0, 8).withColumn("bucket", F.col("id") % 2).repartition(2)
    print(
        {
            "language": "python",
            "spark_version": spark.version,
            "python": sys.executable,
            "partitions": frame.rdd.getNumPartitions(),
        }
    )
    frame.groupBy("bucket").count().orderBy("bucket").show(truncate=False)


def run_s3(spark, uri):
    inspect_frame("s3", spark.read.parquet(uri))


def run_starrocks(spark, path):
    """READ ONLY. wm_live_risk is a colleague's reference schema; this
    function must never gain a .write/.save path against it. If you add
    a write path for your own output tables later, target your own
    schema explicitly and never reuse wm_live_risk."""
    properties = read_properties(path)
    reader = spark.read.format("starrocks")
    for key in REQUIRED_STARROCKS_KEYS:
        reader = reader.option(key, properties[key])
    inspect_frame("starrocks", reader.load())


def build_spark_session():
    return (
        SparkSession.builder.appName("pyspark-demo")
        .config("spark.sql.adaptive.enabled", "true")
        .config("spark.sql.adaptive.coalescePartitions.enabled", "true")
        .getOrCreate()
    )


def main():
    args = parse_args()
    spark = build_spark_session()
    try:
        if args.mode in ("smoke", "all"):
            run_smoke(spark)
        if args.mode in ("s3", "all"):
            run_s3(spark, args.s3_uri)
        if args.mode in ("ml", "all"):
            run_machine_learning(spark, args.s3_uri)
        if args.mode in ("starrocks", "all"):
            run_starrocks(spark, args.starrocks_properties)
    finally:
        spark.stop()


if __name__ == "__main__":
    main()
