# ryochan_demo_v2 变更记录

对照上一轮核实结果逐项修正。**验证方式说明**：本环境没有 Rscript/Spark/StarRocks 集群，R
文件只做了括号配对的静态检查，没有真正跑过；Python 文件跑过 `py_compile`；两个
`.sh` 都跑过 `bash -n`。请按代码里保留的 smoke → s3 → starrocks → ml 顺序，先在测试环境
逐档跑一遍再上生产。

## 新增文件
- `ryochan_pyspark_submit.sh` —— 上一轮核实发现 `pyspark-demo` 节点的包装脚本要找一个叫
  `pyspark_submit.sh` 的资源文件，但压缩包里没有。这次补上，默认 `--method shell` 直接本机
  `spark-submit`，`--method livy` 时才走 Livy 批处理 API（两条路径共用一套参数校验）。

## 重命名
- `ryochan_sparkklyr.R` → `ryochan_sparklyr_coxph.R`（原文件名多打了一个 k；顺便给它一个
  说明其用途的名字，不再是容易和 `ryochan_sparklyr_demo.R` 混淆的相似文件名）。

## 架构改动（对应"SparkR 已落伍，改用 sparklyr"）
- `ryochan_sparklyr_submit.sh` 整个重写：不再拼 Livy 的 JSON payload 去打 `/batches`（那一套
  是原生 SparkR 把 R 文件整个当 Spark driver 启动的模型，`spark.r.command=Rscript` 那些痕迹
  就是证据）。sparklyr 自己已经实现了 Livy 协议，交给 R 脚本自己的 `spark_connect()` 处理更
  正确，也是 sparklyr 官方文档的建议做法。新脚本的职责缩小为：下载 `.R` 主文件和依赖 jar 到
  本地、导出环境变量，然后直接 `exec Rscript`。
- 连接方式（本机直连 yarn，还是走 Livy）现在由 `ryochan_sparklyr_demo.R` 内部读
  `SPARKLYR_CONNECT_METHOD`/`SPARKLYR_MASTER` 环境变量决定，默认 `shell`+`yarn`，对应你说的
  "现在直接在 DolphinScheduler 服务器上直连"。需要走 Livy 时设
  `SPARKLYR_CONNECT_METHOD=livy` 和 `SPARKLYR_MASTER=http://livy-host:8998` 即可，不用改代码。

## 安全 / 数据保护（对应"别篡改、覆盖现有数据表"和"wm-risk 只作参考"）
- `starrocks.properties`：密码换成占位符 `REPLACE_AFTER_ROTATING_CREDENTIAL`——上一轮那个
  真密码建议已经轮换过，这次不会再把明文密码打包进文件里；`starrocks.fe.http.url` 去掉了多
  余的 `http://` 前缀（StarRocks 官方文档格式是纯 `host:port`，`fe.jdbc.url` 那行的
  `jdbc:mysql://` 前缀是对的，两者规范不一样）。
- `ryochan_pyspark_demo.py` / `ryochan_sparklyr_demo.R` 的 `run_starrocks()`：注释里明确标注
  只读，不会新增任何写入路径。
- `ryochan_sparklyr_coxph.R`：这是这批文件里唯一真正做写入(`sdf_copy_to(..., overwrite=TRUE)`)
  的地方。新增 `REFUSED_WRITE_SCHEMAS <- c("wm_live_risk")` 和
  `refuse_protected_write_target()`，写入前会检查目标 schema，一旦指向 `wm_live_risk` 直接
  报错拒绝执行，不会静默覆盖同事的参考数据。输出表名默认
  `ryochan_demo.cox_predictions`（走环境变量 `RYOCHAN_PREDICTIONS_TABLE` 可改），和
  `wm_live_risk` 完全分开的命名空间。

## 正确性修正
- `ryochan_pyspark_demo.py`：
  - `--mode` 新增显式的 `ml`，不再靠"`smoke` 模式下 `--s3-uri` 是否恰好被传了"这种隐性判断
    去决定要不要跑 PCA/KMeans/XGBoost——原来这个隐性判断会导致 `--mode all` 时轻量 smoke
    测试被整套重型 ML 流水线顶替掉。
  - `pip install xgboost-spark` 的注释是错的，PyPI 上没有这个包；改成
    `pip install "xgboost>=1.7"`（1.7 起自带 `xgboost.spark` 模块）。
  - `run_machine_learning()` 里给 `df_vec`/`df_pca` 加了 `.cache()`，PCA/KMeans/XGBoost 三个
    `.fit()` 不会各自重新触发一遍 parquet 读取和 `VectorAssembler` 转换。
  - `SparkSession.builder` 默认开 AQE（`spark.sql.adaptive.enabled`）。
- `ryochan_sparklyr_demo.R`：
  - `run_s3()` 里原来注释写"演示 pysparklyr"，实际代码是纯 `reticulate`——两者不是一回事，
    注释已改正；顺手删掉了从未被用到的 `numpy` 导入。
  - 新增 `run_machine_learning()`（`--mode ml`），用 `sparkxgb` 包把 XGBoost 接进
    sparklyr，和 Python 那边的 PCA/KMeans/XGBoost 对齐。**这是全新代码，建议先单独
    smoke 测这一个模式，并确认你集群上 `sparkxgb`／`xgboost4j-spark` 的版本和 Spark
    主版本匹配**——我没有环境能替你实测这一段。
  - `read_properties()` 加了一行防御性的 `sub("\\r$", "", raw_line)`——`readLines()`
    理论上会正确处理 CRLF，但既然你这份 `starrocks.properties` 确实是 CRLF 结尾，多这一行
    没有坏处。
  - 同样加了 AQE 相关 config。
- `ryochan_sparklyr_coxph.R`：
  - `spark_apply()` 闭包原来把模型固定下载到 `/tmp/cox_model.rds`，同一台 worker 上并发跑多
    个分区任务时有竞态风险（一个任务在读，另一个任务的 `-f` 覆盖下载可能同时发生）。改成
    `tempfile()` 给每次调用一个独立路径，用完删除。
  - `sample_frac` 加了 `min(1, ...)`，源表行数小于 20 万时不会算出大于 1 的抽样比例（原代码
    在那种情况下 `sdf_sample(fraction > 1)` 会直接报错）。
  - 模型 HDFS 路径、源表名、输出表名都从硬编码占位符改成可用环境变量覆盖
    （`RYOCHAN_SOURCE_TABLE` / `RYOCHAN_COX_MODEL_HDFS_PATH` / `RYOCHAN_PREDICTIONS_TABLE`）。

## 没有改动、上一轮已核实为正确的部分
- `REQUIRED_STARROCKS_KEYS`（`starrocks.fe.http.url` / `starrocks.fe.jdbc.url` /
  `starrocks.table.identifier` / `starrocks.user` / `starrocks.password`）对照 StarRocks 官方
  Spark connector 文档核实无误，两个语言版本保持一致，未改动。
- `ryochan_sparklyr_demo.R` 里 `run_starrocks()` 用 `invoke("read")/invoke("format", "starrocks")`
  这套底层调用——这是 sparklyr 没有原生 `starrocks` source 包装函数时的标准写法，核实无误，
  未改动。
