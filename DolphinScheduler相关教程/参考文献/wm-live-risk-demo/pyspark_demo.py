#!/usr/bin/env python3
import argparse
import sys

from pyspark.sql import SparkSession, functions as F


REQUIRED_STARROCKS_KEYS = (
    "starrocks.fe.http.url",
    "starrocks.fe.jdbc.url",
    "starrocks.table.identifier",
    "starrocks.user",
    "starrocks.password",
)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=("smoke", "s3", "starrocks", "all"), default="smoke")
    parser.add_argument("--s3-uri")
    parser.add_argument("--starrocks-properties")
    args = parser.parse_args()
    if args.mode in ("s3", "all") and not args.s3_uri:
        parser.error("--s3-uri is required for s3/all")
    if args.mode in ("starrocks", "all") and not args.starrocks_properties:
        parser.error("--starrocks-properties is required for starrocks/all")
    return args


def read_properties(path):
    properties = {}
    with open(path, "r", encoding="utf-8") as source:
        for line in source:
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
        raise ValueError("Unexpected StarRocks properties: {}".format(", ".join(unexpected)))

    missing = [key for key in REQUIRED_STARROCKS_KEYS if key not in properties]
    if missing:
        raise ValueError("Missing required StarRocks properties: {}".format(", ".join(missing)))
    return properties


def inspect_frame(label, frame):
    print(label)
    frame.printSchema()
    print(frame.count())
    frame.show(10, truncate=True)


def run_smoke(spark):
    frame = spark.range(0, 8).withColumn("bucket", F.col("id") % 2).repartition(2)
    print({"language": "python", "spark_version": spark.version,
           "python": sys.executable, "partitions": frame.rdd.getNumPartitions()})
    frame.groupBy("bucket").count().orderBy("bucket").show(truncate=False)


def run_s3(spark, uri):
    inspect_frame("s3", spark.read.parquet(uri))


def run_starrocks(spark, path):
    properties = read_properties(path)
    reader = spark.read.format("starrocks")
    for key in REQUIRED_STARROCKS_KEYS:
        reader = reader.option(key, properties[key])
    inspect_frame("starrocks", reader.load())


def main():
    args = parse_args()
    spark = SparkSession.builder.appName("pyspark-livy-demo").getOrCreate()
    try:
        if args.mode in ("smoke", "all"):
            run_smoke(spark)
        if args.mode in ("s3", "all"):
            run_s3(spark, args.s3_uri)
        if args.mode in ("starrocks", "all"):
            run_starrocks(spark, args.starrocks_properties)
    finally:
        spark.stop()


if __name__ == "__main__":
    main()
