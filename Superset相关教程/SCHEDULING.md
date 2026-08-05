# 调度、部署和补数

## 1. 构建和部署包

运行环境：JDK 11、Maven 3.9.x、Scala 2.12、Spark 3.5.x。

```powershell
mvn clean test package dependency:copy-dependencies -DoutputDirectory=target/lib
powershell -ExecutionPolicy Bypass -File .\scripts\package-deploy.ps1 -Version 1.0.0
```

输出目录：

```text
target/package/wm-trueman-risk-deploy-1.0.0/
target/package/wm-trueman-risk-deploy-1.0.0.zip
```

部署包包含应用 jar、依赖 jar、DDL、DolphinScheduler/Livy 脚本、配置模板和中英文文档。生产目录建议为：

```text
/opt/wm-risk
  app/
  bin/
  conf/
  docs/
  scripts/
  sql/
```

将 `conf/env.example` 复制为 `conf/env` 并填写真实值。`conf/env`、密码、证书私钥和真实 worker 清单不得提交到仓库。

## 2. 初始化数据库

先创建 StarRocks 数据库，再按顺序执行：

```bash
mysql -h <starrocks-fe> -P 9030 -u <user> -p < /opt/wm-risk/sql/starrocks.sql
mysql -h <starrocks-fe> -P 9030 -u <user> -p < /opt/wm-risk/sql/starrocks_hourly.sql
mysql -h <api-mysql> -P 3306 -u <user> -p < /opt/wm-risk/sql/mysql_api.sql
```

- `starrocks.sql`：checkpoint、刷新键和 StarRocks 离线投影。
- `starrocks_hourly.sql`：三张小时事实表。
- `mysql_api.sql`：供 API 服务读取的两张 MySQL 投影表及查询索引。

执行后检查：

```sql
SHOW TABLES;
SHOW CREATE TABLE player_pair_stat_hourly;
SHOW CREATE TABLE player_round_stat_hourly;
SHOW CREATE TABLE dealer_profit_stat_hourly;
SHOW CREATE TABLE job_checkpoint;
```

## 3. 上传运行文件

Livy JSON 中的 `file`、`jars` 和 `files` 必须指向可由 EMR 访问的 S3 对象。可使用部署脚本上传应用、依赖和证书：

```bash
source /opt/wm-risk/conf/env
bash /opt/wm-risk/bin/upload-s3-files.sh
```

上传后确认：

- 主 jar 和依赖 jar 均可读取。
- StarRocks truststore 通过 `#sr-fe.jks` 在 YARN 容器中创建固定文件名。
- 四个 `scripts/livy/*.json` 的 S3 路径与实际上传位置一致。
- Spark event log 目录存在且 EMR 运行角色有写权限。

## 4. 生产环境变量

完整模板位于 `deploy/conf/env.example`。

### 4.1 Livy 和 YARN

| 变量 | 作用 |
|---|---|
| `LIVY_HOST`, `LIVY_PORT` | Livy 地址，默认端口 8998 |
| `LIVY_USER`, `LIVY_PASSWORD` | Livy Basic Auth |
| `LIVY_POLL_INTERVAL_SEC` | 状态轮询间隔 |
| `LIVY_MAX_WAIT_SEC` | 单批次最长等待时间 |
| `YARN_QUEUE` | 最终提交的 YARN 队列，生产通常为 `prod` |
| `STATS_*` | 两个统计任务的 driver、executor 和数量配置 |

DolphinScheduler 任务优先级只决定 DS 内部调度顺序，最终 YARN 队列由 Livy 请求中的 `queue` 决定，也就是 `YARN_QUEUE`。

### 4.2 运行窗口

| 变量 | 作用 |
|---|---|
| `START_TIME` | 左闭窗口起点，格式 `yyyy-MM-dd HH:mm:ss` |
| `END_TIME` | 右开窗口终点 |
| `RERUN` | 是否为显式重算 |
| `INPUT_SOURCE` | 统计输入，`mysql` 或 `s3` |
| `HISTORY_BASE` | S3 ODS 根路径 |
| `JOB_WINDOW_GRACE_MINUTES` | 统计读取窗口前后扩展分钟数，默认 3 |
| `SPARK_SQL_SESSION_TIMEZONE` | Spark SQL 时区，建议 `Asia/Shanghai` |

### 4.3 数据连接

- `SOURCE_*`：源 MariaDB，读取 `bet01`、`bet02`、`currency`。
- `ODS_JDBC_*`：ODS JDBC 分区和超时参数。
- `SR_*`：StarRocks JDBC、FE HTTP、写入重试和并发参数。
- `API_MYSQL_*`：API MySQL 地址、账号、批次和写并发。

`API_MYSQL_WRITE_PARALLELISM` 建议从 4 开始；MySQL 压力较高时降到 2，只有确认写入阶段是瓶颈且数据库空闲时才提高到 6 或 8。

### 4.4 风控投影阈值

玩家同桌：

- `PLAYER_PAIR_API_MIN_SAME_ROUND_COUNT=3`
- `PLAYER_PAIR_API_MIN_PLAYER_ROUNDS=5`
- `PLAYER_PAIR_API_MIN_SAME_RATE=0.3`
- `PLAYER_PAIR_API_KEEP_SAME_ROUND_COUNT=10`

荷官盈利：

- `DEALER_PROFIT_API_MIN_BET_COUNT=20`
- `DEALER_PROFIT_API_MIN_VALID_BET=1000`
- `DEALER_PROFIT_API_MIN_PROFIT=0`
- `DEALER_PROFIT_API_MIN_PLAYER_ROI=0.2`
- `DEALER_PROFIT_API_KEEP_PROFIT=10000`

金额阈值均为人民币。

## 5. DolphinScheduler 小时任务

建议创建四个独立工作流：

| 工作流 | 调用脚本 | 依赖 |
|---|---|---|
| `wm-risk-ods-bet01-hourly` | `scripts/ds/submit_ods_bet01_livy.sh` | 无 |
| `wm-risk-ods-bet02-hourly` | `scripts/ds/submit_ods_bet02_livy.sh` | 无 |
| `wm-risk-player-pair-hourly` | `scripts/ds/submit_player_pair_livy.sh` | MySQL 模式无 ODS 依赖；S3 模式依赖 ODS `bet01` |
| `wm-risk-dealer-profit-hourly` | `scripts/ds/submit_dealer_profit_livy.sh` | MySQL 模式无 ODS 依赖；S3 模式依赖 ODS `bet02` |

DS Shell 任务示例：

```bash
set -euo pipefail
source /opt/wm-risk/conf/env

export START_TIME="${bizdate} ${hour}:00:00"
export END_TIME="${bizdate} ${next_hour}:00:00"
export RERUN=false
export INPUT_SOURCE=mysql
export YARN_QUEUE=prod

bash /opt/wm-risk/scripts/ds/submit_player_pair_livy.sh
```

DS 应生成明确的小时起止时间，不要依赖节点本地当前时间。跨日窗口同样使用完整时间字符串，例如 `23:00:00` 到次日 `00:00:00`。

### 5.1 正常增量模式

```text
RERUN=false
INPUT_SOURCE=mysql
START_TIME=<可选>
END_TIME=<必填>
```

- 显式提供 `START_TIME`：任务使用该起点，全部小时成功后将 checkpoint 推进到 `END_TIME`。
- 不提供 `START_TIME`：任务从对应 `job_checkpoint.last_update_time` 开始。
- checkpoint 不存在且未提供 `START_TIME`：任务失败，不会猜测起点。

### 5.2 玩家对刷新范围

`PLAYER_PAIR_REFRESH_SCOPE=direct` 只重算本窗口直接变化的玩家对，适合小时任务。

`PLAYER_PAIR_REFRESH_SCOPE=player` 会把受影响玩家参与的所有历史玩家对纳入重算，用于严格传播玩家回合分母变化，但扫描范围更大。可将 `direct` 用于小时任务，并定期执行一次完整离线投影刷新进行校准。

## 6. 历史数据补数

统一脚本：

```bash
source /opt/wm-risk/conf/env
bash /opt/wm-risk/scripts/ds/backfill_history_livy.sh \
  --start "2026-05-01 00:00:00" \
  --end "2026-06-01 00:00:00" \
  --window-hours 24
```

执行顺序：

1. `ods-bet01`
2. `ods-bet02`
3. `player-pair`，使用 `RERUN=true` 和 `INPUT_SOURCE=s3`
4. `dealer-profit`，使用 `RERUN=true` 和 `INPUT_SOURCE=s3`
5. 校验 StarRocks 小时事实。
6. 根据计划推进 checkpoint。
7. 重建投影并清理 API 查询缓存。

脚本默认可并行运行两个 ODS 任务和两个统计任务，并使用 `_backfill_state` done marker 跳过成功窗口。done marker 只属于补数脚本，Spark 任务不会读取它。

### 6.1 grace 覆盖

统计窗口向前后扩展 `JOB_WINDOW_GRACE_MINUTES`，但 ODS 只写精确窗口。补数脚本默认通过 `BACKFILL_ODS_COVER_STATS_GRACE=true` 扩展 ODS 准备范围，确保边界小时可被统计读取。

### 6.2 checkpoint

`RERUN=true` 不读取或更新 `job_checkpoint`。全部补数成功并完成质量校验后，可以执行脚本输出的 checkpoint SQL，或手工更新：

```sql
INSERT INTO job_checkpoint
  (job_name, last_update_time, status, finish_time, created_time, update_time)
VALUES
  ('player-pair', '2026-06-01 00:00:00', 'SUCCESS', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
  ('dealer-profit', '2026-06-01 00:00:00', 'SUCCESS', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
```

`last_update_time` 必须是已确认完整成功的 `bet08` 窗口右边界，不能使用任务完成时间、最大 `bet06` 或当前时间代替。

## 7. StarRocks 每日离线投影

从完整小时事实重建 StarRocks 同形投影：

```bash
source /opt/wm-risk/conf/env
bash /opt/wm-risk/scripts/ds/refresh_starrocks_projection_daily.sh \
  --end "2026-07-18 00:00:00"
```

常用参数：

```bash
# 仅预览 SQL
bash /opt/wm-risk/scripts/ds/refresh_starrocks_projection_daily.sh --dry-run

# DDL 已初始化时跳过建表
bash /opt/wm-risk/scripts/ds/refresh_starrocks_projection_daily.sh --skip-ddl

# 只刷新一类投影
bash /opt/wm-risk/scripts/ds/refresh_starrocks_projection_daily.sh --player-pair
bash /opt/wm-risk/scripts/ds/refresh_starrocks_projection_daily.sh --dealer-profit
```

脚本对目标投影执行 `TRUNCATE + INSERT`，因此不要与依赖这些 StarRocks 投影的长查询并发运行。小时事实不受影响。

## 8. API 查询缓存清理

创建两个独立的 DolphinScheduler Shell 任务：

| 任务名称 | Shell 命令 | 建议上游 |
|---|---|---|
| `wm-risk-evict-player-pair-cache` | `bash /opt/wm-risk/scripts/ds/evict_player_pair_cache.sh` | `wm-risk-player-pair-hourly` 或玩家同桌补数任务 |
| `wm-risk-evict-dealer-profit-cache` | `bash /opt/wm-risk/scripts/ds/evict_dealer_profit_cache.sh` | `wm-risk-dealer-profit-hourly` 或荷官盈利补数任务 |

两个任务清理的是 API Redis/Valkey 查询结果缓存，不是 StarRocks 内部缓存。玩家同桌任务清理 `risk-player-pairs`、`risk-player-pair-evaluate`、`risk-player-pair-top`；荷官盈利任务清理 `risk-dealer-players`、`risk-player-dealer-profits`、`risk-dealer-profit-anomalies`。`risk-player-profile` 同时依赖两类投影，所以两个任务都会清理它。

在 `/opt/wm-risk/conf/env` 配置 `REDIS_HOST`、`REDIS_PORT`、`REDIS_PASSWORD` 和 `REDIS_TLS`。DolphinScheduler Worker 必须安装 `redis-cli`，并可通过安全组访问 Redis/Valkey。脚本只扫描并删除上述 Spring Cache 前缀，不清理 API 客户端、nonce 或限流 key。

API 查询结果默认十分钟过期。如果不要求投影更新后立即可见，可以不配置这两个任务，等待 TTL 自动失效。

## 9. 风控分析报告

默认从 StarRocks 离线投影生成 Markdown 报告：

```bash
source /opt/wm-risk/conf/env
bash /opt/wm-risk/scripts/ds/generate_risk_report.sh \
  --source starrocks \
  --start "2026-07-17 00:00:00" \
  --end "2026-07-18 00:00:00" \
  --limit 20 \
  --output /tmp/wm-risk-report.md
```

也可使用 `--source api-mysql` 检查 API 投影。报告中的金额为人民币口径。

## 10. Livy 管理

```bash
source /opt/wm-risk/conf/env

bash /opt/wm-risk/scripts/livy/livy_admin.sh list 0 50
bash /opt/wm-risk/scripts/livy/livy_admin.sh get <batch_id>
bash /opt/wm-risk/scripts/livy/livy_admin.sh state <batch_id>
bash /opt/wm-risk/scripts/livy/livy_admin.sh log <batch_id> 0 200
bash /opt/wm-risk/scripts/livy/livy_admin.sh delete <batch_id>
```

Livy 返回 `success` 只是任务成功的第一层判断，还应验证 YARN 最终状态、StarRocks 小时数据、checkpoint 和 API MySQL 投影。
