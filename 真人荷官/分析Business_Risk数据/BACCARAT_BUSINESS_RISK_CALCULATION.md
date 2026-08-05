# Baccarat 业务风控详细计算文档

## 1. 文档目的

本文档说明三项独立业务风控如何从 StarRocks ODS 数据计算为版本化快照，适用于业务确认、
数据开发、测试验收、上线核对和问题排查。

本文档覆盖以下三张 StarRocks 结果表：

```text
wm_live_risk.business_risk_late_bet_snapshot
wm_live_risk.business_risk_same_table_pair_snapshot
wm_live_risk.business_risk_player_dealer_snapshot
```

第一个表的实际名称是 `business_risk_late_bet_snapshot`。本文已按实际 DDL 修正原输入中
多余的表名前缀字符。

这套统计只使用 Bash 和 SQL，不需要运行或编译 Java、Scala，也不依赖 Spark 风控任务。

## 2. 总体数据流

```text
StarRocks ods_mariadb_2b.ods_a168_bet01
  ├─> 后段投注计算
  └─> 同桌/对打计算

StarRocks ods_mariadb_2b.ods_a168_bet02
  └─> 玩家—荷官计算

三项计算
  -> StarRocks wm_live_risk.business_risk_*_snapshot
  -> 逐项校验 StarRocks 快照
  -> MySQL business_risk_*_stat
  -> 核对 StarRocks/MySQL 三组行数
  -> MySQL business_risk_publish_state = READY
  -> API 只读取 READY as_of_time
```

StarRocks 快照表是完整计算和重建依据；MySQL `*_stat` 表是供 API 查询的投影。
MySQL 投影不能反向作为统计计算源。

## 3. 公共统计规则

### 3.1 游戏范围

三项统计只处理：

```text
bet02 = 101
```

即只统计 Baccarat 数据。

### 3.2 统计窗口

入口参数关系：

```text
WINDOW_END = AS_OF_TIME
WINDOW_START = AS_OF_TIME - BUSINESS_RISK_LOOKBACK_DAYS
```

默认回看天数：

```text
BUSINESS_RISK_LOOKBACK_DAYS = 30
```

允许范围为 `1..3650` 天。业务记录使用 `bet08` 进入精确半开区间：

```text
WINDOW_START <= bet08 < WINDOW_END
```

- `window_start` 包含边界。
- `window_end` 不包含边界。
- 正好等于 `window_end` 的记录属于下一个快照窗口。

源表同时使用以下 `dt` 条件做分区裁剪：

```text
dt >= DATE(WINDOW_START) - 1 day
dt <  DATE(WINDOW_END) + 1 day
```

`dt` 扩展范围只用于降低分区扫描风险，不改变最终业务窗口；最终归属仍由 `bet08` 的
精确条件决定。

### 3.3 订单最新版本去重

`ods_a168_bet01` 和 `ods_a168_bet02` 都可能包含同一订单的多个同步版本。计算先按
`bet01` 订单 ID 分组，再按以下顺序排序：

```text
updatetime DESC
sync_time DESC
dt DESC
bet01 DESC
```

仅保留：

```text
ROW_NUMBER() = 1
```

因此：

- 同一个订单只参与一次统计。
- 更新后的取消、重算、金额和荷官信息覆盖旧同步版本。
- `order_count` 统计的是去重后的订单，不是 ODS 原始行数。

### 3.4 时间字段区别

| 字段 | 含义 |
|---|---|
| `as_of_time` | 快照的数据截止时间和版本号，等于本次 `AS_OF_TIME`。同一个值标识一次完整计算版本。 |
| `window_start` | 本次统计窗口的包含式开始时间。 |
| `window_end` | 本次统计窗口的不包含结束时间，等于 `as_of_time`。 |
| `created_time` | 该行实际写入 StarRocks 的时间，由 `CURRENT_TIMESTAMP()` 生成。它不是数据截止时间。 |

同一个 `as_of_time` 的所有结果具有相同的 `window_start` 和 `window_end`。
重新计算同一个版本时，`created_time` 会变化，但 `as_of_time` 和业务窗口不变。

### 3.5 快照重跑和版本规则

每段计算都先执行：

```sql
DELETE FROM <snapshot_table>
WHERE as_of_time = TIMESTAMP('${AS_OF_TIME}');
```

再完整插入本次结果。因此相同 `as_of_time` 的完整重跑是幂等覆盖，不会累计相加。

正常工作流要求：

```text
新的 AS_OF_TIME > 当前 READY as_of_time
```

阈值修改只影响之后生成的更大 `as_of_time`。历史版本不会被自动重算，也不会覆盖当前
READY 为旧时间的结果。

## 4. 当前可配置参数

| 参数 | 当前默认值 | 比较规则 | 用途 |
|---|---:|---|---|
| `BUSINESS_RISK_LOOKBACK_DAYS` | `30` | `1..3650` | 统计回看天数。 |
| `BUSINESS_RISK_SNAPSHOT_RETENTION_DAYS` | `7` | `1..365` | StarRocks 和 MySQL 历史快照保留天数。 |
| `BUSINESS_RISK_LATE_SUB_ROUND_MIN` | `40` | `bet04 >= N` | 后段投注开始局号。 |
| `BUSINESS_RISK_LATE_ORDER_RATE_MIN` | `0.60` | `late_order_rate >= N` | 后段投注比例下限。 |
| `BUSINESS_RISK_LATE_ORDER_COUNT_MIN_EXCLUSIVE` | `50` | `late_order_count > N` | 后段投注订单数严格下限。 |
| `BUSINESS_RISK_SAME_ROUND_COUNT_MIN` | `100` | `same_round_count >= N` | 同桌去重局数下限。 |
| `BUSINESS_RISK_SAME_RATE_MIN` | `0.20` | `same_rate >= N` | 同桌率下限。 |
| `BUSINESS_RISK_OPPOSITE_RATE_MIN` | `0.70` | `opposite_rate >= N` | 对打率下限。 |
| `BUSINESS_RISK_PLAYER_DEALER_WIN_RATE_MIN_EXCLUSIVE` | `0.65` | `win_rate > N` | 玩家—荷官非和局胜率严格下限。 |
| `BUSINESS_RISK_PLAYER_DEALER_ORDER_COUNT_MIN_EXCLUSIVE` | `30` | `order_count > N` | 玩家—荷官订单数严格下限。 |

比例参数使用 `0..1`，例如 `0.70` 表示 70%，不能填写 `70` 或 `70%`。

## 5. 后段投注计算

### 5.1 目标表

```text
wm_live_risk.business_risk_late_bet_snapshot
```

存储键和分布：

```text
ENGINE = OLAP
PRIMARY KEY (as_of_time, player_id)
DISTRIBUTED BY HASH(player_id)
BUCKETS 16
```

同一个快照版本内，每个玩家最多一行。

### 5.2 数据源

```text
ods_mariadb_2b.ods_a168_bet01
```

主要源字段：

| 源字段 | 用途 |
|---|---|
| `bet01` | 订单 ID，用于订单最新版本去重。 |
| `bet02` | 游戏类型，只保留 `101`。 |
| `bet03` | 局 ID，必须大于 0。 |
| `bet04` | 子局/第几把，用于判断是否属于后段投注。 |
| `bet05` | 玩家 ID。 |
| `bet08` | 投注时间，用于统计窗口和首末投注时间。 |
| `bet13` | 投注金额，必须大于 0。 |
| `bet30` | 取消标记，只保留规范化后为 `N` 的订单。 |
| `category` | 数据类别，只保留 `1`。 |
| `updatetime`、`sync_time`、`dt` | 订单最新版本排序和分区裁剪。 |

### 5.3 有效订单条件

订单完成最新版本去重后，必须同时满足：

```text
CAST(bet02 AS INT) = 101
CAST(category AS INT) = 1
UPPER(TRIM(bet30)) = 'N'
CAST(bet13 AS DECIMAL) > 0
CAST(bet03 AS BIGINT) > 0
CAST(bet05 AS BIGINT) > 0
WINDOW_START <= CAST(bet08 AS DATETIME) < WINDOW_END
```

### 5.4 玩家聚合

按 `player_id = bet05` 分组：

```text
late_order_count =
  SUM(CASE WHEN bet04 >= BUSINESS_RISK_LATE_SUB_ROUND_MIN
           THEN 1 ELSE 0 END)

total_order_count = COUNT(*)

late_order_rate =
  CAST(late_order_count / total_order_count AS DECIMAL(9,6))

first_bet_time = MIN(bet08)
last_bet_time = MAX(bet08)
```

`late_order_count` 和 `total_order_count` 都是订单数。同一局多笔有效订单会按订单分别计数，
但同一订单的多个 ODS 版本只保留最新一行。

### 5.5 候选条件

当前默认条件：

```text
bet04 >= 40
AND late_order_rate >= 0.60
AND late_order_count > 50
```

边界示例：

| `late_order_count` | `total_order_count` | `late_order_rate` | 是否满足订单数/比例边界 |
|---:|---:|---:|---|
| `50` | `80` | `0.625000` | 否，订单数必须严格大于 50。 |
| `51` | `85` | `0.600000` | 是，比例 0.60 包含边界。 |
| `51` | `86` | `0.593023` | 否，比例低于 0.60。 |

### 5.6 字段字典：`business_risk_late_bet_snapshot`

| 字段 | 类型 | 可空 | 来源/公式 | 业务含义 |
|---|---|---:|---|---|
| `as_of_time` | `DATETIME` | 否 | `TIMESTAMP(AS_OF_TIME)` | 本批完整快照的数据截止时间和版本号。 |
| `player_id` | `BIGINT` | 否 | `CAST(bet05 AS BIGINT)` | 玩家 ID；本表的业务统计维度。 |
| `window_start` | `DATETIME` | 否 | `TIMESTAMP(WINDOW_START)` | 统计窗口开始时间，包含边界。 |
| `window_end` | `DATETIME` | 否 | `TIMESTAMP(WINDOW_END)` | 统计窗口结束时间，不包含边界。 |
| `late_order_count` | `BIGINT` | 否 | 满足 `bet04 >= BUSINESS_RISK_LATE_SUB_ROUND_MIN` 的有效订单数 | 后段投注订单数。 |
| `total_order_count` | `BIGINT` | 否 | 玩家全部有效订单 `COUNT(*)` | 玩家在同一窗口内的全部有效 Baccarat 订单数。 |
| `late_order_rate` | `DECIMAL(9,6)` | 否 | `late_order_count / total_order_count` | 后段投注订单占全部有效订单的比例。 |
| `first_bet_time` | `DATETIME` | 是 | `MIN(bet08)` | 玩家在统计窗口内第一笔有效投注时间。 |
| `last_bet_time` | `DATETIME` | 是 | `MAX(bet08)` | 玩家在统计窗口内最后一笔有效投注时间。 |
| `created_time` | `DATETIME` | 否 | `CURRENT_TIMESTAMP()` | 本快照行的实际创建时间。 |

## 6. 同桌/对打计算

### 6.1 目标表

```text
wm_live_risk.business_risk_same_table_pair_snapshot
```

存储键和分布：

```text
ENGINE = OLAP
PRIMARY KEY (as_of_time, player_a, player_b)
DISTRIBUTED BY HASH(player_a, player_b)
BUCKETS 16
```

同一个快照版本内，每个规范化玩家对最多一行。

### 6.2 数据源和物理局

数据源：

```text
ods_mariadb_2b.ods_a168_bet01
```

物理局键：

```text
round_id + sub_round_id + table_id
= bet03 + bet04 + bet31
```

玩家参与键：

```text
bet03 + bet04 + bet31 + bet05
```

除后段投注使用的 bet01 公共有效条件外，同桌计算还要求：

```text
CAST(bet31 AS BIGINT) > 0
```

### 6.3 投注方向标准化

`bet09` 经过去空格和大写转换后映射：

| 原始值 | 标准方向 |
|---|---|
| `BANKER`、`B`、`ZHUANG`、庄/莊 | `BANKER` |
| `PLAYER`、`P`、`XIAN`、闲/閒 | `PLAYER` |
| `TIE`、`DRAW`、`HE`、和 | `TIE` |
| 其他值 | `OTHER` |

对打只使用 `BANKER` 和 `PLAYER` 金额。`TIE`、`OTHER` 仍可证明玩家参与同一物理局，
但不会形成庄/闲相反投注本金。

### 6.4 玩家物理局去重

同一玩家可能在同一物理局有多笔订单。计算先按：

```text
round_id, sub_round_id, table_id, player_id
```

聚合为一行：

```text
banker_amount = SUM(BANKER 方向投注金额)
player_amount = SUM(PLAYER 方向投注金额)
first_bet_time = MIN(bet08)
last_bet_time = MAX(bet08)
```

`player_round_count` 是该玩家聚合后的物理局行数，不是订单数。

### 6.5 玩家对生成

同一物理局内的玩家参与行自连接，只生成：

```text
player_a < player_b
```

因此不会生成：

- 玩家与自身的 `(A,A)`。
- 同一玩家对的反向重复 `(B,A)`。
- 因同一局多订单产生的重复玩家对。

### 6.6 对打本金和指标

每个共同物理局的匹配对打本金：

```text
matched_principal =
    LEAST(A.banker_amount, B.player_amount)
  + LEAST(A.player_amount, B.banker_amount)
```

含义：

- A 投庄与 B 投闲可以匹配。
- A 投闲与 B 投庄可以匹配。
- 任一方向匹配金额大于 0，该共同局就计为一局对打局。
- 当前指标统计“是否存在匹配本金的局数”，不累计匹配本金金额。

玩家对聚合：

```text
same_round_count = COUNT(shared physical rounds)

opposite_round_count =
  SUM(CASE WHEN matched_principal > 0 THEN 1 ELSE 0 END)

same_rate =
  same_round_count
  / LEAST(player_a_round_count, player_b_round_count)

opposite_rate =
  opposite_round_count / same_round_count

first_game_time =
  MIN(LEAST(A.first_bet_time, B.first_bet_time))

last_game_time =
  MAX(GREATEST(A.last_bet_time, B.last_bet_time))
```

`same_rate` 以两名玩家中较小的总参与局数作为分母，衡量局数较少的一方有多大比例与
另一方同局。`opposite_rate` 以两人共同参与局数作为分母，衡量共同局中出现庄/闲相反
投注的比例。

### 6.7 候选条件

当前三个条件必须全部满足：

```text
same_round_count >= 100
AND same_rate >= 0.20
AND opposite_rate >= 0.70
```

不是 `same_rate` 与 `opposite_rate` 二选一。

边界示例：

| `same_round_count` | `same_rate` | `opposite_rate` | 是否入选 |
|---:|---:|---:|---|
| `100` | `0.200000` | `0.700000` | 是，三个条件都包含边界。 |
| `100` | `0.199999` | `0.900000` | 否，同桌率不满足。 |
| `100` | `0.500000` | `0.699999` | 否，对打率不满足。 |
| `99` | `0.500000` | `0.900000` | 否，共同局数不满足。 |

### 6.8 字段字典：`business_risk_same_table_pair_snapshot`

| 字段 | 类型 | 可空 | 来源/公式 | 业务含义 |
|---|---|---:|---|---|
| `as_of_time` | `DATETIME` | 否 | `TIMESTAMP(AS_OF_TIME)` | 本批完整快照的数据截止时间和版本号。 |
| `player_a` | `BIGINT` | 否 | 玩家对中较小的 `bet05` | 规范化玩家对中的较小玩家 ID。 |
| `player_b` | `BIGINT` | 否 | 玩家对中较大的 `bet05` | 规范化玩家对中的较大玩家 ID。 |
| `window_start` | `DATETIME` | 否 | `TIMESTAMP(WINDOW_START)` | 统计窗口开始时间，包含边界。 |
| `window_end` | `DATETIME` | 否 | `TIMESTAMP(WINDOW_END)` | 统计窗口结束时间，不包含边界。 |
| `same_round_count` | `BIGINT` | 否 | 玩家对共同物理局 `COUNT(*)` | 两名玩家共同参与的去重物理局数。 |
| `player_a_round_count` | `BIGINT` | 否 | 玩家 A 的参与行 `COUNT(*)` | 玩家 A 在窗口内参与的全部去重物理局数。 |
| `player_b_round_count` | `BIGINT` | 否 | 玩家 B 的参与行 `COUNT(*)` | 玩家 B 在窗口内参与的全部去重物理局数。 |
| `same_rate` | `DECIMAL(9,6)` | 否 | `same_round_count / LEAST(A局数,B局数)` | 同桌率。 |
| `opposite_round_count` | `BIGINT` | 否 | `matched_principal > 0` 的共同局数 | 存在庄/闲相反投注匹配本金的去重共同局数。 |
| `opposite_rate` | `DECIMAL(9,6)` | 否 | `opposite_round_count / same_round_count` | 对打率。 |
| `first_game_time` | `DATETIME` | 是 | 所有共同局双方最早投注时间的最小值 | 该玩家对在窗口内第一次同局的投注时间。 |
| `last_game_time` | `DATETIME` | 是 | 所有共同局双方最晚投注时间的最大值 | 该玩家对在窗口内最后一次同局的投注时间。 |
| `created_time` | `DATETIME` | 否 | `CURRENT_TIMESTAMP()` | 本快照行的实际创建时间。 |

## 7. 玩家—荷官计算

### 7.1 目标表

```text
wm_live_risk.business_risk_player_dealer_snapshot
```

存储键和分布：

```text
ENGINE = OLAP
PRIMARY KEY (as_of_time, player_id, dealer_id)
DISTRIBUTED BY HASH(player_id, dealer_id)
BUCKETS 16
```

同一个快照版本内，每个玩家—荷官组合最多一行。

### 7.2 数据源

```text
ods_mariadb_2b.ods_a168_bet02
```

主要源字段：

| 源字段 | 用途 |
|---|---|
| `bet01` | 结算订单 ID，用于最新版本去重。 |
| `bet02` | 游戏类型，只保留 `101`。 |
| `bet03` | 局 ID。 |
| `bet04` | 子局 ID。 |
| `bet05` | 玩家 ID。 |
| `bet08` | 投注时间，用于统计窗口和首末投注时间。 |
| `bet11` | 汇率，必须大于 0；全部金额除以该值归一化。 |
| `bet13` | 源投注金额。 |
| `bet14` | 源派彩金额，用于计算不含返水的游戏输赢。 |
| `bet16` | 源返水金额。 |
| `bet17` | 源结算净盈利/账户净变动，口径包含返水。 |
| `bet38` | 重算标记，只保留规范化后为 `N` 的记录。 |
| `bet39` | 桌 ID。 |
| `eid` | 荷官 ID。 |
| `category` | 数据类别，只保留 `1`。 |
| `updatetime`、`sync_time`、`dt` | 订单最新版本排序和分区裁剪。 |

### 7.3 有效结算订单条件

结算订单完成最新版本去重后，必须同时满足：

```text
CAST(bet02 AS INT) = 101
CAST(category AS INT) = 1
UPPER(TRIM(bet38)) = 'N'
CAST(bet03 AS BIGINT) > 0
CAST(bet39 AS BIGINT) > 0
CAST(bet05 AS BIGINT) > 0
CAST(eid AS BIGINT) > 0
CAST(bet11 AS DECIMAL) > 0
WINDOW_START <= CAST(bet08 AS DATETIME) < WINDOW_END
```

当前玩家—荷官 SQL 没有额外使用 `bet13 > 0` 作为过滤条件；满足上述条件的最新结算订单
都进入金额归一化和后续歧义局判断。

### 7.4 金额口径

每笔有效结算订单按正汇率归一化：

```text
bet_amount = bet13 / bet11

game_pnl = (bet14 - bet13) / bet11

rebate_amount = bet16 / bet11

net_profit_amount = bet17 / bet11
```

含义：

- `bet_amount` 是归一化投注金额。
- `game_pnl` 是不含返水的纯游戏输赢；正数表示玩家赢，负数表示玩家输。
- `rebate_amount` 是归一化返水。
- `net_profit_amount` 是以 `bet17` 为权威来源的账户净变动，口径包含返水。

`net_profit_amount` 不在 SQL 中重新定义为 `game_pnl + rebate_amount`。两者的差值可用于
结算对账，但候选条件和玩家整体盈利使用正式的 `bet17 / bet11` 口径。

### 7.5 歧义荷官局完整排除

玩家物理局键：

```text
round_id + sub_round_id + table_id + player_id
= bet03 + bet04 + bet39 + bet05
```

在每个玩家物理局内统计：

```text
COUNT(DISTINCT dealer_id)
```

只保留：

```text
HAVING COUNT(DISTINCT dealer_id) = 1
```

如果同一个玩家物理局关联两个或更多不同 `eid`：

- 该玩家物理局的全部订单都从统计中排除。
- 不使用最大、最小、最新或随机方式选择一个荷官。
- 该局不进入玩家整体盈利、玩家—荷官金额、胜负、订单数或局数。

歧义排除发生在所有玩家—荷官聚合和整体盈利判断之前。

### 7.6 玩家物理局聚合

通过歧义检查后，按：

```text
round_id, sub_round_id, table_id, player_id, dealer_id
```

聚合为一行：

```text
round_bet_amount = SUM(bet_amount)
round_game_pnl = SUM(game_pnl)
round_rebate_amount = SUM(rebate_amount)
round_net_profit_amount = SUM(net_profit_amount)
round_order_count = COUNT(deduplicated settlement orders)
first_bet_time = MIN(bet08)
last_bet_time = MAX(bet08)
```

后续胜负按局级 `round_game_pnl` 判断，不按单笔订单判断。

### 7.7 玩家整体盈利

在排除歧义局之后，按玩家跨全部荷官汇总：

```text
player_overall_net_profit =
  SUM(round_net_profit_amount across all dealers)
```

只保留：

```text
player_overall_net_profit > 0
```

因此 `player_overall_net_profit`：

- 是玩家在整个统计窗口内的跨荷官整体净盈利。
- 不是玩家仅在当前 `dealer_id` 下的净盈利。
- 使用包含返水的 `net_profit_amount`。
- 同一玩家的不同荷官候选行中，该字段值相同。

### 7.8 玩家—荷官聚合

按 `player_id, dealer_id` 聚合：

```text
bet_amount = SUM(round_bet_amount)
game_pnl = SUM(round_game_pnl)
rebate_amount = SUM(round_rebate_amount)
net_profit_amount = SUM(round_net_profit_amount)

win_count =
  SUM(CASE WHEN round_game_pnl > 0 THEN 1 ELSE 0 END)

lose_count =
  SUM(CASE WHEN round_game_pnl < 0 THEN 1 ELSE 0 END)

push_count =
  SUM(CASE WHEN round_game_pnl = 0 THEN 1 ELSE 0 END)

order_count = SUM(round_order_count)
round_count = COUNT(player physical rounds)

win_rate =
  win_count / (win_count + lose_count)

first_bet_time = MIN(round first_bet_time)
last_bet_time = MAX(round last_bet_time)
```

和局不进入 `win_rate` 分母。始终满足：

```text
round_count = win_count + lose_count + push_count
order_count >= round_count
```

一局有多笔有效结算订单时，`order_count` 会大于 `round_count`。

### 7.9 候选条件

当前三个条件必须全部满足：

```text
player_overall_net_profit > 0
AND win_rate > 0.65
AND order_count > 30
```

`win_rate` 和 `order_count` 都使用严格大于。

边界示例：

| 整体净盈利 | `win_count` | `lose_count` | `win_rate` | `order_count` | 是否入选 |
|---:|---:|---:|---:|---:|---|
| `100.0000` | `13` | `7` | `0.650000` | `31` | 否，胜率必须严格大于 0.65。 |
| `100.0000` | `14` | `6` | `0.700000` | `30` | 否，订单数必须严格大于 30。 |
| `0.0000` | `14` | `6` | `0.700000` | `31` | 否，整体净盈利必须严格大于 0。 |
| `100.0000` | `14` | `6` | `0.700000` | `31` | 是。 |

### 7.10 字段字典：`business_risk_player_dealer_snapshot`

| 字段 | 类型 | 可空 | 来源/公式 | 业务含义 |
|---|---|---:|---|---|
| `as_of_time` | `DATETIME` | 否 | `TIMESTAMP(AS_OF_TIME)` | 本批完整快照的数据截止时间和版本号。 |
| `player_id` | `BIGINT` | 否 | `CAST(bet05 AS BIGINT)` | 玩家 ID。 |
| `dealer_id` | `BIGINT` | 否 | 唯一且有效的 `CAST(eid AS BIGINT)` | 通过歧义局检查后的荷官 ID。 |
| `window_start` | `DATETIME` | 否 | `TIMESTAMP(WINDOW_START)` | 统计窗口开始时间，包含边界。 |
| `window_end` | `DATETIME` | 否 | `TIMESTAMP(WINDOW_END)` | 统计窗口结束时间，不包含边界。 |
| `bet_amount` | `DECIMAL(20,4)` | 否 | `SUM(bet13 / bet11)` | 玩家与该荷官关联订单的归一化投注金额合计。 |
| `game_pnl` | `DECIMAL(20,4)` | 否 | `SUM((bet14 - bet13) / bet11)` | 不含返水的纯游戏输赢合计；正数表示玩家盈利。 |
| `rebate_amount` | `DECIMAL(20,4)` | 否 | `SUM(bet16 / bet11)` | 玩家与该荷官关联订单的归一化返水合计。 |
| `net_profit_amount` | `DECIMAL(20,4)` | 否 | `SUM(bet17 / bet11)` | 玩家与该荷官关联的结算净盈利/账户净变动，包含返水。 |
| `player_overall_net_profit` | `DECIMAL(20,4)` | 否 | 玩家跨全部荷官 `SUM(net_profit_amount)` | 玩家在整个统计窗口内、排除歧义局后的整体净盈利。 |
| `win_count` | `BIGINT` | 否 | 局级 `game_pnl > 0` 的物理局数 | 玩家与该荷官关联的胜局数。 |
| `lose_count` | `BIGINT` | 否 | 局级 `game_pnl < 0` 的物理局数 | 玩家与该荷官关联的负局数。 |
| `push_count` | `BIGINT` | 否 | 局级 `game_pnl = 0` 的物理局数 | 玩家与该荷官关联的和局数。 |
| `win_rate` | `DECIMAL(9,6)` | 否 | `win_count / (win_count + lose_count)` | 非和局胜率，和局不进入分母。 |
| `order_count` | `BIGINT` | 否 | 去重结算订单数合计 | 玩家与该荷官关联的有效结算订单数。 |
| `round_count` | `BIGINT` | 否 | 玩家物理局 `COUNT(*)` | 玩家与该荷官关联的去重物理局数。 |
| `first_bet_time` | `DATETIME` | 是 | `MIN(bet08)` | 玩家与该荷官关联的第一笔有效投注时间。 |
| `last_bet_time` | `DATETIME` | 是 | `MAX(bet08)` | 玩家与该荷官关联的最后一笔有效投注时间。 |
| `created_time` | `DATETIME` | 否 | `CURRENT_TIMESTAMP()` | 本快照行的实际创建时间。 |

## 8. StarRocks 到 MySQL 发布

### 8.1 表映射

| StarRocks 完整快照 | MySQL API 投影 |
|---|---|
| `business_risk_late_bet_snapshot` | `business_risk_late_bet_stat` |
| `business_risk_same_table_pair_snapshot` | `business_risk_same_table_pair_stat` |
| `business_risk_player_dealer_snapshot` | `business_risk_player_dealer_stat` |

三组表字段一一对应，MySQL 不重新计算比例、金额或阈值。

### 8.2 同版本发布幂等

每类 MySQL 发布先执行：

```sql
DELETE FROM <mysql_stat_table>
WHERE as_of_time = '${AS_OF_TIME}';
```

再从对应 StarRocks 快照导出相同 `as_of_time` 的全部行并插入 MySQL。
因此失败后可以对尚未 READY 的同一版本完整重跑，不会累计重复数据。

### 8.3 行数验证

在写 READY 之前，工作流逐项比较：

```text
StarRocks business_risk_late_bet_snapshot 行数
  = MySQL business_risk_late_bet_stat 行数

StarRocks business_risk_same_table_pair_snapshot 行数
  = MySQL business_risk_same_table_pair_stat 行数

StarRocks business_risk_player_dealer_snapshot 行数
  = MySQL business_risk_player_dealer_stat 行数
```

任何一组不一致都停止发布 READY。

### 8.4 READY 指针

三张 MySQL 投影全部成功且行数一致后，写入或更新：

```text
business_risk_publish_state
dataset_name = 'BACCARAT_BUSINESS_RISK'
publish_status = 'READY'
as_of_time = 本次 AS_OF_TIME
```

同时记录：

- `window_start`
- `window_end`
- 三张表各自行数
- `published_at`
- `update_time`

API 查询必须连接该状态行，并且只返回：

```text
结果表 as_of_time = READY as_of_time
```

未 READY 的版本即使已经写入部分 MySQL 表，也不会被 API 返回。

## 9. 历史版本和清理

默认保留：

```text
BUSINESS_RISK_SNAPSHOT_RETENTION_DAYS = 7
```

StarRocks 和 MySQL 都删除早于保留窗口的历史版本，但始终排除当前 READY
`as_of_time`，即当前 READY 版本不会因为时间过旧而被清理。

清理只影响历史版本：

- 不改变统计公式。
- 不改变当前 READY 指针。
- 不使用 MySQL 投影重建 StarRocks。

## 10. 可复制核验 SQL

以下示例使用：

```text
AS_OF_TIME = 2026-07-31 15:00:00
```

执行前只需要把该时间替换为待核验版本。

### 10.1 StarRocks 三张快照行数

```sql
SELECT 'late_bet' AS dataset, COUNT(*) AS row_count
FROM wm_live_risk.business_risk_late_bet_snapshot
WHERE as_of_time = TIMESTAMP('2026-07-31 15:00:00')
UNION ALL
SELECT 'same_table' AS dataset, COUNT(*) AS row_count
FROM wm_live_risk.business_risk_same_table_pair_snapshot
WHERE as_of_time = TIMESTAMP('2026-07-31 15:00:00')
UNION ALL
SELECT 'player_dealer' AS dataset, COUNT(*) AS row_count
FROM wm_live_risk.business_risk_player_dealer_snapshot
WHERE as_of_time = TIMESTAMP('2026-07-31 15:00:00');
```

三类都允许结果为 0；0 行不等于任务失败。是否合理应结合源数据和阈值判断。

### 10.2 后段投注不变量

期望返回 `0`：

```sql
SELECT COUNT(*) AS violation_count
FROM wm_live_risk.business_risk_late_bet_snapshot
WHERE as_of_time = TIMESTAMP('2026-07-31 15:00:00')
  AND (
       late_order_count <= 50
    OR total_order_count < late_order_count
    OR late_order_rate < CAST(0.60 AS DECIMAL(9,6))
    OR late_order_rate > CAST(1 AS DECIMAL(9,6))
    OR late_order_rate <> CAST(
         CAST(late_order_count AS DECIMAL(38,8))
         / NULLIF(CAST(total_order_count AS DECIMAL(38,8)), 0)
         AS DECIMAL(9,6)
       )
  );
```

### 10.3 同桌/对打不变量

期望返回 `0`：

```sql
SELECT COUNT(*) AS violation_count
FROM wm_live_risk.business_risk_same_table_pair_snapshot
WHERE as_of_time = TIMESTAMP('2026-07-31 15:00:00')
  AND (
       player_a >= player_b
    OR same_round_count < 100
    OR same_rate < CAST(0.20 AS DECIMAL(9,6))
    OR opposite_rate < CAST(0.70 AS DECIMAL(9,6))
    OR opposite_round_count < 0
    OR opposite_round_count > same_round_count
    OR same_rate <> CAST(
         CAST(same_round_count AS DECIMAL(38,8))
         / NULLIF(
             CAST(
               LEAST(player_a_round_count, player_b_round_count)
               AS DECIMAL(38,8)
             ),
             0
           )
         AS DECIMAL(9,6)
       )
    OR opposite_rate <> CAST(
         CAST(opposite_round_count AS DECIMAL(38,8))
         / NULLIF(CAST(same_round_count AS DECIMAL(38,8)), 0)
         AS DECIMAL(9,6)
       )
  );
```

### 10.4 玩家—荷官不变量

期望返回 `0`：

```sql
SELECT COUNT(*) AS violation_count
FROM wm_live_risk.business_risk_player_dealer_snapshot
WHERE as_of_time = TIMESTAMP('2026-07-31 15:00:00')
  AND (
       player_overall_net_profit <= CAST(0 AS DECIMAL(20,4))
    OR win_rate <= CAST(0.65 AS DECIMAL(9,6))
    OR win_rate > CAST(1 AS DECIMAL(9,6))
    OR order_count <= 30
    OR order_count < round_count
    OR round_count <> win_count + lose_count + push_count
    OR win_rate <> CAST(
         CAST(win_count AS DECIMAL(38,8))
         / NULLIF(
             CAST(win_count + lose_count AS DECIMAL(38,8)),
             0
           )
         AS DECIMAL(9,6)
       )
  );
```

检查同一玩家的 `player_overall_net_profit` 是否保持一致，期望返回 0 行：

```sql
SELECT player_id,
       COUNT(DISTINCT player_overall_net_profit) AS overall_profit_versions
FROM wm_live_risk.business_risk_player_dealer_snapshot
WHERE as_of_time = TIMESTAMP('2026-07-31 15:00:00')
GROUP BY player_id
HAVING COUNT(DISTINCT player_overall_net_profit) <> 1;
```

### 10.5 `bet17` 净盈利对账信息

以下查询用于观察 `bet17` 正式净盈利与“游戏输赢 + 返水”的差值，不应直接把非 0
差值当作候选快照错误：

```sql
SELECT player_id,
       dealer_id,
       game_pnl,
       rebate_amount,
       net_profit_amount,
       net_profit_amount - (game_pnl + rebate_amount)
           AS reconciliation_delta
FROM wm_live_risk.business_risk_player_dealer_snapshot
WHERE as_of_time = TIMESTAMP('2026-07-31 15:00:00')
ORDER BY ABS(net_profit_amount - (game_pnl + rebate_amount)) DESC
LIMIT 100;
```

统计、整体盈利和 API 返回的净盈利继续以 `net_profit_amount` 为准。

### 10.6 源数据歧义荷官局

以下 StarRocks SQL 列出窗口内被完整排除的多荷官玩家物理局：

```sql
WITH ranked AS (
    SELECT
        CAST(bet01 AS BIGINT) AS bet_id,
        CAST(bet03 AS BIGINT) AS round_id,
        CAST(bet04 AS INT) AS sub_round_id,
        CAST(bet39 AS BIGINT) AS table_id,
        CAST(bet05 AS BIGINT) AS player_id,
        CAST(eid AS BIGINT) AS dealer_id,
        CAST(bet02 AS INT) AS game_type,
        CAST(category AS INT) AS category,
        UPPER(TRIM(CAST(bet38 AS STRING))) AS regrade_flag,
        CAST(bet11 AS DECIMAL(38,8)) AS exchange_rate,
        ROW_NUMBER() OVER (
            PARTITION BY CAST(bet01 AS BIGINT)
            ORDER BY CAST(updatetime AS DATETIME) DESC,
                     CAST(sync_time AS DATETIME) DESC,
                     CAST(dt AS DATE) DESC,
                     CAST(bet01 AS BIGINT) DESC
        ) AS row_num
    FROM ods_mariadb_2b.ods_a168_bet02
    WHERE CAST(dt AS DATE) >= DATE_SUB(
              DATE('2026-07-01 15:00:00'), INTERVAL 1 DAY
          )
      AND CAST(dt AS DATE) < DATE_ADD(
              DATE('2026-07-31 15:00:00'), INTERVAL 1 DAY
          )
      AND CAST(bet08 AS DATETIME) >= TIMESTAMP('2026-07-01 15:00:00')
      AND CAST(bet08 AS DATETIME) < TIMESTAMP('2026-07-31 15:00:00')
),
valid_orders AS (
    SELECT round_id,
           sub_round_id,
           table_id,
           player_id,
           dealer_id
    FROM ranked
    WHERE row_num = 1
      AND game_type = 101
      AND category = 1
      AND regrade_flag = 'N'
      AND round_id > 0
      AND table_id > 0
      AND player_id > 0
      AND dealer_id > 0
      AND exchange_rate > CAST(0 AS DECIMAL(38,8))
)
SELECT round_id,
       sub_round_id,
       table_id,
       player_id,
       COUNT(DISTINCT dealer_id) AS dealer_count
FROM valid_orders
GROUP BY round_id, sub_round_id, table_id, player_id
HAVING COUNT(DISTINCT dealer_id) <> 1
ORDER BY dealer_count DESC,
         round_id,
         sub_round_id,
         table_id,
         player_id;
```

### 10.7 MySQL READY 和三张投影行数

在 API MySQL 执行：

```sql
SELECT dataset_name,
       as_of_time,
       window_start,
       window_end,
       publish_status,
       late_bet_row_count,
       same_table_row_count,
       player_dealer_row_count,
       published_at,
       update_time
FROM business_risk_publish_state
WHERE dataset_name = 'BACCARAT_BUSINESS_RISK';
```

核对 READY 版本的实际行数：

```sql
SELECT 'late_bet' AS dataset, COUNT(*) AS actual_row_count
FROM business_risk_late_bet_stat
WHERE as_of_time = (
    SELECT as_of_time
    FROM business_risk_publish_state
    WHERE dataset_name = 'BACCARAT_BUSINESS_RISK'
      AND publish_status = 'READY'
)
UNION ALL
SELECT 'same_table' AS dataset, COUNT(*) AS actual_row_count
FROM business_risk_same_table_pair_stat
WHERE as_of_time = (
    SELECT as_of_time
    FROM business_risk_publish_state
    WHERE dataset_name = 'BACCARAT_BUSINESS_RISK'
      AND publish_status = 'READY'
)
UNION ALL
SELECT 'player_dealer' AS dataset, COUNT(*) AS actual_row_count
FROM business_risk_player_dealer_stat
WHERE as_of_time = (
    SELECT as_of_time
    FROM business_risk_publish_state
    WHERE dataset_name = 'BACCARAT_BUSINESS_RISK'
      AND publish_status = 'READY'
);
```

三项实际行数应分别等于 `business_risk_publish_state` 中记录的：

```text
late_bet_row_count
same_table_row_count
player_dealer_row_count
```

## 11. 计算口径速查

| 风控项 | 统计维度 | 当前候选条件 | 主要输出 |
|---|---|---|---|
| 后段投注 | 玩家 | `bet04 >= 40`，且 `late_order_rate >= 0.60`，且 `late_order_count > 50` | 玩家、后段订单数、总订单数、后段比例 |
| 同桌/对打 | 规范化玩家对 | `same_round_count >= 100`，且 `same_rate >= 0.20`，且 `opposite_rate >= 0.70` | 玩家 A/B、共同局数、同桌率、对打局数、对打率 |
| 玩家—荷官 | 玩家—唯一荷官 | 玩家整体净盈利 `> 0`，且非和局胜率 `> 0.65`，且订单数 `> 30` | 玩家、荷官、金额、胜负和、胜率、订单数、局数 |

## 12. 重要结论

- 三张 StarRocks 表都是按 `as_of_time` 版本化的候选快照，不是累计表。
- `as_of_time` 是数据截止时间和发布版本；`created_time` 是物理写入时间。
- 后段投注的 `late_order_count` 是订单数，不是局数。
- 同桌计算先按玩家物理局去重，多笔订单不会重复增加同桌局数。
- 同桌局数、同桌率、对打率三个条件必须同时满足。
- 玩家—荷官先完整排除歧义局，不随机选择荷官。
- 玩家—荷官胜率按物理局计算，和局不进入分母。
- `net_profit_amount` 和 `player_overall_net_profit` 使用包含返水的 `bet17` 净盈利口径。
- `order_count` 是去重结算订单数，`round_count` 是去重物理局数。
- 三张 MySQL 投影全部完成且行数一致后才发布 READY。
