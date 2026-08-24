-- ══════════════════════════════════════════════════════════════════════════════════════════
-- ★ D 层 · 结果等价对账套件 · I_ip_player.csv ★
-- ══════════════════════════════════════════════════════════════════════════════════════════
-- 立于 2026-08-24 · 应 REDTEAM 裁定：静态 PASS ≠ 数据实测 PASS。
-- 用途：把 RESULT_EQUIVALENCE 由 PENDING 提为 TESTED_PASS（或据实判 FAIL）。
--
-- 【设计要旨 · 何以不必先把原版全量导出】
--   D 层若照字面做「original_result ↕ UNION ALL(batch_1..7) 双向差集」，
--   须先把原版 696,403 行整件导出——而这恰是分批所要回避之事，且旧档已因
--   OFFSET 事故作废，无可用之原版档。故改以**库内指纹**为原版之代表：
--     原版侧：一条查询、单遍扫描、不导出，算出行数／键数／列级合计／顺序无关之行指纹；
--     分批侧：七档合并后于 R 侧算同一组指纹；
--     两组指纹逐项比对。指纹全同 ⇒ 行之多重集合相同 ⇒ 双向差集必为空。
--   ★ 此法与「双向反连」等价而更省：反连须两侧同时在手，指纹只须一侧在库、一侧在 R。
--
-- 【指纹之构造与其限】
--   行文本以单元分隔符 U+001F 连接十四列，NULL 渲作 \N（与真值 '\N' 之混淆概率极低，
--   然非零，故列为已知限）。浮点列先 ROUND 至定精度再转字串——否则求和之结果依赖加序，
--   两侧加序不同即生尾数差，会误报为 FAIL。
--   行指纹以 SUM(murmur_hash3_32(行文本)) 聚合：加法可交换，故**与行序无关**。
--   ⚠ 哈希碰撞概率非零；故指纹不单独作证，须与行数、键数、列级合计**四项同时**吻合。
-- ══════════════════════════════════════════════════════════════════════════════════════════


-- ──────────────────────────────────────────────────────────────────────────────────────────
-- ① 原版侧指纹（库内一遍算出，不导出任何行）
-- ──────────────────────────────────────────────────────────────────────────────────────────
SELECT
  COUNT(*)                                                        AS n_rows,
  COUNT(DISTINCT CONCAT_WS('|', bet_ip, member_id))               AS n_keys,
  SUM(n_orders_ip)                                                AS sum_n_orders_ip,
  SUM(n_rounds_ip)                                                AS sum_n_rounds_ip,
  ROUND(SUM(ROUND(stake_ip,    4)), 4)                            AS sum_stake_ip,
  ROUND(SUM(ROUND(game_pnl_ip, 4)), 4)                            AS sum_game_pnl_ip,
  ROUND(SUM(ROUND(rebate_ip,   4)), 4)                            AS sum_rebate_ip,
  ROUND(SUM(ROUND(net_pnl_ip,  4)), 4)                            AS sum_net_pnl_ip,
  SUM(murmur_hash3_32(
        CONCAT_WS('\u001f',
           COALESCE(CAST(bet_ip AS STRING),'\\N'),
           COALESCE(CAST(member_id AS STRING),'\\N'),
           COALESCE(CAST(lv3 AS STRING),'\\N'),
           COALESCE(CAST(n_orders_ip AS STRING),'\\N'),
           COALESCE(CAST(n_rounds_ip AS STRING),'\\N'),
           CAST(ROUND(stake_ip, 4) AS STRING),
           CAST(ROUND(game_pnl_ip, 4) AS STRING),
           CAST(ROUND(rebate_ip, 4) AS STRING),
           CAST(ROUND(net_pnl_ip, 4) AS STRING),
           COALESCE(CAST(n_orders_all AS STRING),'\\N'),
           COALESCE(CAST(n_rounds_all AS STRING),'\\N'),
           CAST(ROUND(net_pnl_all, 4) AS STRING),
           CAST(ROUND(game_pnl_all, 4) AS STRING),
           CAST(ROUND(ip_order_share, 8) AS STRING)
         )
      ))                                                          AS fp_sum,
  MIN(CONCAT_WS('|', bet_ip, member_id))                          AS key_min,
  MAX(CONCAT_WS('|', bet_ip, member_id))                          AS key_max
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
) x;

-- ⚠ 若 murmur_hash3_32 于本库不存在，改用下式（择一即可，两侧须用同一式）：
--     SUM(CRC32(<行文本>))                       -- 备用式一
--     SUM(CAST(CONV(SUBSTR(MD5(<行文本>),1,8),16,10) AS BIGINT))   -- 备用式二
--   ★ 择定何式，须记入本件之核验回执；两侧不同式即无从比对。


-- ──────────────────────────────────────────────────────────────────────────────────────────
-- ①b 哈希校准闸（★ 新增 · 2026-08-24 · 校验器先自校）
-- ──────────────────────────────────────────────────────────────────────────────────────────
--   缘由：① 段实测 fp_sum = -142,789,586,420 为**负数**，均值约 -205,038 ≈ 0，
--   足证 murmur_hash3_32 于本库返回**有符号 32 位整数**（-2^31 ~ 2^31-1）；
--   而 R 侧 strtoi(hex,16) 得**无符号**值（0 ~ 2^32-1）。两侧不换算即比对，必误报 FAIL。
--   更根本者：StarRocks 之 murmur3 与 R digest 之 murmur32 是否**同一算法、同一种子**，
--   全属推定。故不得直接比对总和——须先令两侧对同一批已知字串各出其值，逐一对齐。
--   ★ 本闸不过，① 之 fp_sum 一律不得用于 D 级裁定（其余八项不受影响，仍可用）。
SELECT s AS probe,
       murmur_hash3_32(s)                                   AS h_signed,
       CAST(murmur_hash3_32(s) AS BIGINT) & 4294967295      AS h_unsigned
FROM ( SELECT '' AS s
       UNION ALL SELECT 'a'
       UNION ALL SELECT 'abc'
       UNION ALL SELECT '0'
       UNION ALL SELECT 'Hello, world!'
       UNION ALL SELECT '1.0.138.117\u001f148756829'
     ) p
ORDER BY probe;
--   ★ 把 h_signed 六个读数抄入 R 脚本之 HASH_PROBE，R 侧会先自验其实现是否一致；
--     一致方续；不一致则 fp_sum 一项自动降级为 SKIPPED，改以其余八项裁定，并据实登记。


-- ──────────────────────────────────────────────────────────────────────────────────────────
-- ①c 交叉项校验和（★ 2026-08-24 立 · 取代 ①b 哈希校准，亦取代 ① 之 fp_sum）
-- ──────────────────────────────────────────────────────────────────────────────────────────
--   【何以废 fp_sum】① 之 fp_sum 须两侧同时满足二事方可比对：
--     (a) murmur3 算法与种子一致；(b) CAST(ROUND(x,n) AS STRING) 之渲染逐字一致。
--   (a) 尚可以探针校准，(b) 则无从推定——ROUND(x,4) 究竟渲作 256237.0192 抑或
--   256237.019200，0 渲作 '0' 抑或 '0.0'，因引擎而异。2026-08-24 实测：以五种渲染
--   变体于 R/Python 侧复算，无一命中 SQL 侧之 -142,789,586,420。
--   ★ 结论：fp_sum 之设计**依赖不可控之字串渲染**，属本方设计缺陷，作废（W-P）。
--
--   【代之以整数交叉项 · 何以更可靠】
--     · 不经字串、不经哈希、不经浮点：先 ROUND 至定精度，乘 10^n 化为**精确整数**，
--       再与另一整数列相乘后求和。两侧皆以精确整数算术，逐位可比。
--     · 何以能补 SUM 之不足：列级 SUM 无法察觉「两行互换其值」（合计不变）；
--       而交叉项 Σ(aᵢ·bᵢ) 会变——除非两行之 (a,b) 成比例，概率极低。
--     · 求和可交换，故**与行序无关**，正合分批之需。
SELECT
  SUM(CAST(ROUND(stake_ip,       4) * 10000     AS DECIMAL(38,0))
      * CAST(n_orders_ip  AS DECIMAL(38,0)))                        AS x1_stake_x_orders,
  SUM(CAST(ROUND(net_pnl_ip,     4) * 10000     AS DECIMAL(38,0))
      * CAST(n_rounds_ip  AS DECIMAL(38,0)))                        AS x2_netpnl_x_rounds,
  SUM(CAST(ROUND(ip_order_share, 8) * 100000000 AS DECIMAL(38,0))
      * CAST(n_orders_all AS DECIMAL(38,0)))                        AS x3_share_x_ordersall
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
) x;
--   ★ 分批侧已算出（2026-08-24，自七批合并档 696,403 行，精确整数）：
--       x1_stake_x_orders    =  235,289,238,567,809,030
--       x2_netpnl_x_rounds   =   -2,557,633,517,562,424
--       x3_share_x_ordersall =   10,757,495,877,395,650
--     跑毕三数若全同，D 级即由 8/9 收为 **9/9 全闭**。


-- ──────────────────────────────────────────────────────────────────────────────────────────
-- ② 原版侧「一次导全」对照档（可选 · 仅在库内指纹报 FAIL 时才跑）
-- ──────────────────────────────────────────────────────────────────────────────────────────
--   若 ① 与 R 侧指纹不符，方需此件以定位差异行。届时须一次导全（不分批、不加 rn），
--   与七批合并档做真正的双向反连。未报 FAIL 之前不必跑——跑它即回到分批所欲回避之处。
-- SELECT * FROM (
-- --   WITH ta AS (            -- 公司测试线代理（214 条，跨五级）
--   SELECT DISTINCT age001 AS aid                                                                     --
--   FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'                                             --
--   … 略 …
-- ) x;
-- ══════════════════════════════════════════════════════════════════════════════════════════
