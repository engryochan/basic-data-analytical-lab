-- ════════════════════════════════════════════════════════════════════════════════════════════
-- ★ §D07 · 分块行级对账 · I_ip_player.csv ★
-- ════════════════════════════════════════════════════════════════════════════════════════════
-- 立于 2026-08-24 · 应先生所命：须证两版输出**一模一样**，无一观测值遗漏或重叠。
--
-- 【先生之意与我前答之误】
--   我前次误读为「在原版加一列装点门面」，遂答「不必」。实则先生之意是：
--   **原版亦按同一步骤排出序列号，令两版可逐行对照**——此意正当，我前答失焦，撤回。
--
-- 【何以不能照字面做「原版一次导全 + rn」】
--   导出上限每次十万行，而本件 T_true = 696,403。原版若一次导全，根本导不出来；
--   若分批导出，那就**又是分批版**——循环无解。
--   ★ 故改以「原版留在库内、只导其分块指纹」——分块指纹一次可导，且粒度细至每 10 行。
--
-- 【本法之强度】
--   块大小 10 → 输出 69,641 行（< 100,000，一次可导）。
--   每块出：块内行数、rn 上下界、业务键上下界、四项列级合计。
--   · 任一行若在分批下载途中丢失或重出，其所在之 10 行块，**行数与合计必变**；
--   · 跨块搬移亦无所遁形（两块之键界与合计同时变）；
--   · 块内两行互换其值，虽保块内合计，然键界与 rn 之对应亦须同变——须四项同时凑巧
--     方能瞒过，概率可忽略，且本件业务键唯一（已实证 n_keys = n_rows），互换即撞键。
--   ★ 此即「逐行对照」之可行等价物：不必导出原版全量，而定位精度为 10 行。
--
-- 【与 §D06 之别】D06 之八项系**全档一个数**，只能答「总量对不对」；
--   D07 出 69,641 个数，能答「哪一段对不对」。前者是体检，后者是拍片。
--
-- 【要害 · OVER 内之排序键，与分批版逐字同一】
--   两版之 rn 若非同一排序规则所生，逐行对照即无意义。故本节之键**复制自分批版**，
--   仅将别名前缀 y. 改为 s.，余一字未动。
-- ════════════════════════════════════════════════════════════════════════════════════════════

WITH src AS (
    WITH ta AS (            -- 公司测试线代理（214 条，跨五级）
      SELECT DISTINCT age001 AS aid                                                                     -- 取列：产出「aid」
      FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'                                             -- 取数来源：取自代理主档（五级代理线归属来源）
    ),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 I_ip_player.csv）
    rk AS (                  -- 需求 §3.2：同注单号取最新版本（三级排序去重）
      SELECT b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02,                                         -- 取列：起始取列子句，本行先列 b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02，涉 bet02（游戏类别）、dt（营业日）
             b.bet03, b.bet04, b.bet05, b.bet08, b.bet09,                                               -- 续行：接续上一取列子句，续列 b.bet03, b.bet04, b.bet05, b.bet08, b.bet09，涉 bet03（靴号）、bet04（局内序号）、bet05（会员号）
             b.bet11, b.bet13, b.bet14, b.bet16, b.bet17,                                               -- 续行：接续上一取列子句，续列 b.bet11, b.bet13, b.bet14, b.bet16, b.bet17，涉 bet11（汇率）、bet13（下注金额）、bet14（派彩金额）
             b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,                                               -- 续行：接续上一取列子句，续列 b.bet18, b.bet19, b.bet20, b.bet21, b.bet22，涉 bet18（一级代理线）、bet19（二级代理线）、bet20（三级代理线）
             b.bet38, b.bet39, b.category, b.eid, b.ip,                                                 -- 续行：接续上一取列子句，续列 b.bet38, b.bet39, b.category, b.eid, b.ip，涉 bet38（重對）、bet39（桌号）、eid（荷官工号）
             b.validbet,                                                                                -- 续行：接续上一取列子句，续列 b.validbet，涉 validbet（有效投注（洗码量））
             ROW_NUMBER() OVER (                                                                        -- 行号窗口表达式：以行号窗口取每组头部或去重，免出重复行
               PARTITION BY b.bet01                                                                     -- 窗口分区：按 b.bet01 分组开窗，组内各自编号或排名
               ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                           -- 排序：按 b.updatetime（降序）, b.sync_time（降序）, b.dt（降序）) AS rn 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
      FROM ods_mariadb_2b.ods_a168_bet02 b                                                              -- 取数来源：取自注单明细表（金额与行为口径的第一料源）
      WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'                            -- 过滤条件：限定 b.dt不少于 '2026-03-21'、b.dt小于 '2026-08-07'、b.bet02等于 '101'，涉 bet02（游戏类别）、dt（营业日）
    ),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 I_ip_player.csv）
    vd AS (                  -- 有效注单：非测试线、非重对、一般注单
      SELECT r.*                                                                                        -- 取列：整体承接上游结果集的全部字段，不再逐列列举
      FROM rk r                                                                                         -- 取数来源：取自本条自建的中间结果集 rk
      LEFT JOIN ta t1 ON t1.aid = r.bet18                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet18（一级代理线）
      LEFT JOIN ta t2 ON t2.aid = r.bet19                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet19（二级代理线）
      LEFT JOIN ta t3 ON t3.aid = r.bet20                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet20（三级代理线）
      LEFT JOIN ta t4 ON t4.aid = r.bet21                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet21（四级代理线）
      LEFT JOIN ta t5 ON t5.aid = r.bet22                                                               -- 左连接：取自本条自建的中间结果集 ta，连接键为 bet22（五级代理线）
      WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'                                -- 过滤条件：限定 r.rn等于 1、r.category等于 '1'、UPPER(TRIM(r.bet38))等于 'N'，涉 bet38（重對）
        AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0                                                -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)大于 0，涉 bet05（会员号）
        AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0                                         -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))大于 0，涉 bet11（汇率）
        AND NULLIF(TRIM(r.bet08),'') IS NOT NULL                                                        -- 并列条件：限定该值非空，涉 bet08（下注时间）
        AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL                                    -- 并列条件：限定该值为空——本包以左连接加空值判定替代 EXISTS，因 StarRocks 不支持 EXISTS 配多列 IN
    ),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 I_ip_player.csv）
    bs AS (                  -- 金额正名：本金/洗码量/游戏输赢/退水/净输赢（一律÷汇率）
      SELECT v.bet05 AS member_id, v.eid AS dealer_id, v.ip AS bet_ip,                                  -- 取列：起始取列子句，本行先取「bet_ip」，涉 bet05（会员号）、eid（荷官工号）、bet_ip（下注 IP）
             v.bet20 AS lv3, v.bet09 AS bet_side, v.dt AS bet_date,                                     -- 取值表达式：取用 bet09（玩法）、bet20（三级代理线）、dt（营业日），产出「bet_date」
             CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,                                    -- 取值表达式：取用 bet03（靴号）、bet04（局内序号）、bet39（桌号），产出「round_key」
             v.bet39 AS table_id,                                                                       -- 取值表达式：取用 bet39（桌号），产出「table_id」
             CAST(NULLIF(TRIM(v.bet08),'') AS DATETIME) AS t_bet,                                       -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「t_bet」
             CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
               / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS stake,                              -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「stake」
             CAST(NULLIF(TRIM(v.validbet),'') AS DECIMAL(20,4))                                         -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
               / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS valid_bet,                          -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「valid_bet」
             (CAST(NULLIF(TRIM(v.bet14),'') AS DECIMAL(20,4))                                           -- 续行：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
              - CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4)))                                        -- 加减计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
               / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS game_pnl,                           -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「game_pnl」
             CAST(NULLIF(TRIM(v.bet16),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
               / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS rebate,                             -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「rebate」
             CAST(NULLIF(TRIM(v.bet17),'') AS DECIMAL(20,4))                                            -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真
               / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS net_pnl                             -- 除法或乘法计算：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「net_pnl」
      FROM vd v                                                                                         -- 取数来源：取自本条自建的中间结果集 vd
    ),                                                                                                  -- 续行：收束上方的子查询或函数括号（交付件 I_ip_player.csv）
    pl AS (SELECT member_id, COUNT(*) AS n_orders_all,                                                  -- 取值表达式：计数，取用 member_id（会员号），产出「n_orders_all」
                  COUNT(DISTINCT round_key) AS n_rounds_all,                                            -- 计数表达式：统计去重个数，产出「n_rounds_all」
                  SUM(net_pnl) AS net_pnl_all, SUM(game_pnl) AS game_pnl_all                            -- 汇总表达式：取用 net_pnl（会员净输赢）、game_pnl（游戏净输赢），产出「game_pnl_all」
           FROM bs GROUP BY member_id)                                                                  -- 取数来源：取自本条自建的中间结果集 bs
    SELECT b.bet_ip, b.member_id, MAX(b.lv3) AS lv3,                                                    -- 取列：起始取列子句，本行先取「lv3」，涉 bet_ip（下注 IP）、member_id（会员号）、lv3（三级代理线）
      COUNT(*) AS n_orders_ip, COUNT(DISTINCT b.round_key) AS n_rounds_ip,                              -- 计数表达式：统计去重个数，产出「n_rounds_ip」
      SUM(b.stake) AS stake_ip, SUM(b.game_pnl) AS game_pnl_ip,                                         -- 汇总表达式：取用 stake（下注额（经汇率归一化））、game_pnl（游戏净输赢），产出「game_pnl_ip」
      SUM(b.rebate) AS rebate_ip, SUM(b.net_pnl) AS net_pnl_ip,                                         -- 汇总表达式：取用 net_pnl（会员净输赢）、rebate（退水），产出「net_pnl_ip」
      MAX(pl.n_orders_all) AS n_orders_all, MAX(pl.n_rounds_all) AS n_rounds_all,                       -- 取最大值表达式：产出「n_rounds_all」
      MAX(pl.net_pnl_all) AS net_pnl_all, MAX(pl.game_pnl_all) AS game_pnl_all,                         -- 取最大值表达式：产出「game_pnl_all」
      COUNT(*)*1.0/NULLIF(MAX(pl.n_orders_all),0) AS ip_order_share                                     -- 计数表达式：取最大值，产出「ip_order_share」
    FROM bs b JOIN pl ON pl.member_id=b.member_id                                                       -- 取数来源：取自本条自建的中间结果集 bs，连接键为 member_id（会员号）
    WHERE NULLIF(TRIM(b.bet_ip),'') IS NOT NULL                                                         -- 过滤条件：限定该值非空，涉 bet_ip（下注 IP）
    GROUP BY b.bet_ip, b.member_id                                                                      -- 分组：按 b.bet_ip, b.member_id 汇总
    HAVING COUNT(*) >= 30                                                                               -- 分组后过滤：限定行数不少于 30
),
num AS (
  SELECT s.*,
         ROW_NUMBER() OVER (ORDER BY s.`n_orders_ip` DESC, s.`bet_ip`, s.`member_id`, s.`lv3`, s.`n_rounds_ip`, s.`stake_ip`, s.`game_pnl_ip`, s.`rebate_ip`, s.`net_pnl_ip`, s.`n_orders_all`, s.`n_rounds_all`, s.`net_pnl_all`, s.`game_pnl_all`, s.`ip_order_share`) AS rn
  FROM src s
)
SELECT
  CAST(FLOOR((rn - 1) / 10) AS BIGINT)                            AS blk,
  COUNT(*)                                                        AS n,
  MIN(rn)                                                         AS rn_min,
  MAX(rn)                                                         AS rn_max,
  MIN(CONCAT_WS('|', bet_ip, member_id))                          AS key_min,
  MAX(CONCAT_WS('|', bet_ip, member_id))                          AS key_max,
  SUM(n_orders_ip)                                                AS s_orders,
  SUM(n_rounds_ip)                                                AS s_rounds,
  ROUND(SUM(ROUND(stake_ip,   4)), 4)                             AS s_stake,
  ROUND(SUM(ROUND(net_pnl_ip, 4)), 4)                             AS s_netpnl
FROM num
GROUP BY CAST(FLOOR((rn - 1) / 10) AS BIGINT)
ORDER BY blk;

-- ════════════════════════════════════════════════════════════════════════════════════════════
-- 【跑法】本条一次导全，落档为 数据库/_audit/I_ip_player_blk10_原版侧.csv（69,641 行 × 10 列）。
--   然后跑 D07 之 R 侧脚本，与七批合并档所算之同名分块表逐块比对。
--   ★ 分批侧之分块表我已自先生所呈之合并档算出，其滚动校验和见 R 侧脚本顶部；
--     先生导出原版侧后，若两边滚动校验和相同，可先安心；再逐块比对以求确证。
-- ════════════════════════════════════════════════════════════════════════════════════════════
