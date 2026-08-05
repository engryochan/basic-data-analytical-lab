# API 服务边界

`wm-trueman-risk` 不提供 HTTP 接口。它负责生成并维护 API MySQL 投影表；独立项目 `wm-trueman-risk-api` 负责鉴权、查询、缓存和审计。

## 1. 数据交付边界

```text
wm-trueman-risk
  StarRocks 小时事实
    -> 重算受影响键
    -> API MySQL player_pair_stat / dealer_profit_stat
        -> wm-trueman-risk-api
            -> Redis/Valkey 缓存
            -> HTTP 客户端
```

API 服务只读取 MySQL，不直接访问：

- 源 MariaDB
- S3 ODS
- StarRocks
- Spark 或 Livy

API MySQL 是查询投影，不是完整事实仓库。改变投影阈值或执行数据恢复时，应从 StarRocks 小时事实重算。

## 2. 投影表

### 2.1 player_pair_stat

主键：

```text
player_a + player_b
```

玩家 ID 始终规范为 `player_a < player_b`。核心字段：

| 字段 | 含义 |
|---|---|
| `same_round_count` | 累计共同回合数 |
| `player_a_rounds` | 玩家 A 累计回合数 |
| `player_b_rounds` | 玩家 B 累计回合数 |
| `same_rate` | 共同回合数除以两人较小的回合数 |
| `first_game_time` | 首次共同出现时间 |
| `last_game_time` | 最近共同出现时间 |

默认投影条件：

```sql
(same_round_count >= 3
 AND LEAST(player_a_rounds, player_b_rounds) >= 5
 AND same_rate >= 0.3)
OR same_round_count >= 10
```

### 2.2 dealer_profit_stat

主键：

```text
dealer_id + game_id + player_id
```

`valid_bet`、`turnover`、`profit` 和 `profit_per_bet` 都使用人民币金额口径。正 `profit` 表示玩家盈利。

默认投影条件：

```sql
(bet_count >= 20
 AND valid_bet >= 1000
 AND profit > 0
 AND player_roi >= 0.2)
OR profit >= 10000
```

`risk_score=0`、`risk_level='UNKNOWN'`，以及荷官均值、标准差和偏差相关字段均为预留值。接口使用者不应将它们解释为已计算的风险等级。

## 3. 查询接口概览

API 服务提供：

```text
GET /v1/risk/player-pairs/players/{playerId}
GET /v1/risk/player-pairs/evaluate
GET /v1/risk/player-pairs/top
GET /v1/risk/dealer-profit/dealers/{dealerId}/players
GET /v1/risk/dealer-profit/players/{playerId}
GET /v1/risk/dealer-profit/anomalies
GET /v1/risk/players/{playerId}/profile
POST /internal/cache/risk/evict-all
POST /internal/cache/risk/evict-keys
```

分页查询默认 `limit=50`，最大 500，`offset=0`。响应中的 `count` 是本次返回行数，不是总记录数。

完整的签名、请求参数、响应字段和错误码见 API 项目：

- `wm-trueman-risk-api/docs/API_USAGE.md`
- `wm-trueman-risk-api/docs/API_REFERENCE.md`

## 4. 缓存一致性

API 查询结果默认缓存 10 分钟。以下操作完成并通过数据校验后应清理相关缓存：

- 小时投影刷新影响了已查询的玩家或荷官。
- 历史数据补数完成。
- 调整投影阈值并重建投影。
- 人工修正 API MySQL 投影数据。

使用具有 `risk:cache:evict` 权限的客户端调用：

```text
POST /internal/cache/risk/evict-all
```

或使用 API 部署包脚本：

```bash
export RISK_API_BASE_URL="https://<risk-api>"
export RISK_API_KEY="<cache-admin-key>"
export RISK_API_SECRET="<cache-admin-secret>"

bash /opt/wm-risk-api/scripts/evict-risk-cache.sh all
```

## 5. 表结构协作

投影表规范 DDL 位于 `wm-trueman-risk/sql/mysql_api.sql`。API 项目的 Flyway migration 也会为新环境创建对应表结构。修改列、类型、主键或索引时，必须同时核对：

- 离线任务写入列。
- `sql/mysql_api.sql`。
- API 项目 Flyway migration。
- API Repository 查询和 DTO。
- 缓存 key 与排序规则。

表结构发布应先保证 API 能兼容目标结构，再切换离线写入，最后进行数据校验和缓存清理。
