# 数据流和指标口径

## 1. 端到端链路

```text
MariaDB bet01 / bet02
  |-- ods-bet01 / ods-bet02 ---------------------> S3 ODS Parquet
  |                                                   |
  |-- player-pair / dealer-profit <-------------------+
                         |
                         +-> StarRocks 小时事实表
                         |      |
                         |      +-> 受影响键重算
                         |
                         +-> API MySQL 查询投影
                                |
                                +-> wm-trueman-risk-api
```

正常小时统计使用 `INPUT_SOURCE=mysql`，直接读取源 MariaDB。历史数据重算可使用 `INPUT_SOURCE=s3`，但对应 ODS 分区必须先准备完成。

## 2. 源数据职责

### 2.1 bet01

`bet01` 是投注订单表，用于：

- `ods-bet01`
- `PlayerPairJob`

一个玩家在同一回合可能有多条投注记录，因此投注行不能直接等同于玩家参与回合。`RoundBuilder` 按 `(bet03 + bet04, player_id)` 去重，优先保留 `updatetime` 较新的记录；时间相同则保留 `betId` 较大的记录。

统计前还会过滤：

- `bet03 > 0`
- `category = 1`
- `bet30 = 'N'`

### 2.2 bet02

`bet02` 是结算表，用于：

- `ods-bet02`
- `DealerProfitJob`

统计前过滤：

- `bet03 > 0`
- `bet38 = 'N'`
- `category = 1`

荷官盈利使用结算侧的 `validbet`、`bet13`、`bet14`、`eid` 等字段，不直接使用 `bet17` 作为最终盈利口径。

### 2.3 currency

`currency` 位于 `SOURCE_JDBC_URL` 指向的源 MariaDB 数据库，通过 `currency.id = bet10` 关联。

统计金额统一换算为人民币：

```text
CNY amount = source amount / currency.rate
```

`INPUT_SOURCE=mysql` 时，`bet01` 或 `bet02` 查询直接关联 `currency`。`INPUT_SOURCE=s3` 时，投注或结算数据来自 S3 ODS，但 Spark 仍通过源 JDBC 读取 `currency(id, rate)` 并广播关联。因此 S3 重算期间源 MariaDB 仍需可访问。

当前使用任务执行时读取到的汇率。`currency` 没有可用的历史汇率记录时，无法按投注发生时的历史汇率回溯。汇率缺失或 `rate <= 0` 的记录会被内连接过滤，应通过数据质量检查持续监控。

## 3. 时间窗口

### 3.1 读取字段

所有增量源读取使用索引字段：

```text
bet08 / bet_time
```

窗口采用左闭右开：

```text
bet08 >= START_TIME AND bet08 < END_TIME
```

不要使用 `bet06` 或 `updatetime` 替代当前生产增量读取字段。

### 3.2 统计归属

统计任务把一个大窗口拆成逐小时窗口。每个小时先将 `bet08` 读取范围向前、向后扩展 `JOB_WINDOW_GRACE_MINUTES`，默认 3 分钟，然后仅保留：

```text
openTime >= hour_start AND openTime < hour_end
```

读取扩展用于覆盖 `bet08` 与 `bet06/openTime` 的轻微错位；最终小时归属始终由 `bet06/openTime` 决定。

### 3.3 ODS 分区

ODS 路径由 `bet08` 派生：

```text
<HISTORY_BASE>/ods/<table>/bet_date=yyyy-MM-dd/bet_hour=HH
```

ODS 任务只写显式 `[START_TIME, END_TIME)` 覆盖的小时时间，不主动扩展 grace。统计任务从 S3 重算时，ODS 必须覆盖扩展后读取区间所涉及的全部小时。

## 4. ODS 处理

ODS 任务执行 `SELECT *`，保留源字段。写入前删除本次窗口触及的小时时间，再以 append 模式写入对应分区，从而保证重复执行不会累计重复数据。

ODS 任务不使用 `job_checkpoint`，必须显式提供：

- `START_TIME`
- `END_TIME`
- `HISTORY_BASE`
- 源 MariaDB 连接配置

S3 统计读取遇到缺失或没有数据文件的小时分区时，将该分区视为空数据。这允许真实无数据小时正常完成，但也意味着必须结合源表数量确认“空分区”是否符合预期。

## 5. 玩家同桌统计

### 5.1 回合和玩家去重

回合标识为：

```text
round_key = bet03 + bet04
```

`RoundBuilder` 生成每回合每玩家一行的 `RoundPlayer`。`PairGenerator` 对同一回合的玩家去重、排序，只生成：

```text
player_a < player_b
```

不会生成自己与自己的组合，也不会生成反向重复组合。单回合玩家数大于 500 时不生成玩家对，以限制异常数据造成的组合爆炸。

### 5.2 指标公式

| 字段 | 含义 |
|---|---|
| `same_round_count` | 两个玩家共同出现的去重回合数 |
| `player_a_rounds` | 玩家 A 的去重回合数 |
| `player_b_rounds` | 玩家 B 的去重回合数 |
| `same_rate` | `same_round_count / LEAST(player_a_rounds, player_b_rounds)` |
| `first_game_time` | 最早共同出现时间 |
| `last_game_time` | 最近共同出现时间 |

StarRocks 完整小时事实保存在：

- `player_pair_stat_hourly`
- `player_round_stat_hourly`

API MySQL 默认只保留满足以下条件的候选关系：

```sql
(same_round_count >= 3
 AND LEAST(player_a_rounds, player_b_rounds) >= 5
 AND same_rate >= 0.3)
OR same_round_count >= 10
```

阈值由 `PLAYER_PAIR_API_*` 环境变量控制。

## 6. 荷官盈利统计

### 6.1 聚合键

```text
dealer_id + game_id + player_id
```

先按 `(dealer_id, game_id, player_id, round_id, sub_round_id)` 汇总回合，再汇总到荷官、游戏和玩家维度。输赢次数按回合盈利判断，而不是按投注行判断。

### 6.2 金额和比率

所有金额为人民币口径：

```text
turnover  = SUM(bet13 / currency.rate)
valid_bet = SUM(validbet / currency.rate)
profit    = SUM((bet14 - bet13) / currency.rate)
```

`profit` 表示玩家盈利：正数表示玩家盈利、平台或荷官侧亏损；负数表示玩家亏损。

| 字段 | 公式或含义 |
|---|---|
| `bet_count` | 有效结算投注行数 |
| `round_count` | 去重结算回合数 |
| `profit_per_bet` | `profit / bet_count` |
| `win_count` | 回合盈利大于 0 的回合数 |
| `lose_count` | 回合盈利小于 0 的回合数 |
| `push_count` | 回合盈利等于 0 的回合数 |
| `win_rate` | `win_count / round_count` |
| `player_roi` | `profit / valid_bet`，有效投注为 0 时取 0 |

完整小时事实保存在 `dealer_profit_stat_hourly`。API MySQL 默认只保留：

```sql
(bet_count >= 20
 AND valid_bet >= 1000
 AND profit > 0
 AND player_roi >= 0.2)
OR profit >= 10000
```

`valid_bet` 和 `profit` 的阈值单位均为人民币。阈值由 `DEALER_PROFIT_API_*` 环境变量控制。

`dealer_avg_roi`、`dealer_std_roi`、`roi_deviation`、`roi_zscore`、`player_count`、`risk_score` 和 `risk_level` 当前为预留字段。生产查询不能依赖这些字段进行风险判断。

## 7. StarRocks 表

### 7.1 小时事实表

| 表 | 主键 | 用途 |
|---|---|---|
| `player_pair_stat_hourly` | `stat_date, stat_hour, player_a, player_b` | 玩家对每小时共同回合事实 |
| `player_round_stat_hourly` | `stat_date, stat_hour, player_id` | 玩家每小时回合数，用于同桌率分母 |
| `dealer_profit_stat_hourly` | `stat_date, stat_hour, dealer_id, game_id, player_id` | 荷官、游戏、玩家每小时盈利事实 |

小时表使用 StarRocks Primary Key 模型，按 `stat_date` 动态分区，默认保留 730 天前至未来 7 天的分区范围，副本数为 3。规范 DDL 位于 `sql/starrocks_hourly.sql`。

### 7.2 刷新键表

| 表 | 用途 |
|---|---|
| `player_pair_refresh_key` | 保存当前刷新批次直接受影响的玩家对 |
| `player_refresh_player_key` | 保存受影响玩家，用于需要传播分母变化时扩展玩家对 |
| `dealer_profit_refresh_key` | 保存当前刷新批次受影响的荷官、游戏、玩家键 |

刷新键以 `run_id` 隔离。任务读取旧小时键、记录新旧受影响键、替换小时事实、从全部小时事实重算这些键，随后清理本次 `run_id` 数据。

### 7.3 checkpoint 和离线投影

`job_checkpoint` 每个统计任务一行，`last_update_time` 表示最后成功完成的 `bet08` 窗口右边界。正常增量任务成功完成全部小时后才推进 checkpoint。

StarRocks 还可维护与 API 表同形的每日离线投影：

- `player_pair_stat`
- `dealer_profit_stat`

它们由 `scripts/ds/refresh_starrocks_projection_daily.sh` 从小时事实全量重建，适合报表和离线查询，不替代小时事实。

## 8. API MySQL 投影

API MySQL 表为：

- `player_pair_stat`
- `dealer_profit_stat`

它们只保存满足投影阈值的候选记录。小时任务采用幂等刷新：

1. 获取被替换小时的旧键。
2. 删除目标小时快照。
3. 写入新小时快照。
4. 合并旧键和新键。
5. 从全部小时事实重新聚合受影响键。
6. upsert 仍满足阈值的 API MySQL 记录。
7. 删除不再满足阈值或已无事实的记录。

规范 DDL 位于 `sql/mysql_api.sql`。API MySQL 不能用于恢复小时事实或执行离线重算。
