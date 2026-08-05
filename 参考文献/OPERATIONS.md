# 运维手册

## 1. 上线检查

### 1.1 文件和配置

```bash
test -f /opt/wm-risk/conf/env
test -f /opt/wm-risk/conf/application-prod.conf
test -f /opt/wm-risk/app/wm-trueman-risk-1.0.0.jar
test -d /opt/wm-risk/app/lib
test -d /opt/wm-risk/scripts/livy
test -d /opt/wm-risk/scripts/ds
```

确认 `conf/env` 中没有占位符，文件权限仅允许运行账号读取。四个 Livy JSON 的主 jar、依赖 jar、truststore 和 event log S3 路径必须存在。

### 1.2 网络

从 DolphinScheduler worker 或任务执行节点验证：

```bash
source /opt/wm-risk/conf/env

bash /opt/wm-risk/bin/check-source-mysql-connectivity.sh
bash /opt/wm-risk/bin/check-api-mysql-connectivity.sh
curl -fsS -u "$LIVY_USER:$LIVY_PASSWORD" "http://$LIVY_HOST:$LIVY_PORT/batches?from=0&size=1"
curl -fsS "$SR_FE_HTTP/api/health"
```

还需确认 EMR/YARN 容器可以访问源 MariaDB、StarRocks FE HTTP/JDBC、API MySQL、S3 和 Spark event log 目录。

### 1.3 表结构

StarRocks 应包含：

```text
job_checkpoint
player_pair_stat_hourly
player_round_stat_hourly
dealer_profit_stat_hourly
player_pair_refresh_key
player_refresh_player_key
dealer_profit_refresh_key
player_pair_stat
dealer_profit_stat
```

API MySQL 应包含：

```text
player_pair_stat
dealer_profit_stat
```

核对主键、动态分区和副本数，尤其确认未来分区已创建，避免新小时写入失败。

## 2. 小时任务巡检

建议对四个工作流分别监控：

- DolphinScheduler 实例状态和耗时。
- Livy batch 最终状态。
- YARN application 最终状态、队列和资源等待时间。
- Spark stage 失败、shuffle spill、executor lost 和 JDBC 超时。
- StarRocks 目标小时行数。
- API MySQL 投影更新时间。
- 两个统计 checkpoint 是否按计划推进。

查询 Livy：

```bash
bash /opt/wm-risk/scripts/livy/livy_admin.sh list 0 50
bash /opt/wm-risk/scripts/livy/livy_admin.sh log <batch_id> 0 300
```

查询 YARN：

```bash
yarn application -list -appStates RUNNING,ACCEPTED
yarn application -status <application_id>
yarn queue -status prod
```

FairScheduler 队列名通常显示为 `root.prod`。需要同时检查实际 application 的 `Queue` 字段，不能只根据 DS 任务优先级判断。

## 3. checkpoint

查询：

```sql
SELECT
  job_name,
  last_update_time,
  status,
  finish_time,
  update_time
FROM job_checkpoint
ORDER BY job_name;
```

正常情况下至少有：

```text
player-pair
dealer-profit
```

含义：

- `last_update_time`：最后成功统计窗口的右边界，也是下一次自动增量起点。
- `finish_time`：写入 checkpoint 的完成时间。
- `update_time`：checkpoint 行更新时间。
- `status`：当前代码正常推进时写入 `SUCCESS`。

统计任务只有在全部小时窗口成功后才更新 checkpoint。`RERUN=true` 完成后 checkpoint 不变化。

检查连续性：

```sql
SELECT job_name, last_update_time,
       TIMESTAMPDIFF(MINUTE, last_update_time, CURRENT_TIMESTAMP) AS lag_minutes
FROM job_checkpoint
WHERE status = 'SUCCESS';
```

若 `last_update_time` 错误地超前，任务会跳过数据；若落后，任务会重复重算已完成小时。修正前应先对照源表 `bet08` 范围、小时事实和调度记录，确认正确的连续成功右边界。

## 4. ODS 检查

列出分区：

```bash
aws s3 ls "$HISTORY_BASE/ods/bet01/bet_date=2026-07-17/" --recursive
aws s3 ls "$HISTORY_BASE/ods/bet02/bet_date=2026-07-17/" --recursive
```

检查项：

- 窗口涉及的每个小时都有预期分区。
- 目录中存在非 `_`、非 `.` 开头的数据文件。
- Parquet 保留源字段 `bet08` 和 `bet10`。
- 同一小时重跑后没有旧文件和新文件叠加。
- 源表真实无数据的小时可以没有数据文件，但应有源表查询或业务证据支持。

## 5. StarRocks 数据质量

### 5.1 小时覆盖

```sql
SELECT stat_date, stat_hour, COUNT(*) AS rows
FROM player_pair_stat_hourly
WHERE stat_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 2 DAY)
GROUP BY stat_date, stat_hour
ORDER BY stat_date, stat_hour;

SELECT stat_date, stat_hour, COUNT(*) AS rows
FROM player_round_stat_hourly
WHERE stat_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 2 DAY)
GROUP BY stat_date, stat_hour
ORDER BY stat_date, stat_hour;

SELECT stat_date, stat_hour, COUNT(*) AS rows
FROM dealer_profit_stat_hourly
WHERE stat_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 2 DAY)
GROUP BY stat_date, stat_hour
ORDER BY stat_date, stat_hour;
```

空小时不一定是故障，应与源数据数量和任务日志一起判断。

### 5.2 玩家对约束

```sql
SELECT COUNT(*) AS invalid_pairs
FROM player_pair_stat_hourly
WHERE player_a >= player_b
   OR same_round_count < 0;

SELECT COUNT(*) AS invalid_rates
FROM (
  SELECT
    p.player_a,
    p.player_b,
    SUM(p.same_round_count) AS same_round_count,
    ar.round_count AS player_a_rounds,
    br.round_count AS player_b_rounds
  FROM player_pair_stat_hourly p
  JOIN (
    SELECT player_id, SUM(round_count) AS round_count
    FROM player_round_stat_hourly
    GROUP BY player_id
  ) ar ON p.player_a = ar.player_id
  JOIN (
    SELECT player_id, SUM(round_count) AS round_count
    FROM player_round_stat_hourly
    GROUP BY player_id
  ) br ON p.player_b = br.player_id
  GROUP BY p.player_a, p.player_b, ar.round_count, br.round_count
) t
WHERE same_round_count > LEAST(player_a_rounds, player_b_rounds);
```

### 5.3 荷官盈利约束

```sql
SELECT COUNT(*) AS invalid_rows
FROM dealer_profit_stat_hourly
WHERE bet_count < 0
   OR round_count < 0
   OR win_count + lose_count + push_count <> round_count
   OR win_rate < 0
   OR win_rate > 1;

SELECT
  SUM(valid_bet) AS valid_bet_cny,
  SUM(turnover) AS turnover_cny,
  SUM(profit) AS profit_cny
FROM dealer_profit_stat_hourly
WHERE stat_date = '2026-07-17';
```

### 5.4 汇率覆盖

在源 MariaDB 检查 `bet10` 是否能关联有效汇率：

```sql
SELECT b.bet10, COUNT(*) AS missing_rows
FROM bet02 b
LEFT JOIN currency c ON c.id = b.bet10 AND c.rate > 0
WHERE b.bet08 >= '2026-07-17 00:00:00'
  AND b.bet08 <  '2026-07-18 00:00:00'
  AND c.id IS NULL
GROUP BY b.bet10
ORDER BY missing_rows DESC;
```

结果不为空表示这些记录不会进入统计，应先修复币种或汇率数据再重跑对应小时。

## 6. API MySQL 投影检查

```sql
SELECT COUNT(*) AS pair_rows,
       MAX(update_time) AS pair_last_update
FROM player_pair_stat;

SELECT COUNT(*) AS dealer_profit_rows,
       MAX(update_time) AS dealer_profit_last_update
FROM dealer_profit_stat;
```

抽查投影阈值：

```sql
SELECT COUNT(*) AS invalid_pair_projection
FROM player_pair_stat
WHERE NOT (
  (same_round_count >= 3
   AND LEAST(player_a_rounds, player_b_rounds) >= 5
   AND same_rate >= 0.3)
  OR same_round_count >= 10
);

SELECT COUNT(*) AS invalid_profit_projection
FROM dealer_profit_stat
WHERE NOT (
  (bet_count >= 20
   AND valid_bet >= 1000
   AND profit > 0
   AND player_roi >= 0.2)
  OR profit >= 10000
);
```

如果生产阈值已通过环境变量调整，应同步替换检查 SQL 中的常量。

统计投影刷新或补数完成后，调用 API 服务的缓存清理接口。最稳妥的方式是：

```bash
export RISK_API_BASE_URL="https://<risk-api>"
export RISK_API_KEY="<cache-admin-key>"
export RISK_API_SECRET="<cache-admin-secret>"

bash /opt/wm-risk-api/scripts/evict-risk-cache.sh all
```

## 7. 失败恢复

### 7.1 ODS 任务失败

修复连接、权限或资源问题后，以相同 `[START_TIME, END_TIME)` 重跑。ODS 写入前会删除触及分区，因此不需要手工清空整个表目录。

### 7.2 统计任务失败且 checkpoint 未推进

修复原因后使用原窗口和 `RERUN=false` 重跑。小时快照采用替换写，重复执行不会累计加写。

### 7.3 checkpoint 已推进但数据不完整

1. 确认受影响的最早小时和最后小时。
2. 使用显式窗口和 `RERUN=true` 重算。
3. 校验小时事实和 API 投影。
4. 将 checkpoint 调整到连续成功窗口的右边界。
5. 清理 API 查询缓存。

### 7.4 S3 统计结果为空

依次检查：

1. `HISTORY_BASE` 是否正确。
2. 表名和 `bet_date/bet_hour` 分区是否正确。
3. grace 扩展涉及的边界小时是否准备完成。
4. Parquet 是否包含 `bet08`、`bet10` 和统计所需字段。
5. 源 MariaDB 的 `currency(id, rate)` 是否可访问且覆盖全部币种。
6. `bet06/openTime` 是否落在目标统计小时。

### 7.5 刷新键残留

失败可能留下某个 `run_id` 的临时键。确认没有对应任务仍在运行后，可按明确的 `run_id` 删除：

```sql
DELETE FROM player_pair_refresh_key WHERE run_id = '<run_id>';
DELETE FROM player_refresh_player_key WHERE run_id = '<run_id>';
DELETE FROM dealer_profit_refresh_key WHERE run_id = '<run_id>';
```

不要无条件清空全部刷新键，避免影响并发任务。

## 8. 操作原则

- 不用 API MySQL 作为重算来源。
- 不用 `_backfill_state` 修复正常小时增量问题。
- 不用任务完成时间替代 checkpoint 窗口时间。
- 不在统计未校验时手工推进 checkpoint。
- 不把 `risk_score` 或 `risk_level` 当作已实现的评分结果。
- 不在生产日志或命令输出中暴露数据库密码、API Secret 和 truststore 密码。
