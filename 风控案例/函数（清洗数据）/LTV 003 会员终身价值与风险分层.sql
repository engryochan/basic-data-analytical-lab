/* ============================================================
   商君风控体系 · 会员终身价值(LTV) × 行为风险 分层
   ------------------------------------------------------------
   数据来源：ods_mariadb_2b.ods_a168_dailyreport_member（会员日报表）
   —— 注意：不是 bet01，bet01 里没有"派彩金额"这个字段。
   字段含义（来自字典 glimpse.ods_a168_dailyreport_member.csv，
   与此前排查记录里 bet01/wallet_reporter/commission 的结论并不冲突，
   是同一份字典里此前没测过的另一张表）：
     bet05 = 会员编号        bet02 = 游戏编号（待与game_type核对）
     bet13 = 下注金额        bet14 = 派彩金额  ← 这两个此前从未组合测试过
     bet41 = 有效投注         bet15 = 会员退水%数
     bet28~32 = LV1~LV5退水（按数值量级判断像是金额,不是%,见0节校验）
   ⚠️ 本文件基于字典的字段注释，字典注释权威性高于此前的猜测排查，
   但尚未像此前四个候选字段一样做过真实数据实测。正式使用前，
   请先跑第0节，10秒内可判断这条路径是否成立。
   ============================================================ */


-- ============================================================
-- 0. 字段校验 —— 判断 bet14-bet13 是否真的是盈亏，不是又一个"伪盈亏"
-- ============================================================
SELECT
    COUNT(*)                                                          AS 总行数,
    SUM(CASE WHEN CAST(bet14 AS DECIMAL(18,4))
                 - CAST(bet13 AS DECIMAL(18,4)) > 0 THEN 1 ELSE 0 END) AS 净赢行数,
    SUM(CASE WHEN CAST(bet14 AS DECIMAL(18,4))
                 - CAST(bet13 AS DECIMAL(18,4)) < 0 THEN 1 ELSE 0 END) AS 净输行数,
    MIN(CAST(bet14 AS DECIMAL(18,4)) - CAST(bet13 AS DECIMAL(18,4)))   AS 净输赢_最小值,
    MAX(CAST(bet14 AS DECIMAL(18,4)) - CAST(bet13 AS DECIMAL(18,4)))   AS 净输赢_最大值,
    AVG(CAST(bet41 AS DECIMAL(18,4)) / NULLIF(CAST(bet13 AS DECIMAL(18,4)),0)) AS 有效投注_除以_下注额_均值,
    AVG(CAST(bet28 AS DECIMAL(18,4)))                                  AS LV1退水_均值_看量级像金额还是百分比
FROM ods_mariadb_2b.ods_a168_dailyreport_member
WHERE dt BETWEEN '2026-03-21' AND '2026-07-24';
/*
 期望结果：净赢行数、净输行数都不是0（有正有负，才是真盈亏）。
 如果和当初的 bet41 一样，比值又稳定卡在某个固定区间——说明这条路径
 也是假线索，此节应立刻停止，回去用第2章8节的结论，不要往下跑。
 同时顺手确认 bet02 是否真的能跟 game_type.code 对上（见下方1.3节注释）。
*/


-- ============================================================
-- 1. 会员级 LTV 明细
-- ============================================================
WITH 会员日粒度 AS (
    SELECT
        CAST(bet05 AS BIGINT)                          AS uid,
        dt,
        CAST(bet13 AS DECIMAL(18,4))                   AS 下注金额,
        CAST(bet14 AS DECIMAL(18,4))                   AS 派彩金额,
        CAST(bet41 AS DECIMAL(18,4))                   AS 有效投注,
        COALESCE(CAST(bet28 AS DECIMAL(18,4)),0)
      + COALESCE(CAST(bet29 AS DECIMAL(18,4)),0)
      + COALESCE(CAST(bet30 AS DECIMAL(18,4)),0)
      + COALESCE(CAST(bet31 AS DECIMAL(18,4)),0)
      + COALESCE(CAST(bet32 AS DECIMAL(18,4)),0)        AS 五级退水合计,
        CAST(bet02 AS INT)                              AS 游戏编号
    FROM ods_mariadb_2b.ods_a168_dailyreport_member
    WHERE dt BETWEEN '2026-03-21' AND '2026-07-24'
),

会员汇总 AS (
    SELECT
        uid,
        MIN(dt)                                AS 首次活跃日,
        MAX(dt)                                AS 最近活跃日,
        DATEDIFF('2026-07-24', MAX(dt))        AS 距今未活跃天数,
        COUNT(DISTINCT dt)                     AS 活跃天数,
        SUM(下注金额)                          AS 总下注额,
        SUM(有效投注)                          AS 总有效投注额,
        SUM(派彩金额)                          AS 总派彩额,
        SUM(派彩金额) - SUM(下注金额)          AS 会员净输赢,        -- 正=会员净赢(平台净输), 负=会员净输(平台净赢)
        SUM(五级退水合计)                      AS 总返水成本,
        COUNT(DISTINCT 游戏编号)               AS 涉及产品数
    FROM 会员日粒度
    GROUP BY uid
),

-- 1.3 主力产品：按下注额最高的游戏编号，JOIN game_type取名字
-- ⚠️ dailyreport_member.bet02 注释是"遊戲編號"，bet01.bet02 注释是"遊戲類別編號"，
--    两者是否是同一套编码体系、能否共用 game_type.code，第0节校验之外再单独跑：
--    SELECT DISTINCT 游戏编号 FROM 会员日粒度 LEFT JOIN ods_a168_game_type ON ... 看有没有大量对不上
主力产品 AS (
    SELECT uid, 游戏编号 AS 主力产品编号
    FROM (
        SELECT uid, 游戏编号,
               ROW_NUMBER() OVER (PARTITION BY uid ORDER BY SUM(下注金额) DESC) AS rn
        FROM 会员日粒度
        GROUP BY uid, 游戏编号
    ) t
    WHERE rn = 1
),

LTV计算 AS (
    SELECT
        s.*,
        gt.cnname                                                          AS 主力产品名称,
        (-1 * s.会员净输赢) - s.总返水成本                                  AS 平台净贡献,      -- 分子：平台从该会员身上的真实净收益
        ROUND((-1*s.会员净输赢 - s.总返水成本) / NULLIF(s.总下注额,0), 4)   AS 平台ROI,        -- 每一元流水换回多少净收益
        ROUND(s.总返水成本 / NULLIF(s.总下注额,0), 4)                       AS 综合返水率
    FROM 会员汇总 s
    LEFT JOIN 主力产品 p ON s.uid = p.uid
    LEFT JOIN ods_mariadb_2b.ods_a168_game_type gt ON p.主力产品编号 = gt.code
)

SELECT
    uid, 首次活跃日, 最近活跃日, 距今未活跃天数, 活跃天数,
    总下注额, 总有效投注额, 总派彩额, 会员净输赢, 总返水成本,
    平台净贡献, 平台ROI, 综合返水率, 涉及产品数, 主力产品名称,

    -- 价值分层：用分位数而不是写死的金额门槛——具体量级取决于真实币种/流水规模，
    -- 门槛数字务必按下面算出来的真实分布再定，不要直接照抄
    NTILE(10) OVER (ORDER BY 平台净贡献 DESC)   AS 净贡献十分位_1最高,

    CASE
        WHEN 距今未活跃天数 <= 7  THEN '活跃'
        WHEN 距今未活跃天数 <= 30 THEN '沉睡预警'
        ELSE '流失'
    END                                          AS 生命周期状态
FROM LTV计算
ORDER BY 平台净贡献 DESC;


-- ============================================================
-- 2. 价值 × 行为风险矩阵（对接已有的团伙同桌/策略性投注高置信度名单）
--    需先把 02_真实数据/双重命中_策略性投注与团伙同桌.csv 落库，
--    这里假设表名为 dwd.风控高置信度名单(uid)，请按实际路径调整
-- ============================================================
WITH LTV基础 AS (
    -- 把上面第1节的完整查询在这里再跑一遍（或改成先建成中间表 dwd.会员LTV，
    -- 再从这里 SELECT * FROM dwd.会员LTV，避免重复计算，取决于是否要建表）
    SELECT uid, 平台净贡献, 平台ROI,
           NTILE(10) OVER (ORDER BY 平台净贡献 DESC) AS 净贡献十分位
    FROM ( /* 同第1节 LTV计算 CTE 的聚合逻辑 */ SELECT
             CAST(bet05 AS BIGINT) AS uid,
             SUM(CAST(bet14 AS DECIMAL(18,4))) - SUM(CAST(bet13 AS DECIMAL(18,4)))
               - SUM(COALESCE(CAST(bet28 AS DECIMAL(18,4)),0)+COALESCE(CAST(bet29 AS DECIMAL(18,4)),0)
                    +COALESCE(CAST(bet30 AS DECIMAL(18,4)),0)+COALESCE(CAST(bet31 AS DECIMAL(18,4)),0)
                    +COALESCE(CAST(bet32 AS DECIMAL(18,4)),0)) AS 会员净贡献占位
           FROM ods_mariadb_2b.ods_a168_dailyreport_member
           WHERE dt BETWEEN '2026-03-21' AND '2026-07-24'
           GROUP BY CAST(bet05 AS BIGINT)
         ) x
    -- 上面这段偷懒写法仅作示意，正式使用请直接复用第1节完整的LTV计算CTE
)
SELECT
    l.uid, l.净贡献十分位, l.平台ROI,
    CASE WHEN r.uid IS NOT NULL THEN '高置信度行为风险' ELSE '未触发' END AS 行为风险标记,
    CASE
        WHEN l.净贡献十分位 <= 2 AND r.uid IS NOT NULL THEN '优先人工复核+回查录像（高价值不代表免检，但先核实身份再动作，避免误伤真实大客户）'
        WHEN l.净贡献十分位 >  2 AND r.uid IS NOT NULL THEN '按SOP直接限制返水/冻结排查'
        WHEN l.净贡献十分位 <= 2 AND r.uid IS NULL      THEN '重点维护，差异化权益（专属客服/生日礼遇）'
        ELSE '常规监控'
    END AS 建议动作
FROM LTV基础 l
LEFT JOIN dwd.风控高置信度名单 r ON l.uid = r.uid
ORDER BY l.净贡献十分位, l.平台ROI DESC;
