-- ══════════════════════════════════════════════════════════════════════════════════════════
-- ★ I_ip_player.csv · 斧正后完整取数代码（行号切片 · 七批 · 禁遗漏禁重叠）★
-- ══════════════════════════════════════════════════════════════════════════════════════════
-- 立于 2026-08-24 · 源：a168_取数与核验_SQL总包_v11.1.0 行 1589~1654（内层查询逐字复制）
-- 身份：派生作业件。内层 SQL 一字未改，仅剥去原末尾 ORDER BY 与分号，外加行号切片壳。
--
-- 【事故留证 · 本件为何须重取】
--   前次以 LIMIT/OFFSET 分批所得：取回 696,403 行，去重后 696,275 行。
--   实测 T_true = 696,403（2026-08-24，6.528 秒）。三数对齐即知：
--     重复 128 行 ＝ 遗漏 128 行  —— 取回总数恰等于 T_true，而不重复者少 128，
--     则那 128 个位置被重复占用，另有 128 行一次也没被取到。
--   病根：原 ORDER BY 仅 n_orders_ip DESC，并列极多；七批各重排一次，
--         六个批边界处各错位约 21 行。错位率 0.0184%。
--   ★ 去重挽回不了遗漏。本件须整件重取，旧档作废。
--
-- 【本代码何以能禁绝遗漏与重叠】
--   ① 全序：OVER 内首键接回原意图 n_orders_ip DESC，其后补 bet_ip、member_id
--      —— 即本查询之 GROUP BY 键，聚合后唯一。并列由此打破，排序遂成定数。
--   ② 自证：rn 随行落档。每批 rn 之区间可当场验明首尾相接，
--      不必信任引擎，亦不必信任本代码——数自己会说话。
--
-- 【批次】T_true = 696,403 ÷ 100,000 → 共 7 批（末批 96,403 行）。
-- 【顺序】① 复验 T_true → ② 逐批取数（第 1~7 批）→ ③ 每批自证 → ④ 全批合验。
-- ══════════════════════════════════════════════════════════════════════════════════════════


-- ──────────────────────────────────────────────────────────────────────────────────────────
-- ① 复验 T_true（预期 696,403。若不符，说明源数据已变动，其下批次划分须重定）
-- ──────────────────────────────────────────────────────────────────────────────────────────
SELECT COUNT(*) AS T_true FROM (
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
) x;

-- ──────────────────────────────────────────────────────────────────────────────────────────
-- ② 第 1 批 / 共 7    rn ∈ (0 , 100,000]    预期返回 100,000 行
-- ──────────────────────────────────────────────────────────────────────────────────────────
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`n_orders_ip` DESC, y.`bet_ip`, y.`member_id`, y.`lv3`, y.`n_rounds_ip`, y.`stake_ip`, y.`game_pnl_ip`, y.`rebate_ip`, y.`net_pnl_ip`, y.`n_orders_all`, y.`n_rounds_all`, y.`net_pnl_all`, y.`game_pnl_all`, y.`ip_order_share`) AS rn
  FROM (
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
  ) y
) z
WHERE z.rn > 0 AND z.rn <= 100000
ORDER BY z.rn;

-- ──────────────────────────────────────────────────────────────────────────────────────────
-- ② 第 2 批 / 共 7    rn ∈ (100,000 , 200,000]    预期返回 100,000 行
-- ──────────────────────────────────────────────────────────────────────────────────────────
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`n_orders_ip` DESC, y.`bet_ip`, y.`member_id`, y.`lv3`, y.`n_rounds_ip`, y.`stake_ip`, y.`game_pnl_ip`, y.`rebate_ip`, y.`net_pnl_ip`, y.`n_orders_all`, y.`n_rounds_all`, y.`net_pnl_all`, y.`game_pnl_all`, y.`ip_order_share`) AS rn
  FROM (
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
  ) y
) z
WHERE z.rn > 100000 AND z.rn <= 200000
ORDER BY z.rn;

-- ──────────────────────────────────────────────────────────────────────────────────────────
-- ② 第 3 批 / 共 7    rn ∈ (200,000 , 300,000]    预期返回 100,000 行
-- ──────────────────────────────────────────────────────────────────────────────────────────
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`n_orders_ip` DESC, y.`bet_ip`, y.`member_id`, y.`lv3`, y.`n_rounds_ip`, y.`stake_ip`, y.`game_pnl_ip`, y.`rebate_ip`, y.`net_pnl_ip`, y.`n_orders_all`, y.`n_rounds_all`, y.`net_pnl_all`, y.`game_pnl_all`, y.`ip_order_share`) AS rn
  FROM (
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
  ) y
) z
WHERE z.rn > 200000 AND z.rn <= 300000
ORDER BY z.rn;

-- ──────────────────────────────────────────────────────────────────────────────────────────
-- ② 第 4 批 / 共 7    rn ∈ (300,000 , 400,000]    预期返回 100,000 行
-- ──────────────────────────────────────────────────────────────────────────────────────────
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`n_orders_ip` DESC, y.`bet_ip`, y.`member_id`, y.`lv3`, y.`n_rounds_ip`, y.`stake_ip`, y.`game_pnl_ip`, y.`rebate_ip`, y.`net_pnl_ip`, y.`n_orders_all`, y.`n_rounds_all`, y.`net_pnl_all`, y.`game_pnl_all`, y.`ip_order_share`) AS rn
  FROM (
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
  ) y
) z
WHERE z.rn > 300000 AND z.rn <= 400000
ORDER BY z.rn;

-- ──────────────────────────────────────────────────────────────────────────────────────────
-- ② 第 5 批 / 共 7    rn ∈ (400,000 , 500,000]    预期返回 100,000 行
-- ──────────────────────────────────────────────────────────────────────────────────────────
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`n_orders_ip` DESC, y.`bet_ip`, y.`member_id`, y.`lv3`, y.`n_rounds_ip`, y.`stake_ip`, y.`game_pnl_ip`, y.`rebate_ip`, y.`net_pnl_ip`, y.`n_orders_all`, y.`n_rounds_all`, y.`net_pnl_all`, y.`game_pnl_all`, y.`ip_order_share`) AS rn
  FROM (
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
  ) y
) z
WHERE z.rn > 400000 AND z.rn <= 500000
ORDER BY z.rn;

-- ──────────────────────────────────────────────────────────────────────────────────────────
-- ② 第 6 批 / 共 7    rn ∈ (500,000 , 600,000]    预期返回 100,000 行
-- ──────────────────────────────────────────────────────────────────────────────────────────
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`n_orders_ip` DESC, y.`bet_ip`, y.`member_id`, y.`lv3`, y.`n_rounds_ip`, y.`stake_ip`, y.`game_pnl_ip`, y.`rebate_ip`, y.`net_pnl_ip`, y.`n_orders_all`, y.`n_rounds_all`, y.`net_pnl_all`, y.`game_pnl_all`, y.`ip_order_share`) AS rn
  FROM (
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
  ) y
) z
WHERE z.rn > 500000 AND z.rn <= 600000
ORDER BY z.rn;

-- ──────────────────────────────────────────────────────────────────────────────────────────
-- ② 第 7 批 / 共 7    rn ∈ (600,000 , 700,000]    预期返回 96,403 行
-- ──────────────────────────────────────────────────────────────────────────────────────────
SELECT *
FROM (
  SELECT y.*,
         ROW_NUMBER() OVER (ORDER BY y.`n_orders_ip` DESC, y.`bet_ip`, y.`member_id`, y.`lv3`, y.`n_rounds_ip`, y.`stake_ip`, y.`game_pnl_ip`, y.`rebate_ip`, y.`net_pnl_ip`, y.`n_orders_all`, y.`n_rounds_all`, y.`net_pnl_all`, y.`game_pnl_all`, y.`ip_order_share`) AS rn
  FROM (
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
  ) y
) z
WHERE z.rn > 600000 AND z.rn <= 700000
ORDER BY z.rn;

-- ══════════════════════════════════════════════════════════════════════════════════════════
-- ③ 每批取回后之自证四数（任一不符即刻停手回报，禁止放行）
-- ══════════════════════════════════════════════════════════════════════════════════════════
--   于所下载之第 k 批档上跑（R 侧或 SQL 侧皆可）：
--     n_rows      = COUNT(*)
--     n_rn_uniq   = COUNT(DISTINCT rn)
--     rn_min      = MIN(rn)
--     rn_max      = MAX(rn)
--   须同时满足：
--     n_rows = n_rn_uniq                    （批内无重复）
--     rn_min = (k-1)*100000 + 1             （与上批严丝合缝）
--     rn_max = rn_min + n_rows - 1          （批内无缺口）
--
--   逐批预期值（本件）：
--     第 1 批：rn_min =      1 ／ rn_max =  100,000 ／ n_rows = 100,000
--     第 2 批：rn_min = 100,001 ／ rn_max =  200,000 ／ n_rows = 100,000
--     第 3 批：rn_min = 200,001 ／ rn_max =  300,000 ／ n_rows = 100,000
--     第 4 批：rn_min = 300,001 ／ rn_max =  400,000 ／ n_rows = 100,000
--     第 5 批：rn_min = 400,001 ／ rn_max =  500,000 ／ n_rows = 100,000
--     第 6 批：rn_min = 500,001 ／ rn_max =  600,000 ／ n_rows = 100,000
--     第 7 批：rn_min = 600,001 ／ rn_max =  696,403 ／ n_rows =  96,403
--
-- ══════════════════════════════════════════════════════════════════════════════════════════
-- ④ 全批合验（七档合并之后跑，此为放行之唯一凭据）
-- ══════════════════════════════════════════════════════════════════════════════════════════
--   合并七档为一表，须同时满足：
--     COUNT(*)            = 696,403      （总数等于 T_true）
--     COUNT(DISTINCT rn)  = 696,403      （无重号）
--     MIN(rn) = 1  且  MAX(rn) = 696,403 （无缺号 —— 与上一条合看即证并集恰为 1..696403）
--     COUNT(DISTINCT CONCAT_WS('|', bet_ip, member_id)) = 696,403
--                                        （粒度键亦唯一，与 GROUP BY 语义相符）
--   四数全中，方可放行；任一不符，整件重取。
--
-- ══════════════════════════════════════════════════════════════════════════════════════════
-- ⑤ 旧档处置
-- ══════════════════════════════════════════════════════════════════════════════════════════
--   前次 OFFSET 所得之 696,403 行档（去重后 696,275 行）**作废**，
--   加 _superseded 后缀归档，禁删——留作 D01-13 之实物证据。
--
--   建议顺手做一件事：以新档反连旧档（去重后），揪出旧档所缺之 128 行，
--   看其 n_orders_ip 之分布。可证伪之预测：因原序为 DESC，
--   那 128 行应集中于六个批边界所在之并列带，且**偏向低注单数之尾部**——
--   若果真如此，则此次遗漏非随机缺失，而是系统性偏在尾部。
--   验毕请回报其分布，此事值得单独登记。
-- ══════════════════════════════════════════════════════════════════════════════════════════
