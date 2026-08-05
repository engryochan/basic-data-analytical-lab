-- ==============================================================================
-- 同桌特征_按月分批版.sql
-- ==============================================================================
-- 【为什么退回分批】126天全量一次性做自连接，这次连续两次撞上不同BE节点
-- 的内存上限(第一次89.7GB/96.4GB，第二次80.9GB/96.4GB)——同一条查询在
-- 内存压力不同的两个节点上都失败，说明问题是查询本身峰值内存需求太高，
-- 不是"运气不好撞上正忙的节点"。之前跑通过一次全量(12.7分钟，62,245人)，
-- 很可能是当时集群恰好负载较低才侥幸成功，不能依赖这种运气。
--
-- 退回按月分批：每批只处理约30天数据，之前验证过1个月耗时约68.5秒、
-- 内存峰值远低于全量——用多次小查询换取稳定性，这是应对"共享集群资源、
-- 负载会波动"这种现实情况的正规做法，不是权宜之计。
-- ==============================================================================

SET query_timeout = 1800;

-- 【重要说明：分批阈值的取舍，不是可以随便设的数字】
-- 完全不设HAVING筛选：每批要导出"哪怕只同桌1次"的全部配对组合——
-- 已知同一局平均涉及62.7个玩家、最多358个，组合数会极其庞大，
-- 反而可能制造出新的内存/下载压力，等于没解决问题。
-- 每批仍设HAVING>50：会漏掉"分散在多个月、每月没到50但总数过线"的
-- 真实团伙(比如5个月各11局，合计55局，这类情况会被完全漏掉)。
-- 折中方案：每批设一个很低的门槛(同桌≥3局)，只过滤掉"偶然撞见1-2次"
-- 这种绝大多数是噪音的组合，既能把单批结果集压缩到可控规模，又只有
-- 极小概率漏掉"连续多月都恰好只出现1-2次却总数过线"这种边缘情况——
-- 这是精度与稳定性之间的务实折中，不是理论上最严谨的解法，如实说明。

-- ---- 第1批：3月21-31日(11天) ----
WITH 同桌配对统计_批1 AS (
    SELECT a.bet05 AS uid1, b.bet05 AS uid2, COUNT(DISTINCT a.bet03) AS 同桌局数
    FROM ods_mariadb_2b.ods_a168_bet01 a
    JOIN ods_mariadb_2b.ods_a168_bet01 b
      ON a.bet03 = b.bet03 AND a.bet05 < b.bet05 AND a.dt = b.dt
    WHERE a.dt BETWEEN '2026-03-21' AND '2026-03-31'
    GROUP BY a.bet05, b.bet05
    HAVING COUNT(DISTINCT a.bet03) >= 3                                   -- 低门槛，只滤掉偶然噪音，不是最终判定阈值
)
SELECT uid1, uid2, 同桌局数 FROM 同桌配对统计_批1;
-- 下载为：同桌配对_批1_0321-0331.csv


-- ---- 第2批：4月1-30日 ----
SET query_timeout = 1800;
WITH 同桌配对统计_批2 AS (
    SELECT a.bet05 AS uid1, b.bet05 AS uid2, COUNT(DISTINCT a.bet03) AS 同桌局数
    FROM ods_mariadb_2b.ods_a168_bet01 a
    JOIN ods_mariadb_2b.ods_a168_bet01 b
      ON a.bet03 = b.bet03 AND a.bet05 < b.bet05 AND a.dt = b.dt
    WHERE a.dt BETWEEN '2026-04-01' AND '2026-04-30'
    GROUP BY a.bet05, b.bet05
    HAVING COUNT(DISTINCT a.bet03) >= 3
)
SELECT uid1, uid2, 同桌局数 FROM 同桌配对统计_批2;
-- 下载为：同桌配对_批2_0401-0430.csv


-- ---- 第3批：5月1-31日 ----
SET query_timeout = 1800;
WITH 同桌配对统计_批3 AS (
    SELECT a.bet05 AS uid1, b.bet05 AS uid2, COUNT(DISTINCT a.bet03) AS 同桌局数
    FROM ods_mariadb_2b.ods_a168_bet01 a
    JOIN ods_mariadb_2b.ods_a168_bet01 b
      ON a.bet03 = b.bet03 AND a.bet05 < b.bet05 AND a.dt = b.dt
    WHERE a.dt BETWEEN '2026-05-01' AND '2026-05-31'
    GROUP BY a.bet05, b.bet05
    HAVING COUNT(DISTINCT a.bet03) >= 3
)
SELECT uid1, uid2, 同桌局数 FROM 同桌配对统计_批3;
-- 下载为：同桌配对_批3_0501-0531.csv


-- ---- 第4批：6月1-30日 ----
SET query_timeout = 1800;
WITH 同桌配对统计_批4 AS (
    SELECT a.bet05 AS uid1, b.bet05 AS uid2, COUNT(DISTINCT a.bet03) AS 同桌局数
    FROM ods_mariadb_2b.ods_a168_bet01 a
    JOIN ods_mariadb_2b.ods_a168_bet01 b
      ON a.bet03 = b.bet03 AND a.bet05 < b.bet05 AND a.dt = b.dt
    WHERE a.dt BETWEEN '2026-06-01' AND '2026-06-30'
    GROUP BY a.bet05, b.bet05
    HAVING COUNT(DISTINCT a.bet03) >= 3
)
SELECT uid1, uid2, 同桌局数 FROM 同桌配对统计_批4;
-- 下载为：同桌配对_批4_0601-0630.csv


-- ---- 第5批：7月1-24日 ----
SET query_timeout = 1800;
WITH 同桌配对统计_批5 AS (
    SELECT a.bet05 AS uid1, b.bet05 AS uid2, COUNT(DISTINCT a.bet03) AS 同桌局数
    FROM ods_mariadb_2b.ods_a168_bet01 a
    JOIN ods_mariadb_2b.ods_a168_bet01 b
      ON a.bet03 = b.bet03 AND a.bet05 < b.bet05 AND a.dt = b.dt
    WHERE a.dt BETWEEN '2026-07-01' AND '2026-07-24'
    GROUP BY a.bet05, b.bet05
    HAVING COUNT(DISTINCT a.bet03) >= 3
)
SELECT uid1, uid2, 同桌局数 FROM 同桌配对统计_批5;
-- 下载为：同桌配对_批5_0701-0724.csv


-- ==============================================================================
-- 五批CSV下载完成后，本地合并 + 跨批累加 + 最终筛选(R代码)：
--
-- library(data.table)
-- 批1 <- fread("同桌配对_批1_0321-0331.csv")
-- 批2 <- fread("同桌配对_批2_0401-0430.csv")
-- 批3 <- fread("同桌配对_批3_0501-0531.csv")
-- 批4 <- fread("同桌配对_批4_0601-0630.csv")
-- 批5 <- fread("同桌配对_批5_0701-0724.csv")
-- 全部批次 <- rbindlist(list(批1, 批2, 批3, 批4, 批5))
--
-- # 关键一步：同一对(uid1,uid2)可能分散在不同批次里各出现一次，
-- # 必须先按(uid1,uid2)把跨批次的同桌局数加总，再做>50这个筛选，
-- # 不能在每一批各自筛完之后才合并(那样会漏掉"分散在两个月、
-- # 合计过线"的配对)
-- 汇总 <- 全部批次[, .(同桌局数 = sum(同桌局数)), by = .(uid1, uid2)]
-- 候选_同桌异常 <- 汇总[同桌局数 > 50]
-- fwrite(候选_同桌异常, "候选_同桌异常_最终版.csv")
-- ==============================================================================
