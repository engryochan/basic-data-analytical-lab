-- =====================================================================
-- R03b_source_from_v10.sql · §R03b 查询原文（自总包 v10 逐字摘出）
-- ---------------------------------------------------------------------
-- 身份 : 【候选件】★ 非事实记录、非交付件、不可径改名
-- 摘出日期 : 2026-08-22
-- 来源 : a168_取数与核验_SQL总包_v10.sql
--        9,475 行 | 1,195,130 字节 | CRLF | MD5(file) 62985e9b2932bd7ab70fba7ee9c01cb8
-- 摘出范围 : 第 5278 ~ 5377 行（§R03b 之 SQL 正文，自 WITH 起至 ORDER BY 之分号止）
--            逐字未改：未加 LIMIT、未改窗口、未加分页谓词、未动排序、未删行尾注
-- ---------------------------------------------------------------------
-- 【⚠ 使用前必读 · 本档不得径改名为 R03b_source.sql】
--
--   R03b_cc_verifier.R 之 Gate-0 所要证明者，是
--     「档里记的 SQL」与「您当日实际在 Superset 提交的 SQL」是同一份。
--   本档只是【总包原文】，不是【您实际所跑者】之证据。
--
--   ✅ 唯一合法之改名条件：
--      您确认当日提交者与本档逐字节相同——未加 LIMIT、未改窗口、未分批、
--      未改排序、未删注释。确认后方可另存为 函数/R03b_source.sql。
--
--   ⛔ 若有任何一处不同（哪怕只加了 LIMIT 100000 试跑），须存【实际所跑者】。
--      以本档冒充，即为伪造留痕——哈希会对上，但对上的是一个从未跑过的查询，
--      Gate-0 遂由『证明同一份』沦为『证明抄了同一份』。
--
--   ★ 本段第 5265~5277 行（未摘入）明载：本件十万行上限下不可直接导出，
--     须先定粒度或以三键游标分批。若当日确曾分批，则实际所跑者必含分页谓词，
--     与本档必不相同——而那正是 R03b 截断悬案（预期 18,139,550 行、
--     实得 6,143,388 行、STOP CAUSE UNKNOWN）之关键线索，不可被本档抹平。
-- =====================================================================

WITH ranked AS (                                                                                    -- 公共表表达式：开启中间结果集 ranked，其后各行为其定义体（§R03b）
  SELECT b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02,                                         -- 取列：起始取列子句，本行先列 b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02，涉 bet02（游戏类别）、dt（营业日）
         b.bet03, b.bet04, b.bet05, b.bet09, b.bet11,                                               -- 续行：接续上一取列子句，续列 b.bet03, b.bet04, b.bet05, b.bet09, b.bet11，涉 bet03（靴号）、bet04（局内序号）、bet05（会员号）
         b.bet13, b.bet14, b.bet17, b.bet38, b.bet39,                                               -- 续行：接续上一取列子句，续列 b.bet13, b.bet14, b.bet17, b.bet38, b.bet39，涉 bet13（下注金额）、bet14（派彩金额）、bet17（会员净输赢）
         b.category, b.eid,                                                                         -- 续行：接续上一取列子句，续列 b.category, b.eid，涉 eid（荷官工号）
         ROW_NUMBER() OVER (                                                                        -- 行号窗口表达式：以行号窗口取每组头部或去重，免出重复行
           PARTITION BY b.bet01                                                                     -- 窗口分区：按 b.bet01 分组开窗，组内各自编号或排名
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                           -- 排序：按 b.updatetime（降序）, b.sync_time（降序）, b.dt（降序）) AS rn 排列；导出必带排序，否则分页无稳定序（曾致 36.49% 重复行）
  FROM ods_mariadb_2b.ods_a168_bet02 b                                                              -- 取数来源：取自注单明细表（金额与行为口径的第一料源）
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'                                                -- 过滤条件：限定 b.dt不少于 '2026-03-21'、b.dt小于 '2026-08-07'，涉 dt（营业日）
    AND b.bet02 = '101' AND b.category = '1'                                                        -- 并列条件：限定 b.bet02等于 '101'、b.category等于 '1'，涉 bet02（游戏类别）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§R03b）
base AS (                                                                                           -- 公共表表达式：开启中间结果集 base，其后各行为其定义体（§R03b）
  SELECT r.bet05 AS member_id, r.eid AS dealer_id, r.dt AS bet_date,                                -- 取列：起始取列子句，本行先取「bet_date」，涉 bet05（会员号）、eid（荷官工号）、dt（营业日）
         CASE WHEN TRIM(r.eid) IN ('-1','0') THEN 1 ELSE 0 END AS is_sentinel_dealer,               -- 取值表达式：哨兵标记——★ 由删除改为标注（事实层不删，分析层才筛）
         r.bet09 AS bet_side,                                                                       -- 取值表达式：取用 bet09（玩法），产出「bet_side」
         CONCAT_WS('|', r.bet03, r.bet04, r.bet39) AS round_key,                                    -- 取值表达式：取用 bet03（靴号）、bet04（局内序号）、bet39（桌号），产出「round_key」
         CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) AS fx,                                     -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「fx」
         CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)) AS stake_raw,                              -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「stake_raw」
         CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4)) AS payout_raw,                             -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「payout_raw」
         CAST(NULLIF(TRIM(r.bet17),'') AS DECIMAL(20,4)) AS net_raw                                 -- 取值表达式：先去空白、空串归 NULL，再显式转型——本库字段多为 varchar，不转型即比较失真，产出「net_raw」
  FROM ranked r                                                                                     -- 取数来源：取自本条自建的中间结果集 ranked
  WHERE r.rn = 1 AND UPPER(TRIM(r.bet38)) = 'N'                                                     -- 过滤条件：限定 r.rn等于 1、UPPER(TRIM(r.bet38))等于 'N'，涉 bet38（测试标识）
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0                                                -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT)大于 0，涉 bet05（会员号）
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0                                         -- 并列条件：限定 CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8))大于 0，涉 bet11（汇率）
    AND NULLIF(TRIM(r.eid),'') IS NOT NULL                                                          -- 并列条件：限定该值非空，涉 eid（荷官工号）
    AND UPPER(TRIM(r.bet09)) NOT LIKE 'TIP\_1\_%'                                                   -- 并列条件：限定不匹配所给模式，涉 bet09（玩法）
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§R03b）
ord AS (                                                                                            -- 公共表表达式：开启中间结果集 ord，其后各行为其定义体（§R03b）
  SELECT member_id, dealer_id, is_sentinel_dealer, bet_date, bet_side, round_key,                   -- 取列：起始取列子句，透传哨兵标记，涉 bet_date（营业日）、round_key（局键）
         stake_raw / fx                AS stake,                                                    -- 取值表达式：取用 stake（下注额（经汇率归一化）），产出「stake」
         (payout_raw - stake_raw) / fx AS game_pnl,                                                 -- 续行：取用 game_pnl（游戏净输赢），产出「game_pnl」
         net_raw / fx                  AS net_pnl                                                   -- 取值表达式：取用 net_pnl（会员净输赢），产出「net_pnl」
  FROM base                                                                                         -- 取数来源：取自本条自建的中间结果集 base
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§R03b）
side_base AS (                                                                                      -- 公共表表达式：开启中间结果集 side_base，其后各行为其定义体（§R03b）
  SELECT bet_side,                                                                                  -- 取列：起始取列子句，本行先列 bet_side
         SUM(CASE WHEN game_pnl > 0 THEN 1 ELSE 0 END) * 1.0                                        -- 取值表达式：比率之分子，乘 1.0 以避整数除法截断，涉 game_pnl（游戏净输赢）
           / NULLIF(SUM(CASE WHEN game_pnl <> 0 THEN 1 ELSE 0 END), 0) AS p_base                    -- 除法或乘法计算：汇总，取用 game_pnl（游戏净输赢），产出「p_base」
  FROM ord WHERE is_sentinel_dealer = 0                                                             -- 取数来源：取自本条自建的中间结果集 ord——★ 基准只由**真实牌桌**估计
  GROUP BY bet_side                                                                                 -- 分组：按投注产品汇总
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§R03b）
ordb AS (             -- ★ 2026-08-11 增：注单层挂上各自产品的基准，供下方按注额加权
  SELECT o.member_id, o.dealer_id, o.is_sentinel_dealer, o.bet_date, o.round_key, o.bet_side,       -- 取列：起始取列子句，透传五键与哨兵标记
         o.stake, o.game_pnl, o.net_pnl, s.p_base AS p_side                                         -- 续行：并取三项金额与该注自身产品的基准胜率，产出「p_side」
  FROM      ord o                                                                                   -- 取数来源：取自本条自建的中间结果集 ord
  LEFT JOIN side_base s ON s.bet_side = o.bet_side                                                  -- 左连接：取自本条自建的中间结果集 side_base，基准未定义者留空——不以 0.5 顶替
),                                                                                                  -- 续行：收束上方的子查询或函数括号（§R03b）
pr AS (   -- 局级去重：同一物理局折成一局，避免 Z-score 被 sqrt(k) 放大
  SELECT member_id, dealer_id, is_sentinel_dealer, bet_date, round_key,                             -- 取列：起始取列子句，透传哨兵标记
         SUM(stake) AS stake, SUM(game_pnl) AS game_pnl, SUM(net_pnl) AS net_pnl,                   -- 汇总表达式：取用 stake（下注额（经汇率归一化））、net_pnl（会员净输赢）、game_pnl（游戏净输赢），产出「net_pnl」
         COUNT(*) AS n_orders_in_round,                                                             -- 计数表达式：产出「n_orders_in_round」
         SUM(stake * p_side)                                                                        -- 汇总表达式：注额加权基准起算——★ 斧正，旧法 MAX(bet_side) 取字母序最大而非主注
           / NULLIF(SUM(CASE WHEN p_side IS NOT NULL THEN stake ELSE 0 END), 0)                     -- 除法或乘法计算：除以有基准之注的注额合计
                       AS p_base_round_w,                                                             -- 续行：产出「p_base_round_w」——该局的**注额加权**基准；全注皆无基准则留空
         AVG(p_side)   AS p_base_round_unw,                                                         -- 汇总表达式：同局各注基准的**等权**均值——★ 2026-08-11 增，供两种 estimand 对照
         MAX(bet_side) AS main_side                                                                 -- 取最大值表达式：字母序最大注项，**仅备查、不参与计算**
  FROM ordb GROUP BY member_id, dealer_id, is_sentinel_dealer, bet_date, round_key                  -- 取数来源：取自本条自建的中间结果集 ordb（已挂基准）
)                                                                                                   -- 续行：收束上方的子查询或函数括号（§R03b）
SELECT p.bet_date, p.member_id AS uid, p.dealer_id, p.is_sentinel_dealer,                           -- 取列：起始取列子句，本行先取「uid」与哨兵标记
       SUM(p.stake)                                        AS stake_amount,                         -- 汇总表达式：取用 stake（下注额（经汇率归一化）），产出「stake_amount」
       SUM(p.game_pnl)                                     AS profit_amount,                        -- 汇总表达式：取用 game_pnl（游戏净输赢），产出「profit_amount」
       SUM(p.net_pnl)                                      AS net_pnl,                              -- 汇总表达式：取用 net_pnl（会员净输赢），产出「net_pnl」
       SUM(CASE WHEN p.game_pnl > 0 THEN 1 ELSE 0 END) * 1.0                                        -- 取值表达式：比率之分子，乘 1.0 以避整数除法截断，涉 game_pnl（游戏净输赢）
         / NULLIF(SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END), 0) AS win_rate,                 -- 除法或乘法计算：汇总，取用 game_pnl（游戏净输赢），产出「win_rate」
       SUM(p.n_orders_in_round)                            AS n_related_orders,                     -- 汇总表达式：产出「n_related_orders」
       COUNT(*)                                            AS n_rounds_eff,                         -- 计数表达式：取用 n_rounds_eff（有效局数），产出「n_rounds_eff」
       AVG(p.p_base_round_w)                                 AS p_base_mix_w,                           -- 汇总表达式：对各局的**注额加权**基准取均值——判定所用者
       AVG(p.p_base_round_unw)                             AS p_base_mix_unw,                       -- 汇总表达式：**等权**口径之对照量——★ 2026-08-11 与 §R03 对齐，二者背离即示资金集中于某产品
       (SUM(CASE WHEN p.game_pnl > 0 THEN 1 ELSE 0 END)                                             -- 续行：汇总，取用 game_pnl（游戏净输赢）
        - SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END) * AVG(p.p_base_round_w))           -- 加减计算：汇总后取负号——会员净输赢取负即平台毛利（GGR）
         / NULLIF(SQRT(SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END)                             -- 除法或乘法计算：汇总，取用 game_pnl（游戏净输赢）
                       * AVG(p.p_base_round_w)                                                -- 除法或乘法计算：求均值
                       * (1 - AVG(p.p_base_round_w))), 0)        AS z_score_w,                      -- 除法或乘法计算：产出「z_score_w」——**加权候选臂**
       (SUM(CASE WHEN p.game_pnl > 0 THEN 1 ELSE 0 END)                                             -- 取值表达式：★ **对照臂**之分子——同式改用等权基准（Dixon & Coles 1996：先立无权重基线）
        - SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END) * AVG(p.p_base_round_unw))               -- 续行：期望胜局按等权基准算
         / NULLIF(SQRT(SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END)                             -- 除法或乘法计算：除以伯努利标准差
                       * AVG(p.p_base_round_unw)                                                    -- 续行：等权基准
                       * (1 - AVG(p.p_base_round_unw))), 0)    AS z_score_unw,                      -- 续行：产出「z_score_unw」——加权之优势须由本臂对照证成
       (SUM(CASE WHEN p.game_pnl > 0 THEN 1 ELSE 0 END)                                             -- 取值表达式：兼容别名之分子——与 z_score_w 逐字同式
        - SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END) * AVG(p.p_base_round_w))                 -- 续行：期望胜局按加权基准算
         / NULLIF(SQRT(SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END)                             -- 除法或乘法计算：除以伯努利标准差
                       * AVG(p.p_base_round_w)                                                      -- 续行：加权基准
                       * (1 - AVG(p.p_base_round_w))), 0)        AS z_score,                        -- 续行：产出「z_score」——★ **兼容别名，恒等于 z_score_w**；既有报告与数据契约沿用此名
       AVG(p.p_base_round_w) - AVG(p.p_base_round_unw)          AS delta_p,                         -- 加减计算：比较层——两臂基准之差，产出「delta_p」
       CASE WHEN p.is_sentinel_dealer = 1 THEN 'SENTINEL_DEALER'                                    -- 取值表达式：统计资格判定起算——事实层不删，此处只标注资格
            WHEN AVG(p.p_base_round_w) IS NULL THEN 'NO_BASE_RATE'                                    -- 续行：基准未定义
            WHEN SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END) = 0 THEN 'NO_DECISIVE_ROUND'      -- 续行：全为退还局，无胜负可判
            ELSE 'ELIGIBLE' END                                 AS eligibility_status,               -- 续行：产出「eligibility_status」——日粒度不设局数下限，下限由分析层施加
       'R03b_20260811_FULL_v1'                              AS comparison_id,                       -- 取值表达式：比较批次号——与 §R03 同规格，两臂须同批次方可比
       'L1_ELIGIBILITY'                           AS filter_stage,                                  -- 取值表达式：过滤所处之层——★ L0 事实层不删行，此处只标注其在 L1 资格层的去留
       'v2026-08-11'                              AS filter_rule_version,                            -- 取值表达式：资格规则版本号——改规则须改版本号并记入变更日志，免「同名不同义」
       '2026-03-21..2026-08-06'                             AS cmp_time_window,                     -- 取值表达式：时间窗，产出「cmp_time_window」
       'baccarat_bet02_101_all_pairs_incl_sentinel'         AS cmp_population,                      -- 取值表达式：总体定义（含哨兵之全量对）
       'round_win = game_pnl > 0 (decisive only)'           AS cmp_label,                           -- 取值表达式：标签定义
       'COMPATIBILITY_ONLY_NOT_PRODUCTION'                  AS z_score_alias_status                 -- 取值表达式：★ 兼容别名状态——禁止作生产输入
FROM pr p                                                                                           -- 取数来源：取自本条自建的中间结果集 pr
-- （已废）旧版在此按 main_side 连 side_base 取基准，2026-08-11 改注单层注额加权                                          -- 注：连接已移至 ordb，本处不再取基准
GROUP BY p.bet_date, p.member_id, p.dealer_id, p.is_sentinel_dealer                                 -- 分组：按营业日×会员×荷官×哨兵标记汇总
ORDER BY p.bet_date, p.member_id, p.dealer_id;                                                      -- 排序：★ 2026-08-11 改——按**唯一键**（日×会员×荷官）升序；分页铁律①：排序键须唯一
