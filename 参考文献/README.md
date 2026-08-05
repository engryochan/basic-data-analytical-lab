# wm-trueman-risk 文档

本文档集描述离线风控统计引擎的当前生产架构、数据口径、任务调度和运维方式。代码、DDL、Livy 模板和部署脚本是最终执行依据。

## 阅读顺序

| 文档 | 适用场景 |
|---|---|
| [DATA_FLOW.md](DATA_FLOW.md) | 理解源表、时间窗口、金额换算、指标公式和存储表 |
| [SCHEDULING.md](SCHEDULING.md) | 配置 DolphinScheduler、Livy、YARN 队列、部署和历史补数 |
| [OPERATIONS.md](OPERATIONS.md) | 上线检查、任务巡检、数据质量检查和故障恢复 |
| [API_SERVICES.md](API_SERVICES.md) | 理解离线投影与 `wm-trueman-risk-api` 的接口边界 |
| [../deploy/README.md](../deploy/README.md) | 使用部署包和随包脚本 |
| [en/README.md](en/README.md) | English documentation |

## 架构边界

```text
源 MariaDB
  bet01 --------> PlayerPairJob
  bet02 --------> DealerProfitJob
  currency -----> 金额人民币换算
      |
      +---------> ODS Livy 任务 -> S3 Parquet ODS

统计任务 -> StarRocks 小时事实 -> API MySQL 投影 -> wm-trueman-risk-api
```

系统分工如下：

- `wm-trueman-risk` 负责 ODS、离线统计、小时事实、投影刷新和 checkpoint。
- StarRocks 保存可按小时替换、可重新聚合的事实数据。
- API MySQL 保存满足风控阈值的查询投影，不作为重算来源。
- `wm-trueman-risk-api` 只读取 API MySQL，并使用 Redis/Valkey 提供鉴权、限流和结果缓存。

## 生产任务

| 任务 | 调度建议 | checkpoint | 默认统计输入 |
|---|---:|---:|---|
| `ods-bet01` | 每小时 | 否 | MariaDB |
| `ods-bet02` | 每小时 | 否 | MariaDB |
| `player-pair` | 每小时 | 是 | MariaDB |
| `dealer-profit` | 每小时 | 是 | MariaDB |

四个任务使用同一个入口类 `com.wm.risk.launcher.JobLauncher`。统计任务读取 S3 时，必须先准备覆盖统计读取窗口的 ODS 小时分区。

## 核心数据原则

- 读取时间：`bet08/bet_time`。
- 统计归属时间：`bet06/openTime`。
- 时间区间：左闭右开 `[start, end)`。
- 回合标识：`bet03 + bet04`。
- 玩家同桌：先按回合和玩家去重，再生成 `player_a < player_b` 的组合。
- 荷官盈利：`profit = (bet14 - bet13) / currency.rate`。
- 有效投注：`valid_bet = validbet / currency.rate`。
- 投注额：`turnover = bet13 / currency.rate`。
- S3 ODS 保留源字段；人民币换算发生在统计读取阶段。
- 汇率缺失或 `rate <= 0` 的记录不会进入统计。
- `risk_score` 和 `risk_level` 是预留字段，不承载风控判断语义。

## 配置来源

- 默认配置：`src/main/resources/application.conf`
- 生产覆盖：`src/main/resources/application-prod.conf`
- 部署变量模板：`deploy/conf/env.example`
- Livy 提交模板：`scripts/livy/*.json`
- DolphinScheduler 调用脚本：`scripts/ds/*.sh`

生产变量通过 Livy JSON 同时注入 `spark.yarn.appMasterEnv.*` 和 `spark.executorEnv.*`，无需在每个 EMR 节点手工导出。
