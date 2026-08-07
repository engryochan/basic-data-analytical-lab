/* ═══════════════════════════════════════════════════════════════════════════
   a168 风控与客户分层评分体系 · 商业方案 v3　取数 SQL 包（增补）
   ---------------------------------------------------------------------------
   作者：®γσ ξηg（Ryo Eng）· 世博量化® Scibrokes Trading®
   适用：StarRocks（ods_mariadb_2b），Superset SQL Lab
   窗口：2026-03-21 ~ 2026-08-07（139 营业日，E1 全局窗口，字面量已写死）
   ---------------------------------------------------------------------------
   ★ 三条硬规矩（与 @sec-runbook 一致，违反必出事）
     1. 一次一条 —— SQL Lab 一个 tab 只贴一条语句，跑完再贴下一条。
        批量提交会产生僵尸查询，拖垮集群。
     2. 导出前先数行数 —— 见 §00 COUNT 预检。超过 10 万行的按会员号区间切分，
        **不要用 OFFSET 翻页**：277 批数据出现过 36.49% 重复，根因就是分页没有稳定排序。
     3. 导出编码选 CSV(UTF-8)，文件名一个字都不能错，全部存到报告同目录 `数据库/`。
   ---------------------------------------------------------------------------
   ★ 表名开关（ODS ↔ ADS）
     本包默认 ODS 层：ods_mariadb_2b.ods_a168_bet02（字段名保持 betNN 原样）。
     若贵司走 ADS 层 ads_a168_bet02，**先跑 DESC 核对列名**（ADS 常把
     bet13→stake、bet14→payout、bet16→rebate），再只改每条 SQL 里
     `FROM ods_mariadb_2b.ods_a168_bet02` 这一行 + 在 ranked CTE 里加别名映射。
     不要在几十处逐个改。
   ---------------------------------------------------------------------------
   清单
     §00  COUNT 预检（导出前必跑，5 条，返回个位数行）
     §R01 R01_late_shoe.csv            靴末段下注 + 注额斜率 + 末段ROI
     §R02 R02_same_table.csv           同桌对：同桌率 / Jaccard / 提升度 Lift
     §R03 R03_player_dealer.csv        玩家×荷官：局级胜率 / 玩法基准 Z / 对照胜率
     §T02 T02_daily_roi.csv            会员×日 ROI 序列（索提诺 / CAS 输入）
     §T03 T03_arbitrage.csv            打水型：游戏输赢比 / 自对押率 / 返水依赖
     §E02 E02_segment_econ.csv         分群单位经济学（m / ρ / κ / V / H）
     §B01 B01_bt_panel.csv             会员×日回测面板（策略滚动回测输入）
     §K01 K01_risk_feature_matrix.csv  T4 扩样特征矩阵（含 is_seed 种子列）
   ═══════════════════════════════════════════════════════════════════════════ */


/* ───────────────────────────────────────────────────────────────────────────
   §00 · COUNT 预检　一次出 5 个数字，决定要不要切分导出
   用途：任何一份导出前先看它多大。超过 10 万行就按 bet05 区间切分。
   ─────────────────────────────────────────────────────────────────────────── */
SELECT
  COUNT(*)                                   AS n_rows_raw,
  COUNT(DISTINCT bet01)                      AS n_bet_id,
  COUNT(DISTINCT bet05)                      AS n_member,
  COUNT(DISTINCT CONCAT_WS('|',bet03,bet04,bet39)) AS n_round,
  COUNT(DISTINCT eid)                        AS n_dealer
FROM ods_mariadb_2b.ods_a168_bet02
WHERE dt >= '2026-03-21' AND dt < '2026-08-07'
  AND bet02 = '101'
  AND category = '1'
  AND UPPER(TRIM(bet38)) = 'N';


/* ───────────────────────────────────────────────────────────────────────────
   §00b · 辅助表字段名核对（★ 跑 §E02 / §K01b 之前必做，五秒钟）
   ---------------------------------------------------------------------------
   教训：K-01 首次运行报 `Column 'member_id' cannot be resolved.`，
   根因是 ods_a168_dailyreport_member / ods_a168_alert_ip_setting 的会员列与
   IP 列并不叫 member_id / ip —— 主表 bet02 用 betNN 代号，辅助表各有各的命名。
   本包因此把「一定跑得起来的部分」与「需要先核对列名的部分」彻底分开：
     · §E02 / §K01  —— 只碰 bet02 + agent，**保证跑通**
     · §K01b / §E02c —— 需要辅助表；★ 2026-08-07 列名已实测填实，可直接跑
   下面四条 DESC 各返回十几行，看一眼把真实列名抄下来即可。
   ─────────────────────────────────────────────────────────────────────────── */
DESC ods_mariadb_2b.ods_a168_dailyreport_member;
-- 找：会员标识列（可能叫 mem001 / memberid / username / uid）
--     風險單列（risk）、劃單列（orders）、日期列（dt / report_date）

DESC ods_mariadb_2b.ods_a168_alert_ip_setting;
-- 找：IP 列（可能叫 ip / alert_ip / ipaddress）、备注列（风控员判定原话）

DESC ods_mariadb_2b.ods_a168_member_dtl;
-- 找：会员标识列（doc 记为 mem001）、退水配置列（doc 记为 mem003）

DESC ods_mariadb_2b.ods_a168_employee;
-- 找：工号列（与 bet02.eid 对应）、type 列（type=3 为荷官）


/* ───────────────────────────────────────────────────────────────────────────
   §DX · 两条实测教训的诊断查询（2026-08-07 新增：C-06 零结果 + E1-11 语法错）
   ═══════════════════════════════════════════════════════════════════════════
   §DX-01 · bet09 玩法编码到底长什么样 —— ★ 跑本包任何含 hedge 的查询之前必做
   ---------------------------------------------------------------------------
   背景：C-06「同IP对打对」实测 9.3 秒返回 零结果。该查询的判别是
         bet_side IN ('1','B','庄','莊') / ('2','P','闲','閒')。
         零结果的最可能解释不是「本平台没有对打」——@sec-e1-dist 曾记录
         999 对完美对打、最长 1,185 把——而是 bet09 的实际取值不在这份清单里。
   影响面：凡需区分庄/闲之处全部失效，且失效方式是「静默」的：
         判别不匹配 → is_b/is_p 恒为 0 → hedge_rate 恒为 0 → 阈值 P90 也是 0
         → 打水型闸门形同虚设，却不报任何错。这比报错危险得多。
   ★ 2026-08-07 已实测，结果如下（139 天全量 1.256 亿注单，23 种玩法）：
       Banker 4,682万(37.3%) / Player 4,422万(35.2%) / Tie 964万(7.7%)
       边注 20 种合计 2,496万(19.9%)：BPair PPair Super6 Lucky7 SuperLucky7
            PerfectPair BankerDragonBonus PlayerDragonBonus AnyPair Big
            BankerNatural PlayerNatural Small 等
       另有 7 种玩法（Lucky7TwoCard/SuperTie4,5,8,9/SmallTiger/Bear8）
            各仅 1 笔、均在 2026-07-20 —— 判为**上线试跑残留**，一切统计中剔除。
   结论：C-06 零结果的原因确认为**编码不匹配**，不是「平台无对打」。
   ★ 关键陷阱：不能用 LIKE '%BANK%'。它会把 BankerDragonBonus(20.7万笔)
     与 BankerNatural(6.2万笔) 算成庄——那是边注，与主线庄闲不构成对冲。
     本包三处判别已全部改为 **等值匹配 'Banker' / 'Player'**。
   ─────────────────────────────────────────────────────────────────────────── */
SELECT bet09 AS bet_side_raw,
       COUNT(*)                                            AS n_orders,
       COUNT(DISTINCT bet05)                               AS n_member,
       SUM(CAST(NULLIF(TRIM(bet13),'') AS DECIMAL(20,4)))  AS stake_raw_sum,
       MIN(dt) AS first_day, MAX(dt) AS last_day
FROM ods_mariadb_2b.ods_a168_bet02
WHERE dt >= '2026-03-21' AND dt < '2026-08-07'
  AND bet02 = '101' AND category = '1'
  AND UPPER(TRIM(bet38)) = 'N'
GROUP BY bet09
ORDER BY n_orders DESC;
/* 读法：按 n_orders 排序，前两名通常就是庄与闲（百家乐庄闲各占约四成）。
   把这两个真实取值填回三处判别（§T03 的 is_b/is_p、§B01 与 §K01 的
   is_self_hedge），以及 C-06 的 side CTE。
   本包已用「LIKE 字母码 OR IN 数字/中文码」的宽口径并集先兜一层；
   若真实取值仍在并集之外（例如 '101'/'102' 这类内部码），必须手动改。
   ★ C-06 修复方法：把它的 side CTE 里的
       bet_side IN ('1','B','庄','莊') → bet_side = 'Banker'
       bet_side IN ('2','P','闲','閒') → bet_side = 'Player'
     改完复跑，对打证据链即可复活。 */


/* ═══════════════════════════════════════════════════════════════════════════
   §DX-02 · 为什么 E1-11 报 Unexpected input 'R_rebate_dist'
   ---------------------------------------------------------------------------
   这是注释写法的问题，不是 SQL 本身的问题。原注释里有这么一行：

       导出：（两个星号）数据库/R_rebate_dist.csv（两个星号）

   块注释的终止符是「星号+斜杠」。上面这行里，两个星号与后面的斜杠之间
   只隔着 CJK 字符。当解析链路（Superset 前端预处理 / 剪贴板 / 编辑器编码）
   任何一环丢失或跳过非 ASCII 字符时，那段就塌缩成「星号+斜杠」，
   注释被提前终止，紧随其后的 R_rebate_dist 便成了语句的第一个 token
   —— 报错信息里那个 token 正是它，这也是本判断的依据。

   固化规则：SQL 注释里禁止出现「连续星号」紧邻「斜杠」的写法。
   本包已把所有 (星号星号)数据库/xxx.csv(星号星号) 统一改写为 「数据库/xxx.csv」。
   ═══════════════════════════════════════════════════════════════════════════
   §DX-03 · 取列定义的通用写法（比 DESC 好用：带列注释与顺序，一条顶三条）
   ─────────────────────────────────────────────────────────────────────────── */
SELECT TABLE_NAME, ORDINAL_POSITION, COLUMN_NAME, DATA_TYPE, COLUMN_COMMENT
FROM information_schema.columns
WHERE TABLE_SCHEMA = 'ods_mariadb_2b'
  AND TABLE_NAME IN ('ods_a168_member_dtl',
                     'ods_a168_dailyreport_member',
                     'ods_a168_alert_ip_setting')
ORDER BY TABLE_NAME, ORDINAL_POSITION;
/* 拿到结果即可填回：§E02b 的退水配置列、§K01b 的会员列与 IP 列。
   COLUMN_COMMENT 里常写着中文列义，比靠列名猜可靠得多。 */


/* ───────────────────────────────────────────────────────────────────────────
   §R01 · R01_late_shoe.csv
   策略性风控：靴内第 50 把及之后的下注占比 + 相对靴位 + 注额斜率 + 分段 ROI
   对应报告：@sec-r01
   输出列：uid, n_orders_all, n_orders_late, late_share, shoe_pos_p50,
           stake_late_avg, stake_early_avg, stake_ramp, roi_late, roi_early,
           stake_late, game_pnl_late, stake_all, game_pnl_all
   预期行数：数千 ~ 数万（HAVING 已收敛）
   ─────────────────────────────────────────────────────────────────────────── */
WITH test_agents AS (
  SELECT age001 AS agent_id
  FROM ods_mariadb_2b.ods_a168_agent
  WHERE age022 = '1'                                  -- 铁律④b：公司测试线
),
ranked AS (                                            -- 需求 §3.2：同单号保留最新版本
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b                 -- ★ 表名开关
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101'
),
base AS (
  SELECT r.bet01 AS bet_id, r.bet05 AS member_id,
         r.bet03 AS shoe_id, r.bet39 AS table_id,
         CAST(NULLIF(TRIM(r.bet04),'') AS INT)           AS round_no,
         CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) AS fx,
         CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)) AS stake_raw,
         CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4)) AS payout_raw
  FROM ranked r
  /* StarRocks 不支持 EXISTS + 多列 IN，测试线剔除改五路 LEFT JOIN */
  LEFT JOIN test_agents t1 ON t1.agent_id = r.bet18
  LEFT JOIN test_agents t2 ON t2.agent_id = r.bet19
  LEFT JOIN test_agents t3 ON t3.agent_id = r.bet20
  LEFT JOIN test_agents t4 ON t4.agent_id = r.bet21
  LEFT JOIN test_agents t5 ON t5.agent_id = r.bet22
  WHERE r.rn = 1
    AND r.category = '1'
    AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND CAST(NULLIF(TRIM(r.bet04),'') AS INT) > 0
    AND COALESCE(t1.agent_id,t2.agent_id,t3.agent_id,t4.agent_id,t5.agent_id) IS NULL
),
shoe_len AS (          -- 缺陷一修正：靴长不定，固定 50 不是固定位置
  SELECT shoe_id, table_id, MAX(round_no) AS max_round
  FROM base GROUP BY shoe_id, table_id
),
enriched AS (
  SELECT b.member_id, b.shoe_id, b.table_id, b.round_no, s.max_round,
         b.round_no * 1.0 / NULLIF(s.max_round,0)     AS shoe_pos,
         b.stake_raw / b.fx                           AS stake,
         (b.payout_raw - b.stake_raw) / b.fx          AS game_pnl,
         CASE WHEN b.round_no >= 50 THEN 1 ELSE 0 END AS is_late
  FROM base b
  JOIN shoe_len s ON s.shoe_id = b.shoe_id AND s.table_id = b.table_id
)
SELECT
  member_id                                                     AS uid,
  COUNT(*)                                                      AS n_orders_all,
  SUM(is_late)                                                  AS n_orders_late,
  SUM(is_late) * 1.0 / COUNT(*)                                 AS late_share,
  PERCENTILE_APPROX(CASE WHEN is_late=1 THEN shoe_pos END, 0.5) AS shoe_pos_p50,
  SUM(CASE WHEN is_late=1 THEN stake END) / NULLIF(SUM(is_late),0)              AS stake_late_avg,
  SUM(CASE WHEN is_late=0 THEN stake END) / NULLIF(COUNT(*)-SUM(is_late),0)     AS stake_early_avg,
  (SUM(CASE WHEN is_late=1 THEN stake END) / NULLIF(SUM(is_late),0))
    / NULLIF(SUM(CASE WHEN is_late=0 THEN stake END)
             / NULLIF(COUNT(*)-SUM(is_late),0), 0)                              AS stake_ramp,
  SUM(CASE WHEN is_late=1 THEN game_pnl END)
    / NULLIF(SUM(CASE WHEN is_late=1 THEN stake END),0)                         AS roi_late,
  SUM(CASE WHEN is_late=0 THEN game_pnl END)
    / NULLIF(SUM(CASE WHEN is_late=0 THEN stake END),0)                         AS roi_early,
  SUM(CASE WHEN is_late=1 THEN stake END)                                       AS stake_late,
  SUM(CASE WHEN is_late=1 THEN game_pnl END)                                    AS game_pnl_late,
  SUM(stake)                                                                    AS stake_all,
  SUM(game_pnl)                                                                 AS game_pnl_all
FROM enriched
GROUP BY member_id
HAVING COUNT(*) >= 100                                    -- 需求：订单数据 > 100 笔
ORDER BY late_share DESC, n_orders_late DESC;
/* ⚠️ 注意：此处**故意不加** late_share >= 0.70 的 HAVING。
   报告需要「命中组 vs 对照组」的 hold% 对照才能做经济裁定（@sec-r01 的 r01-decision），
   只导命中组就没有对照组。阈值筛选一律放在 R 侧做，SQL 只负责给全量底料。
   若行数过大，改为 HAVING COUNT(*) >= 300 提高活跃度门槛，而不是加 late_share 条件。 */


/* ───────────────────────────────────────────────────────────────────────────
   §R02 · R02_same_table.csv
   团伙同桌：两阶段自连接（先压到会员×物理局并限候选池，再 join）
   对应报告：@sec-r02
   输出列：uid1, uid2, n_same_orders, rounds_1, rounds_2,
           same_rate, jaccard, lift, exp_same, n_tables, first_day, last_day
   ★ 绝不可对 bet02 原表直接自连接：1.9 亿 × 1.9 亿 必然打爆集群。
   ─────────────────────────────────────────────────────────────────────────── */
WITH mr AS (                          -- 阶段一：会员 × 物理局，去重后每人每局一行
  SELECT DISTINCT
         b.bet05 AS member_id,
         CONCAT_WS('|', b.bet03, b.bet04, b.bet39) AS round_key,
         b.bet39 AS table_id,
         b.dt    AS bet_date
  FROM ods_mariadb_2b.ods_a168_bet02 b            -- ★ 表名开关
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101' AND b.category = '1'
    AND UPPER(TRIM(b.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(b.bet05),'') AS BIGINT) > 0
),
act AS (                              -- 候选池：局数不够就不可能凑到 100 局同桌
  SELECT member_id, COUNT(*) AS n_rounds
  FROM mr GROUP BY member_id HAVING COUNT(*) >= 100
),
mr2 AS (
  SELECT m.* FROM mr m JOIN act a ON a.member_id = m.member_id
),
pair AS (                             -- 阶段二：同局自连接（已压到候选池）
  SELECT x.member_id AS uid1, y.member_id AS uid2,
         COUNT(*)                    AS same_rounds,
         COUNT(DISTINCT x.table_id)  AS n_tables,
         MIN(x.bet_date)             AS first_day,
         MAX(x.bet_date)             AS last_day
  FROM mr2 x
  JOIN mr2 y ON x.round_key = y.round_key AND x.member_id < y.member_id
  GROUP BY x.member_id, y.member_id
  HAVING COUNT(*) >= 100                           -- 需求：同桌订单数 > 100 笔
),
td AS (                               -- Lift 零假设的分子件：每人每桌每日局数
  SELECT table_id, bet_date, member_id, COUNT(*) AS n_md
  FROM mr2 GROUP BY table_id, bet_date, member_id
),
tot AS (                              -- Lift 零假设的分母件：每桌每日总局数
  SELECT table_id, bet_date, COUNT(DISTINCT round_key) AS n_td
  FROM mr2 GROUP BY table_id, bet_date
),
expct AS (                            -- E[same] = Σ n_a(t,d)·n_b(t,d) / N(t,d)
  SELECT a.member_id AS uid1, b.member_id AS uid2,
         SUM(a.n_md * b.n_md * 1.0 / NULLIF(t.n_td,0)) AS exp_same
  FROM td a
  JOIN td b  ON a.table_id = b.table_id AND a.bet_date = b.bet_date
            AND a.member_id < b.member_id
  JOIN tot t ON t.table_id = a.table_id AND t.bet_date = a.bet_date
  GROUP BY a.member_id, b.member_id
)
SELECT p.uid1, p.uid2,
       p.same_rounds                                          AS n_same_orders,
       a1.n_rounds                                            AS rounds_1,
       a2.n_rounds                                            AS rounds_2,
       p.same_rounds * 1.0
         / NULLIF(LEAST(a1.n_rounds, a2.n_rounds),0)          AS same_rate,   -- 需求口径
       p.same_rounds * 1.0
         / NULLIF(a1.n_rounds + a2.n_rounds - p.same_rounds,0) AS jaccard,    -- 对照口径
       p.same_rounds * 1.0 / NULLIF(e.exp_same, 0)            AS lift,        -- ★ 去巧合
       e.exp_same, p.n_tables, p.first_day, p.last_day
FROM pair p
JOIN act a1 ON a1.member_id = p.uid1
JOIN act a2 ON a2.member_id = p.uid2
LEFT JOIN expct e ON e.uid1 = p.uid1 AND e.uid2 = p.uid2
ORDER BY lift DESC, same_rate DESC;
/* ⚠️ 同上：**故意不加** same_rate >= 0.30 的 WHERE。阈值网格（@sec-r02 的 r02-grid）
   要扫 30%/40%/50%/70% × Lift 1/2/3/5 十六格，只导 30% 以上就扫不出下沿。
   若行数仍过大，把 act 的门槛从 100 提到 300，而不是加 same_rate 条件。
   跑不动时按桌台切分：在 mr 的 WHERE 加 AND b.bet39 IN ('T01','T02',...) 分批跑。 */


/* ───────────────────────────────────────────────────────────────────────────
   §R03 · R03_player_dealer.csv
   玩家×荷官关联异常：局级去重 + 玩法基准 Z-score + 对照胜率
   对应报告：@sec-r03
   ★ 已实现《荷官作弊风控阈值分析报告》自列的必补检查：
     用 bet03+bet04 统计关联有效局数，修正同局拆多单造成的 Z-score 放大。
   输出列：uid, dealer_id, stake_amount, profit_amount, net_pnl, win_rate,
           n_related_orders, n_rounds_eff, p_base_mix, z_score,
           net_pnl_all, game_pnl_all, stake_all, win_rate_all, win_rate_other
   ─────────────────────────────────────────────────────────────────────────── */
WITH ranked AS (
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b            -- ★ 表名开关
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101' AND b.category = '1'
),
base AS (
  SELECT r.bet01 AS bet_id, r.bet05 AS member_id, r.eid AS dealer_id,
         r.bet09 AS bet_side,
         CONCAT_WS('|', r.bet03, r.bet04, r.bet39) AS round_key,
         CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) AS fx,
         CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)) AS stake_raw,
         CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4)) AS payout_raw,
         CAST(NULLIF(TRIM(r.bet17),'') AS DECIMAL(20,4)) AS net_raw
  FROM ranked r
  WHERE r.rn = 1
    AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND NULLIF(TRIM(r.eid),'') IS NOT NULL
    AND UPPER(TRIM(r.bet09)) NOT LIKE 'TIP\_1\_%'      -- 阈值报告：排除小费单
),
ord AS (
  SELECT bet_id, member_id, dealer_id, bet_side, round_key,
         stake_raw / fx                AS stake,
         (payout_raw - stake_raw) / fx AS game_pnl,
         net_raw / fx                  AS net_pnl
  FROM base
),
side_base AS (      -- ★ 玩法基准胜率：Banker/Player/Tie/Big/Small 各算各的
  SELECT bet_side,
         SUM(CASE WHEN game_pnl > 0 THEN 1 ELSE 0 END) * 1.0
           / NULLIF(SUM(CASE WHEN game_pnl <> 0 THEN 1 ELSE 0 END), 0) AS p_base
  FROM ord GROUP BY bet_side
),
pr AS (             -- ★ 局级去重：同局多单折成一局，Z-score 才不被 √k 倍放大
  SELECT member_id, dealer_id, round_key,
         SUM(stake)    AS stake,
         SUM(game_pnl) AS game_pnl,
         SUM(net_pnl)  AS net_pnl,
         COUNT(*)      AS n_orders_in_round,
         MAX(bet_side) AS main_side
  FROM ord GROUP BY member_id, dealer_id, round_key
),
player_all AS (     -- 需求条件：用户整体盈利
  SELECT member_id,
         SUM(net_pnl)  AS net_pnl_all,
         SUM(game_pnl) AS game_pnl_all,
         SUM(stake)    AS stake_all,
         SUM(CASE WHEN game_pnl >  0 THEN 1 ELSE 0 END) AS win_all,
         SUM(CASE WHEN game_pnl <> 0 THEN 1 ELSE 0 END) AS dec_all
  FROM pr GROUP BY member_id
),
pd AS (
  SELECT p.member_id, p.dealer_id,
         COUNT(*)                                          AS n_rounds_eff,
         SUM(p.n_orders_in_round)                          AS n_orders,
         SUM(p.stake)                                      AS stake,
         SUM(p.game_pnl)                                   AS game_pnl,
         SUM(p.net_pnl)                                    AS net_pnl,
         SUM(CASE WHEN p.game_pnl >  0 THEN 1 ELSE 0 END)  AS n_win,
         SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END)  AS n_dec,
         AVG(COALESCE(s.p_base, 0.5))                      AS p_base_mix
  FROM pr p
  LEFT JOIN side_base s ON s.bet_side = p.main_side
  GROUP BY p.member_id, p.dealer_id
)
SELECT
  pd.member_id AS uid, pd.dealer_id,
  pd.stake      AS stake_amount,      -- 需求「投注金额」
  pd.game_pnl   AS profit_amount,     -- 需求「盈利金额」（剔返水口径）
  pd.net_pnl,
  pd.n_win * 1.0 / NULLIF(pd.n_dec, 0)              AS win_rate,          -- 需求「胜率」
  pd.n_orders  AS n_related_orders,                                       -- 需求「关联订单笔数」
  pd.n_rounds_eff, pd.p_base_mix,
  (pd.n_win - pd.n_dec * pd.p_base_mix)
    / NULLIF(SQRT(pd.n_dec * pd.p_base_mix * (1 - pd.p_base_mix)), 0)  AS z_score,
  pa.net_pnl_all, pa.game_pnl_all, pa.stake_all,
  pa.win_all * 1.0 / NULLIF(pa.dec_all, 0)          AS win_rate_all,
  (pa.win_all - pd.n_win) * 1.0
    / NULLIF(pa.dec_all - pd.n_dec, 0)              AS win_rate_other     -- ★ 对照检验
FROM pd
JOIN player_all pa ON pa.member_id = pd.member_id
WHERE pd.n_rounds_eff >= 30                 -- 阈值报告口径：有效局数下限
ORDER BY z_score DESC, profit_amount DESC;
/* ⚠️ 此处保留 n_rounds_eff>=30（阈值报告已论证 30 以下噪声主导），
   但**不加** win_rate>0.70 / net_pnl_all>0：四条规则对照表（@sec-r03 的 r03-dual）
   需要在同一份底料上比较需求原口径与修正口径，加了就比不了。 */


/* ───────────────────────────────────────────────────────────────────────────
   §T02 · T02_daily_roi.csv
   会员 × 日 的投注与游戏输赢序列 —— 索提诺 / CAS 的唯一输入
   对应报告：@sec-t2
   输出列：member_id, bet_date, stake, game_pnl, n_rounds
   预期行数：大。**必须切分导出**（见文末切分模板），或先加活跃度门槛。
   ─────────────────────────────────────────────────────────────────────────── */
WITH test_agents AS (
  SELECT age001 AS agent_id FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
ranked AS (
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b            -- ★ 表名开关
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101'
),
ord AS (
  SELECT r.bet05 AS member_id, r.dt AS bet_date,
         CONCAT_WS('|', r.bet03, r.bet04, r.bet39) AS round_key,
         CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4))
           / NULLIF(CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)),0) AS stake,
         (CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4))
          - CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)))
           / NULLIF(CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)),0) AS game_pnl
  FROM ranked r
  LEFT JOIN test_agents t1 ON t1.agent_id = r.bet18
  LEFT JOIN test_agents t2 ON t2.agent_id = r.bet19
  LEFT JOIN test_agents t3 ON t3.agent_id = r.bet20
  LEFT JOIN test_agents t4 ON t4.agent_id = r.bet21
  LEFT JOIN test_agents t5 ON t5.agent_id = r.bet22
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND COALESCE(t1.agent_id,t2.agent_id,t3.agent_id,t4.agent_id,t5.agent_id) IS NULL
),
act AS (   -- 报告里索提诺要求「活跃日 ≥ 20」，少于 20 天的会员导出来也用不上
  SELECT member_id FROM ord
  GROUP BY member_id HAVING COUNT(DISTINCT bet_date) >= 20
)
SELECT o.member_id, o.bet_date,
       SUM(o.stake)                     AS stake,
       SUM(o.game_pnl)                  AS game_pnl,
       COUNT(DISTINCT o.round_key)      AS n_rounds
FROM ord o JOIN act a ON a.member_id = o.member_id
GROUP BY o.member_id, o.bet_date
ORDER BY o.member_id, o.bet_date;


/* ───────────────────────────────────────────────────────────────────────────
   §T03 · T03_arbitrage.csv
   打水型：游戏输赢趋零 × 账户仍在赚 × 对押率高
   对应报告：@sec-t3
   输出列：member_id, stake, validbet, game_pnl, net_pnl, rebate,
           hedge_rate, stake_cv, n_rounds, n_days
   ★ hedge_rate 口径说明：此处为**自对押率**（同一物理局内该会员同时押到
     庄侧与闲侧的局数占比），是单表可算的打水指纹。
     **跨会员对押**（一庄一闲两个号）不在本查询范围，由 §R02 / C-06 并入。
   ─────────────────────────────────────────────────────────────────────────── */
WITH test_agents AS (
  SELECT age001 AS agent_id FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
ranked AS (
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b            -- ★ 表名开关
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101'
),
ord AS (
  SELECT r.bet05 AS member_id, r.dt AS bet_date, r.bet09 AS bet_side,
         CONCAT_WS('|', r.bet03, r.bet04, r.bet39) AS round_key,
         CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) AS fx,
         CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)) AS stake_raw,
         CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4)) AS payout_raw,
         CAST(NULLIF(TRIM(r.bet16),'') AS DECIMAL(20,4)) AS rebate_raw,
         CAST(NULLIF(TRIM(r.bet17),'') AS DECIMAL(20,4)) AS net_raw,
         CAST(NULLIF(TRIM(r.validbet),'') AS DECIMAL(20,4)) AS vb_raw
  FROM ranked r
  LEFT JOIN test_agents t1 ON t1.agent_id = r.bet18
  LEFT JOIN test_agents t2 ON t2.agent_id = r.bet19
  LEFT JOIN test_agents t3 ON t3.agent_id = r.bet20
  LEFT JOIN test_agents t4 ON t4.agent_id = r.bet21
  LEFT JOIN test_agents t5 ON t5.agent_id = r.bet22
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND COALESCE(t1.agent_id,t2.agent_id,t3.agent_id,t4.agent_id,t5.agent_id) IS NULL
),
o2 AS (
  SELECT member_id, bet_date, round_key,
         stake_raw / fx                AS stake,
         COALESCE(vb_raw,stake_raw)/fx AS validbet,
         (payout_raw - stake_raw)/fx   AS game_pnl,
         rebate_raw / fx               AS rebate,
         net_raw / fx                  AS net_pnl,
         /* ★ 2026-08-07 DX-01 实测校准：bet09 为英文玩法名。
            必须用等值匹配，不能用 LIKE '%BANK%' —— 后者会把
            BankerDragonBonus(20.7万) 与 BankerNatural(6.2万) 一并算成庄，
            而那是边注，与主线庄闲不构成对冲关系。 */
         CASE WHEN TRIM(bet_side) = 'Banker' THEN 1 ELSE 0 END AS is_b,
         CASE WHEN TRIM(bet_side) = 'Player' THEN 1 ELSE 0 END AS is_p
  FROM ord
),
rk AS (      -- 局级：该会员本局是否同时押了庄与闲（自对押）
  SELECT member_id, bet_date, round_key,
         SUM(stake) AS stake, SUM(validbet) AS validbet,
         SUM(game_pnl) AS game_pnl, SUM(rebate) AS rebate, SUM(net_pnl) AS net_pnl,
         CASE WHEN MAX(is_b)=1 AND MAX(is_p)=1 THEN 1 ELSE 0 END AS is_self_hedge
  FROM o2 GROUP BY member_id, bet_date, round_key
)
SELECT member_id,
       SUM(stake)                          AS stake,
       SUM(validbet)                       AS validbet,
       SUM(game_pnl)                       AS game_pnl,
       SUM(net_pnl)                        AS net_pnl,
       SUM(rebate)                         AS rebate,
       SUM(is_self_hedge) * 1.0 / COUNT(*) AS hedge_rate,     -- 自对押率
       STDDEV_SAMP(stake) / NULLIF(AVG(stake),0) AS stake_cv, -- 注额变异系数（打水者极低）
       COUNT(*)                            AS n_rounds,
       COUNT(DISTINCT bet_date)            AS n_days
FROM rk
GROUP BY member_id
HAVING COUNT(*) >= 100                       -- 局数太少算不出稳定的比率
ORDER BY hedge_rate DESC, validbet DESC;


/* ───────────────────────────────────────────────────────────────────────────
   §E02 · E02_segment_econ.csv
   分群单位经济学 —— 赏罚经济学引擎（@sec-econ）的唯一输入
   输出列：segment, n_member, validbet, ggr, rebate, commission, tenure_months
   口径：
     ggr        = -SUM(game_pnl)         庄家从该群赢到的钱（剔返水）
     rebate     =  SUM(rebate)           返水支出
     commission =  占成支出（**当前置 0**，见下方警告）
     tenure_months = 该群平均活跃月数（H 的经验代理，正式版应由 Cox/RSF 给出）
   分群：退水档位 × 洗码量四分位（均由数据算出，不写死档位）
   ─────────────────────────────────────────────────────────────────────────── */
WITH test_agents AS (
  SELECT age001 AS agent_id FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
ranked AS (
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b            -- ★ 表名开关
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101'
),
ord AS (
  SELECT r.bet05 AS member_id, r.dt AS bet_date,
         CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) AS fx,
         CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)) AS stake_raw,
         CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4)) AS payout_raw,
         CAST(NULLIF(TRIM(r.bet16),'') AS DECIMAL(20,4)) AS rebate_raw,
         CAST(NULLIF(TRIM(r.validbet),'') AS DECIMAL(20,4)) AS vb_raw
  FROM ranked r
  LEFT JOIN test_agents t1 ON t1.agent_id = r.bet18
  LEFT JOIN test_agents t2 ON t2.agent_id = r.bet19
  LEFT JOIN test_agents t3 ON t3.agent_id = r.bet20
  LEFT JOIN test_agents t4 ON t4.agent_id = r.bet21
  LEFT JOIN test_agents t5 ON t5.agent_id = r.bet22
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND COALESCE(t1.agent_id,t2.agent_id,t3.agent_id,t4.agent_id,t5.agent_id) IS NULL
),
mem AS (
  SELECT member_id,
         SUM(COALESCE(vb_raw,stake_raw)/fx)                       AS validbet,
         SUM((payout_raw - stake_raw)/fx)                         AS game_pnl,
         SUM(rebate_raw/fx)                                       AS rebate,
         COUNT(DISTINCT DATE_FORMAT(CAST(bet_date AS DATE),'%Y-%m'))            AS n_months,
         COUNT(DISTINCT bet_date)                                 AS n_days
  FROM ord GROUP BY member_id
),
mem2 AS (
  /* ★ 自足版：退水档位用「实测退水率」= rebate 除以 validbet 分档，
     不 join member_dtl —— 该表的会员列名尚未核对（见 §00b），
     且实测口径本来就比配置口径更贴近真实成本。
     若已核对好列名、想用配置档位，改跑下方 §E02b。 */
  SELECT m.*,
         ROUND(m.rebate / NULLIF(m.validbet,0), 3) AS rebate_rate_bkt,
         NTILE(4) OVER (ORDER BY m.validbet) AS vb_q
  FROM mem m
  WHERE m.validbet > 0
)
SELECT
  CONCAT('实测退水', CAST(rebate_rate_bkt AS STRING),
         ' · 流水Q', CAST(vb_q AS STRING))   AS segment,
  COUNT(*)                                   AS n_member,
  SUM(validbet)                              AS validbet,
  -SUM(game_pnl)                             AS ggr,          -- 庄家赢 = 玩家输
  SUM(rebate)                                AS rebate,
  0                                          AS commission,   -- ⚠️ 见下方警告
  AVG(n_months)                              AS tenure_months
FROM mem2
GROUP BY rebate_rate_bkt, vb_q
ORDER BY validbet DESC;
/* ⚠️⚠️ commission（代理占成）当前恒置 0 —— 这是本包唯一一个**已知不完整**的字段。
   bet02 里的 commission 是「佣金模式标记」（免佣桌/一般桌），不是占成金额。
   信用盘占成惯例 1–2.5%，若不补齐，@sec-econ 算出的净贡献率会**系统性偏乐观**，
   δ* 偏小、γ* 偏大（赏得过头）。
   补齐路径：从代理合同表取各 LV 层占成比例，按 bet18–bet22 沿链分摊到会员。
   在补齐之前，E02 的 γ*（赏项上限）一律视为**上界估计，不得直接下发**。 */


/* ───────────────────────────────────────────────────────────────────────────
   §B01 · B01_bt_panel.csv
   会员 × 日 回测面板 —— 策略滚动回测（@sec-strategy-bt）的输入
   输出列：member_id, bet_date, stake, game_pnl, net_pnl, rebate, validbet,
           n_rounds, n_tables, n_ip, late_share_d, hedge_rate_d, stake_cv_d
   ★ 本查询**不产出 risk_score**：风险分是被拟合的量，由 R 侧
     compose_risk_score() 在各折训练窗内算出。SQL 只给原始特征，
     在 SQL 里预先算好风险分再回测 = 用全样本定分数 = 信息泄漏。
   ─────────────────────────────────────────────────────────────────────────── */
WITH test_agents AS (
  SELECT age001 AS agent_id FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
ranked AS (
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b            -- ★ 表名开关
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101'
),
ord AS (
  SELECT r.bet05 AS member_id, r.dt AS bet_date, r.bet39 AS table_id, r.ip AS bet_ip,
         r.bet09 AS bet_side,
         CONCAT_WS('|', r.bet03, r.bet04, r.bet39) AS round_key,
         CAST(NULLIF(TRIM(r.bet04),'') AS INT)           AS round_no,
         CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) AS fx,
         CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)) AS stake_raw,
         CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4)) AS payout_raw,
         CAST(NULLIF(TRIM(r.bet16),'') AS DECIMAL(20,4)) AS rebate_raw,
         CAST(NULLIF(TRIM(r.bet17),'') AS DECIMAL(20,4)) AS net_raw,
         CAST(NULLIF(TRIM(r.validbet),'') AS DECIMAL(20,4)) AS vb_raw
  FROM ranked r
  LEFT JOIN test_agents t1 ON t1.agent_id = r.bet18
  LEFT JOIN test_agents t2 ON t2.agent_id = r.bet19
  LEFT JOIN test_agents t3 ON t3.agent_id = r.bet20
  LEFT JOIN test_agents t4 ON t4.agent_id = r.bet21
  LEFT JOIN test_agents t5 ON t5.agent_id = r.bet22
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND COALESCE(t1.agent_id,t2.agent_id,t3.agent_id,t4.agent_id,t5.agent_id) IS NULL
),
rk AS (
  SELECT member_id, bet_date, round_key, MAX(table_id) AS table_id,
         MAX(bet_ip) AS bet_ip, MAX(round_no) AS round_no,
         SUM(stake_raw/fx)                     AS stake,
         SUM(COALESCE(vb_raw,stake_raw)/fx)    AS validbet,
         SUM((payout_raw-stake_raw)/fx)        AS game_pnl,
         SUM(rebate_raw/fx)                    AS rebate,
         SUM(net_raw/fx)                       AS net_pnl,
         /* ★ DX-01 实测校准：等值匹配主线庄闲，不用 LIKE（会误纳龙宝/天牌边注） */
         CASE WHEN MAX(CASE WHEN TRIM(bet_side)='Banker' THEN 1 ELSE 0 END)=1
               AND MAX(CASE WHEN TRIM(bet_side)='Player' THEN 1 ELSE 0 END)=1
              THEN 1 ELSE 0 END                AS is_self_hedge
  FROM ord GROUP BY member_id, bet_date, round_key
)
SELECT member_id, bet_date,
       SUM(stake)                                     AS stake,
       SUM(game_pnl)                                  AS game_pnl,
       SUM(net_pnl)                                   AS net_pnl,
       SUM(rebate)                                    AS rebate,
       SUM(validbet)                                  AS validbet,
       COUNT(*)                                       AS n_rounds,
       COUNT(DISTINCT table_id)                       AS n_tables,
       COUNT(DISTINCT bet_ip)                         AS n_ip,
       SUM(CASE WHEN round_no >= 50 THEN 1 ELSE 0 END) * 1.0 / COUNT(*) AS late_share_d,
       SUM(is_self_hedge) * 1.0 / COUNT(*)            AS hedge_rate_d,
       STDDEV_SAMP(stake) / NULLIF(AVG(stake),0)      AS stake_cv_d
FROM rk
GROUP BY member_id, bet_date
ORDER BY bet_date, member_id;


/* ───────────────────────────────────────────────────────────────────────────
   §K01 · K01_risk_feature_matrix.csv
   T4 扩样特征矩阵（@sec-t4）：会员级特征 + is_seed 种子标记
   ★ 种子必须**混合来源**（人工風險單 + R-01/R-02/R-03 + L0 金标准），
     否则 PU 模型学到的只是「某一条规则」，扩样等于把规则重跑一遍。
   ★ 特征侧**刻意排除**产生种子的那几个量（late_share / same_rate / z_score），
     否则就是自我循环。此处只给「行为结构」类特征。
   输出列：member_id, is_seed, n_rounds, n_days, n_tables, n_ip, n_dealer,
           side_entropy, stake_cv, stake_p90_p50, hedge_rate, rebate_dep,
           night_share, roi_game, validbet
   ─────────────────────────────────────────────────────────────────────────── */
WITH test_agents AS (
  SELECT age001 AS agent_id FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
ranked AS (
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b            -- ★ 表名开关
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101'
),
ord AS (
  SELECT r.bet05 AS member_id, r.dt AS bet_date, r.bet39 AS table_id,
         r.ip AS bet_ip, r.eid AS dealer_id, r.bet09 AS bet_side,
         CONCAT_WS('|', r.bet03, r.bet04, r.bet39) AS round_key,
         HOUR(CAST(NULLIF(TRIM(r.bet08),'') AS DATETIME)) AS bet_hour,
         CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) AS fx,
         CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)) AS stake_raw,
         CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4)) AS payout_raw,
         CAST(NULLIF(TRIM(r.bet16),'') AS DECIMAL(20,4)) AS rebate_raw,
         CAST(NULLIF(TRIM(r.bet17),'') AS DECIMAL(20,4)) AS net_raw,
         CAST(NULLIF(TRIM(r.validbet),'') AS DECIMAL(20,4)) AS vb_raw
  FROM ranked r
  LEFT JOIN test_agents t1 ON t1.agent_id = r.bet18
  LEFT JOIN test_agents t2 ON t2.agent_id = r.bet19
  LEFT JOIN test_agents t3 ON t3.agent_id = r.bet20
  LEFT JOIN test_agents t4 ON t4.agent_id = r.bet21
  LEFT JOIN test_agents t5 ON t5.agent_id = r.bet22
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND COALESCE(t1.agent_id,t2.agent_id,t3.agent_id,t4.agent_id,t5.agent_id) IS NULL
),
side_mix AS (      -- 玩法熵：只押单一玩法（熵≈0）是打水/技术型的共同结构特征
  SELECT member_id, bet_side, COUNT(*) AS n_side
  FROM ord GROUP BY member_id, bet_side
),
side_ent AS (
  SELECT s.member_id,
         -SUM((s.n_side*1.0/t.n_all) * LOG2(s.n_side*1.0/t.n_all)) AS side_entropy
  FROM side_mix s
  JOIN (SELECT member_id, SUM(n_side) AS n_all FROM side_mix GROUP BY member_id) t
    ON t.member_id = s.member_id
  GROUP BY s.member_id
),
rk AS (
  SELECT member_id, bet_date, round_key,
         MAX(table_id) AS table_id, MAX(bet_ip) AS bet_ip,
         MAX(dealer_id) AS dealer_id, MAX(bet_hour) AS bet_hour,
         SUM(stake_raw/fx) AS stake,
         SUM(COALESCE(vb_raw,stake_raw)/fx) AS validbet,
         SUM((payout_raw-stake_raw)/fx) AS game_pnl,
         SUM(rebate_raw/fx) AS rebate,
         SUM(net_raw/fx)    AS net_pnl,
         /* ★ DX-01 实测校准：等值匹配主线庄闲，不用 LIKE（会误纳龙宝/天牌边注） */
         CASE WHEN MAX(CASE WHEN TRIM(bet_side)='Banker' THEN 1 ELSE 0 END)=1
               AND MAX(CASE WHEN TRIM(bet_side)='Player' THEN 1 ELSE 0 END)=1
              THEN 1 ELSE 0 END AS is_self_hedge
  FROM ord GROUP BY member_id, bet_date, round_key
),
feat AS (
  SELECT member_id,
         COUNT(*)                        AS n_rounds,
         COUNT(DISTINCT bet_date)        AS n_days,
         COUNT(DISTINCT table_id)        AS n_tables,
         COUNT(DISTINCT bet_ip)          AS n_ip,
         COUNT(DISTINCT dealer_id)       AS n_dealer,
         STDDEV_SAMP(stake)/NULLIF(AVG(stake),0)              AS stake_cv,
         PERCENTILE_APPROX(stake,0.9)
           / NULLIF(PERCENTILE_APPROX(stake,0.5),0)           AS stake_p90_p50,
         SUM(is_self_hedge)*1.0/COUNT(*)                      AS hedge_rate,
         SUM(rebate)/NULLIF(ABS(SUM(net_pnl)),0)              AS rebate_dep,
         SUM(CASE WHEN bet_hour BETWEEN 0 AND 6 THEN 1 ELSE 0 END)*1.0/COUNT(*) AS night_share,
         SUM(game_pnl)/NULLIF(SUM(stake),0)                   AS roi_game,
         SUM(validbet)                                        AS validbet
  FROM rk GROUP BY member_id
)
SELECT f.member_id,
       CAST(0 AS INT) AS is_seed,          -- ★ 占位列：种子一律在 Python 侧并入，见下方说明
       f.n_rounds, f.n_days, f.n_tables, f.n_ip, f.n_dealer,
       COALESCE(se.side_entropy, 0) AS side_entropy,
       f.stake_cv, f.stake_p90_p50, f.hedge_rate, f.rebate_dep,
       f.night_share, f.roi_game, f.validbet
FROM feat f
LEFT JOIN side_ent se ON se.member_id = f.member_id
WHERE f.n_rounds >= 50
ORDER BY f.validbet DESC;
/* ═══ 为什么 is_seed 恒为 0 —— 这是刻意的，不是遗漏 ═══════════════════════════
   首版这里 join 了 dailyreport_member 与 alert_ip_setting，实跑报错：
     StarRocks: Column 'member_id' cannot be resolved.
   根因：主表 bet02 用 betNN 代号，辅助表各有各的命名，两张辅助表的会员列
   与 IP 列都不叫 member_id / ip。列名未核对就写 join，是本包唯一一次踩坑。

   斧正后的分工（也更符合「种子必须混合来源」这条原则）：
     · 本查询 = **纯特征矩阵**，只碰 bet02 + agent，保证任何时候都跑得通；
     · 五路种子全部在 Python 侧合并（@sec-t4 的 t4-cluster 块已实现）：
         ①人工風險單/劃單  ②L0 金标准 IP  ③R-01 闸三  ④R-02 Lift≥3  ⑤R-03 Z≥4
       其中 ③④⑤ 直接读 R01/R02/R03 三份 CSV；①② 走下方 §K01b。
   好处：任何一路种子缺位，T4 仍能用其余几路跑起来，不会因一张辅助表卡死全章。
   ═══════════════════════════════════════════════════════════════════════════ */


/* ═══════════════════════════════════════════════════════════════════════════
   §K01b · 种子来源①② —— ★ 2026-08-07 列名已实测填实，可直接运行
   ---------------------------------------------------------------------------
   实测列定义（information_schema 确认）：
     ods_a168_dailyreport_member : bet05=會員編號  risk=風險單(1:是)  orders=劃單(1:是)
                                   dt=日分区  category=1一般/2小費  bet02=遊戲編號
     ods_a168_alert_ip_setting   : ip  creator  addtime  remarks(风控员判定原话)
   导出：「数据库/K01b_seed_manual.csv」（两条各跑一次，纵向合并成一份）
   ═══════════════════════════════════════════════════════════════════════════ */
-- ① 人工風險單 / 劃單（L1a 人工标签）
SELECT DISTINCT bet05 AS member_id, 'manual_risk' AS seed_src
FROM ods_mariadb_2b.ods_a168_dailyreport_member
WHERE dt >= '2026-03-21' AND dt < '2026-08-07'
  AND bet02 = '101'
  AND (CAST(NULLIF(TRIM(risk),'')   AS INT) = 1
    OR CAST(NULLIF(TRIM(orders),'') AS INT) = 1)
  AND CAST(NULLIF(TRIM(bet05),'') AS BIGINT) > 0
ORDER BY member_id;
-- 注意：risk/orders 在 ODS 里是 varchar 承载的 tinyint，必须 CAST 后比 1，
--       写成 risk > 0 会做字符串比较，'0' > 0 的语义在不同引擎下不一致。

-- ② L0 金标准关注 IP 下的会员（先单跑 alert 名单看它是否仍活跃）
SELECT id, ip, creator, addtime, remarks
FROM ods_mariadb_2b.ods_a168_alert_ip_setting
ORDER BY addtime DESC;

-- ②b 关注 IP 命中的会员（上一条确认 IP 仍在本窗口出现后再跑）
SELECT DISTINCT b.bet05 AS member_id, 'gold_ip' AS seed_src
FROM ods_mariadb_2b.ods_a168_bet02 b
JOIN ods_mariadb_2b.ods_a168_alert_ip_setting a ON TRIM(a.ip) = TRIM(b.ip)
WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
  AND b.bet02 = '101' AND b.category = '1'
  AND UPPER(TRIM(b.bet38)) = 'N'
ORDER BY member_id;


/* ═══════════════════════════════════════════════════════════════════════════
   §E02c · 分群单位经济学（★ 占成版 —— 补齐上一轮标注的唯一不完整字段）
   ---------------------------------------------------------------------------
   上一轮 §E02 把 commission 恒置 0，并警告「会让净贡献率系统性偏乐观、
   γ* 偏大（赏得过头）」。DX-03 实测发现 ods_a168_dailyreport_member 里
   本来就有五级占成与五级退水：
       bet23~bet27 = LV1~LV5 占成      bet28~bet32 = LV1~LV5 退水
       bet41 = 有效投注   bet13 = 下注金額   bet14 = 派彩金額
       bet15 = 會員退水%數   bet11 = 匯率
   于是 κ（占成率）可以直接算出来，E02 的那个 0 就填实了。
   ---------------------------------------------------------------------------
   ⚠️ 量纲未定：bet23~bet32 是「金额」还是「比率」，列注释没写。
      先跑 §E02c-0 看量级——若与 bet41 同数量级则为金额，若恒在 0~1 则为比率。
      量纲判错会让 κ 差几个数量级，δ*/γ* 全盘失真。**这一步不可跳过。**
   导出：「数据库/E02_segment_econ.csv」
   ═══════════════════════════════════════════════════════════════════════════ */
-- §E02c-0 · 量纲探针（先跑这条，30 秒，决定下面怎么算）
SELECT
  COUNT(*)                                                            AS n_rows,
  AVG(CAST(NULLIF(TRIM(bet41),'') AS DECIMAL(20,4)))                  AS avg_validbet,
  AVG(CAST(NULLIF(TRIM(bet13),'') AS DECIMAL(20,4)))                  AS avg_stake,
  AVG(CAST(NULLIF(TRIM(bet15),'') AS DECIMAL(20,4)))                  AS avg_rebate_pct,
  AVG(CAST(NULLIF(TRIM(bet23),'') AS DECIMAL(20,4)))                  AS avg_lv1_comm,
  MAX(CAST(NULLIF(TRIM(bet23),'') AS DECIMAL(20,4)))                  AS max_lv1_comm,
  AVG(CAST(NULLIF(TRIM(bet28),'') AS DECIMAL(20,4)))                  AS avg_lv1_reb,
  MAX(CAST(NULLIF(TRIM(bet28),'') AS DECIMAL(20,4)))                  AS max_lv1_reb
FROM ods_mariadb_2b.ods_a168_dailyreport_member
WHERE dt >= '2026-03-21' AND dt < '2026-08-07'
  AND bet02 = '101' AND category = '1';
-- 读法：max_lv1_comm ≤ 1 且 avg 在 0.0x 量级 → 比率；
--       与 avg_validbet 同量级（成千上万）→ 金额。下面按「金额」写，
--       若探针判为比率，把 §E02c 里 comm_amt 的算式改为
--         SUM((bet23+..+bet27) * bet41 / bet11)

-- §E02c · 分群单位经济学（占成已补齐）
WITH d AS (
  SELECT bet05 AS member_id, dt,
         CAST(NULLIF(TRIM(bet11),'') AS DECIMAL(20,8)) AS fx,
         CAST(NULLIF(TRIM(bet41),'') AS DECIMAL(20,4)) AS vb_raw,
         CAST(NULLIF(TRIM(bet13),'') AS DECIMAL(20,4)) AS stake_raw,
         CAST(NULLIF(TRIM(bet14),'') AS DECIMAL(20,4)) AS payout_raw,
         COALESCE(CAST(NULLIF(TRIM(bet28),'') AS DECIMAL(20,4)),0)
       + COALESCE(CAST(NULLIF(TRIM(bet29),'') AS DECIMAL(20,4)),0)
       + COALESCE(CAST(NULLIF(TRIM(bet30),'') AS DECIMAL(20,4)),0)
       + COALESCE(CAST(NULLIF(TRIM(bet31),'') AS DECIMAL(20,4)),0)
       + COALESCE(CAST(NULLIF(TRIM(bet32),'') AS DECIMAL(20,4)),0) AS reb_raw,
         COALESCE(CAST(NULLIF(TRIM(bet23),'') AS DECIMAL(20,4)),0)
       + COALESCE(CAST(NULLIF(TRIM(bet24),'') AS DECIMAL(20,4)),0)
       + COALESCE(CAST(NULLIF(TRIM(bet25),'') AS DECIMAL(20,4)),0)
       + COALESCE(CAST(NULLIF(TRIM(bet26),'') AS DECIMAL(20,4)),0)
       + COALESCE(CAST(NULLIF(TRIM(bet27),'') AS DECIMAL(20,4)),0) AS comm_raw
  FROM ods_mariadb_2b.ods_a168_dailyreport_member
  WHERE dt >= '2026-03-21' AND dt < '2026-08-07'
    AND bet02 = '101' AND category = '1'
    AND CAST(NULLIF(TRIM(bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(bet11),'') AS DECIMAL(20,8)) > 0
),
mem AS (
  SELECT member_id,
         SUM(vb_raw / fx)                        AS validbet,
         SUM((payout_raw - stake_raw) / fx)      AS game_pnl,
         SUM(reb_raw  / fx)                      AS rebate,
         SUM(comm_raw / fx)                      AS commission,
         COUNT(DISTINCT DATE_FORMAT(CAST(dt AS DATE),'%Y-%m')) AS n_months,
         COUNT(DISTINCT dt)                      AS n_days
  FROM d GROUP BY member_id
),
mem2 AS (
  SELECT m.*,
         /* 分群：实测退水率三位小数分档 × 洗码量四分位，全部由数据算出 */
         ROUND(m.rebate / NULLIF(m.validbet,0), 3) AS rebate_rate_bkt,
         NTILE(4) OVER (ORDER BY m.validbet)       AS vb_q
  FROM mem m WHERE m.validbet > 0
)
SELECT
  CONCAT('实测退水', CAST(rebate_rate_bkt AS STRING),
         ' · 流水Q', CAST(vb_q AS STRING)) AS segment,
  COUNT(*)             AS n_member,
  SUM(validbet)        AS validbet,
  -SUM(game_pnl)       AS ggr,           -- 庄家赢 = 玩家输
  SUM(rebate)          AS rebate,
  SUM(commission)      AS commission,    -- ★ 不再是 0
  AVG(n_months)        AS tenure_months
FROM mem2
GROUP BY rebate_rate_bkt, vb_q
ORDER BY validbet DESC;
/* ★ 交叉校验（务必做）：本表的 SUM(validbet) 应与 §E02 走 bet02 明细算出的
   洗码量大体一致。dailyreport 是日汇总表，bet02 是注单明细表，两者若差异
   超过 5%，说明 dailyreport 的口径含小費/其他游戏或未剔测试线——
   以 bet02 明细为准，把本表仅用于取 commission 一列并回贴。 */


/* ───────────────────────────────────────────────────────────────────────────
   §C06fix · C-06 同IP对打对（DX-01 校准版，替换原包 C-06）
   ---------------------------------------------------------------------------
   原版 side CTE 用 bet_side IN ('1','B','庄','莊') / ('2','P','闲','閒')，
   与库内实际取值 Banker / Player 完全不匹配 → 两次实测均返回零行。
   本版只改 side CTE 两行判别，其余一字未动。
   注释一律用行注释，不用块注释（见 §DX-02 写法禁令）。
   导出：「数据库/C06_hedge_pairs.csv」
   ─────────────────────────────────────────────────────────────────────────── */
WITH ta AS (
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
rk AS (
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'
),
vd AS (
  SELECT r.*
  FROM rk r
  LEFT JOIN ta t1 ON t1.aid = r.bet18
  LEFT JOIN ta t2 ON t2.aid = r.bet19
  LEFT JOIN ta t3 ON t3.aid = r.bet20
  LEFT JOIN ta t4 ON t4.aid = r.bet21
  LEFT JOIN ta t5 ON t5.aid = r.bet22
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
bs AS (
  SELECT v.bet05 AS member_id, v.eid AS dealer_id, v.ip AS bet_ip,
         v.bet20 AS lv3, v.bet09 AS bet_side, v.dt AS bet_date,
         CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,
         v.bet39 AS table_id,
         CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS stake
  FROM vd v
),
side AS (
  -- 每人每把在该IP的净方向（庄=+ 闲=-，按本金）
  -- ★ DX-01 校准：等值匹配 Banker / Player。
  --   不可用 LIKE '%BANK%'：会误纳 BankerDragonBonus(20.7万笔)、
  --   BankerNatural(6.2万笔) 等边注，那与主线庄闲不构成对冲关系。
  SELECT bet_ip, round_key, member_id,
         SUM(CASE WHEN TRIM(bet_side) = 'Banker' THEN stake
                  WHEN TRIM(bet_side) = 'Player' THEN -stake
                  ELSE 0 END) AS dir_stake
  FROM bs WHERE NULLIF(TRIM(bet_ip),'') IS NOT NULL
  GROUP BY bet_ip, round_key, member_id
  HAVING ABS(SUM(CASE WHEN TRIM(bet_side) = 'Banker' THEN stake
                      WHEN TRIM(bet_side) = 'Player' THEN -stake
                      ELSE 0 END)) > 0
),
pairs AS (
  SELECT a.bet_ip, a.member_id AS m_a, b.member_id AS m_b,
         COUNT(*) AS n_same_round,
         SUM(CASE WHEN a.dir_stake*b.dir_stake < 0 THEN 1 ELSE 0 END) AS n_opposite_round,
         SUM(CASE WHEN a.dir_stake*b.dir_stake < 0
                   AND ABS(ABS(a.dir_stake)-ABS(b.dir_stake))
                       <= 0.1*GREATEST(ABS(a.dir_stake),ABS(b.dir_stake))
                  THEN 1 ELSE 0 END) AS n_hedged
  FROM side a JOIN side b
    ON a.bet_ip=b.bet_ip AND a.round_key=b.round_key
   AND a.member_id < b.member_id
  GROUP BY a.bet_ip, a.member_id, b.member_id
  HAVING COUNT(*) >= 30
)
SELECT bet_ip, m_a, m_b, n_same_round, n_opposite_round,
       n_opposite_round*1.0/n_same_round AS opposite_rate,
       n_hedged*1.0/NULLIF(n_opposite_round,0) AS hedge_coverage
FROM pairs
ORDER BY opposite_rate DESC, n_opposite_round DESC;
-- 若本版仍返回零行，那才是真正的结论（同IP无对打）；
-- 但在此之前先跑下面这条一行探针确认判别已生效：
--   SELECT COUNT(*) FROM ods_mariadb_2b.ods_a168_bet02
--   WHERE dt >= '2026-03-21' AND dt < '2026-08-07' AND bet09 = 'Banker';
-- 该数应约为 4,682 万。若为 0，说明 bet09 有前后空格，把判别改成
--   UPPER(TRIM(bet_side)) = 'BANKER' / 'PLAYER'。


/* ───────────────────────────────────────────────────────────────────────────
   §99 · 大表切分导出模板（T02 / B01 / K01 用得上）
   ★ 绝对不要用 OFFSET 翻页 —— 277 批数据 36.49% 重复的根因就是分页无稳定排序。
   正确做法：按 bet05 的哈希或数值区间切成 N 份，每份独立跑、独立导。
   ─────────────────────────────────────────────────────────────────────────── */
-- 第 k 份（k = 0..9，共 10 份）：在最外层 SELECT 之前的 ord/rk CTE 里加这一行
--   AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) % 10 = 0     -- ← 改 0,1,2,...,9
-- 导出 10 份后在 R 侧 rbind 即可；因为切分键是会员号，各份之间天然不重叠。

-- 切分前先确认每份大小：
SELECT CAST(NULLIF(TRIM(bet05),'') AS BIGINT) % 10 AS bucket,
       COUNT(*) AS n_rows, COUNT(DISTINCT bet05) AS n_member
FROM ods_mariadb_2b.ods_a168_bet02
WHERE dt >= '2026-03-21' AND dt < '2026-08-07'
  AND bet02 = '101' AND category = '1' AND UPPER(TRIM(bet38)) = 'N'
GROUP BY CAST(NULLIF(TRIM(bet05),'') AS BIGINT) % 10
ORDER BY bucket;

/* ───────────────────────────────────────────────────────────────────────────
   §TG · 时间一致性守卫（截止日 2026-08-07）
   ---------------------------------------------------------------------------
   目的：事实表已按窗口截断，但**维度表通常是最新快照**。
   两者时点不一致会造成两类静默错误：
     ① 穿越 —— 会员注册时间晚于其首笔注单 → 「注册至今天数」为负 → 生命周期特征全错
     ② 口径漂移 —— 「该 IP 关联多少会员」算的是今天的关联，不是窗口内的关联
   凡检出晚于截止日的记录，一律先剔除并记数，再进入建模。
   ─────────────────────────────────────────────────────────────────────────── */

-- §TG-01 · 会员注册时间 vs 首笔注单时间（穿越检测）
-- ★★ 会员主表尚未提供，先跑 §DX-03 拿到列名后把 ★★ 替换掉
-- SELECT m.★★会员列★★ AS member_id,
--        m.★★注册时间列★★ AS reg_time,
--        f.first_bet,
--        CASE WHEN CAST(m.★★注册时间列★★ AS DATE) > DATE '2026-08-07'
--               THEN '未来日期'
--             WHEN CAST(m.★★注册时间列★★ AS DATETIME) > f.first_bet
--               THEN '注册晚于首注单（穿越）'
--             ELSE 'OK' END AS verdict
-- FROM ods_mariadb_2b.★★会员主表★★ m
-- LEFT JOIN (SELECT bet05, MIN(CAST(NULLIF(TRIM(bet08),'') AS DATETIME)) AS first_bet
--            FROM ods_mariadb_2b.ods_a168_bet02
--            WHERE dt >= '2026-03-21' AND dt < '2026-08-07' AND bet02='101'
--            GROUP BY bet05) f ON f.bet05 = m.★★会员列★★
-- ORDER BY verdict, member_id;

-- §TG-03 · 关注 IP 名单的登记时间是否越过截止日（可直接跑，列名已实测）
SELECT id, ip, creator, addtime, remarks,
       CASE WHEN CAST(SUBSTR(addtime,1,10) AS DATE) > DATE '2026-08-07'
            THEN '🔴 未来日期，应从 L0 金标准剔除' ELSE '🟢 OK' END AS verdict
FROM ods_mariadb_2b.ods_a168_alert_ip_setting
ORDER BY addtime DESC;

-- §TG-05 · 事实表自身的越界自检（应返回 0 行；非 0 即窗口过滤有漏）
SELECT COUNT(*) AS n_future_rows,
       MIN(dt) AS min_dt, MAX(dt) AS max_dt
FROM ods_mariadb_2b.ods_a168_bet02
WHERE dt >= DATE '2026-08-07';


/* ───────────────────────────────────────────────────────────────────────────
   §DX-04 · 玩法 × 会员 的子分类底料（@sec-subclass 的定量输入）
   输出：bet09 玩法 · 注单数 · 会员数 · 投注额 · 玩家盈亏 · 实测庄家 hold%
   用途：验证各玩法的实测庄家优势与理论值是否一致；偏离大的玩法优先查
   导出：「数据库/DX04_bet09_profile.csv」
   ─────────────────────────────────────────────────────────────────────────── */
WITH ranked AS (
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'
),
o AS (
  SELECT r.bet09 AS bet_side, r.bet05 AS member_id,
         CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4))
           / NULLIF(CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)),0) AS stake,
         (CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4))
          - CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)))
           / NULLIF(CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)),0) AS game_pnl
  FROM ranked r
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
)
SELECT bet_side,
       COUNT(*)                                   AS n_orders,
       COUNT(DISTINCT member_id)                  AS n_member,
       SUM(stake)                                 AS stake_total,
       SUM(game_pnl)                              AS player_pnl,
       -SUM(game_pnl) / NULLIF(SUM(stake),0)      AS house_hold_pct,
       SUM(CASE WHEN game_pnl > 0 THEN 1 ELSE 0 END) * 1.0
         / NULLIF(SUM(CASE WHEN game_pnl <> 0 THEN 1 ELSE 0 END),0) AS win_rate_base,
       AVG(stake)                                 AS avg_stake,
       STDDEV_SAMP(stake) / NULLIF(AVG(stake),0)  AS stake_cv
FROM o
GROUP BY bet_side
ORDER BY n_orders DESC;
-- 读法：house_hold_pct 应接近该玩法的理论庄家优势。
--   明显低于理论值的玩法 = 该玩法上有人在赢庄家 → 优先查；
--   win_rate_base 就是 R-03 的 Z-score 基准，务必按玩法取用，不可混算。

/* ───────────────────────────────────────────────────────────────────────────
   §DX-05 · 产品全景：本报告只覆盖了多大一块？
   ---------------------------------------------------------------------------
   全文所有 SQL 都带 bet02 = '101'（百家乐）。这是主动的产品口径选择，
   但必须知道它在全平台里占多少——否则漏损总量会被低估、净贡献率会被算偏
   （退水与占成按全产品结算，而分子只算了百家乐）。
   本查询给出各产品的注单量、投注额、玩家盈亏、庄家 hold%，一次看清占比。
   导出：「数据库/DX05_product_panorama.csv」
   ─────────────────────────────────────────────────────────────────────────── */
WITH test_agents AS (
  SELECT age001 AS agent_id FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
ranked AS (
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
),
o AS (
  SELECT r.bet02 AS product_code, r.bet05 AS member_id, r.eid AS dealer_id,
         CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4))
           / NULLIF(CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)),0) AS stake,
         COALESCE(CAST(NULLIF(TRIM(r.validbet),'') AS DECIMAL(20,4)),
                  CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)))
           / NULLIF(CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)),0) AS validbet,
         (CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4))
          - CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)))
           / NULLIF(CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)),0) AS game_pnl,
         CAST(NULLIF(TRIM(r.bet16),'') AS DECIMAL(20,4))
           / NULLIF(CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)),0) AS rebate
  FROM ranked r
  LEFT JOIN test_agents t1 ON t1.agent_id = r.bet18
  LEFT JOIN test_agents t2 ON t2.agent_id = r.bet19
  LEFT JOIN test_agents t3 ON t3.agent_id = r.bet20
  LEFT JOIN test_agents t4 ON t4.agent_id = r.bet21
  LEFT JOIN test_agents t5 ON t5.agent_id = r.bet22
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND COALESCE(t1.agent_id,t2.agent_id,t3.agent_id,t4.agent_id,t5.agent_id) IS NULL
)
SELECT product_code,
       CASE WHEN product_code = '101' THEN '百家乐（本报告口径）' ELSE '其他产品' END AS scope,
       COUNT(*)                                  AS n_orders,
       COUNT(DISTINCT member_id)                 AS n_member,
       COUNT(DISTINCT dealer_id)                 AS n_dealer,
       SUM(stake)                                AS stake_total,
       SUM(validbet)                             AS validbet_total,
       SUM(game_pnl)                             AS player_pnl,
       -SUM(game_pnl)                            AS ggr,
       -SUM(game_pnl) / NULLIF(SUM(stake),0)     AS house_hold_pct,
       SUM(rebate)                               AS rebate_total,
       SUM(rebate) / NULLIF(SUM(validbet),0)     AS rebate_rate,
       COUNT(*) * 1.0 / SUM(COUNT(*)) OVER ()    AS order_share,
       SUM(stake) / SUM(SUM(stake)) OVER ()      AS stake_share
FROM o
GROUP BY product_code
ORDER BY n_orders DESC;
/* 读法（三个关键比值）：
   ① 百家乐的 order_share / stake_share —— 本报告覆盖面。低于 70% 则所有金额结论
      必须显式标注「百家乐口径」，不得当全平台数字引用。
   ② 各产品的 house_hold_pct —— 明显低于理论庄家优势者，说明该产品上有人在赢庄家，
      应优先把本方案的三条风控线移植过去。
   ③ 各产品的 rebate_rate —— 退水率显著高于百家乐的产品，是打水套利的下一个战场。
      @sec-econ 的 κ 与 ρ 必须按全产品重算，否则净贡献率系统性偏乐观。 */

/* ───────────────────────────────────────────────────────────────────────────
   §00c · 表行数复核（一次给全，供报告的「核心表点货单」现算行数）
   ---------------------------------------------------------------------------
   报告里的「行数量级」原本是早期测试期的静态记忆。跑这条导出后，
   点货单会自动改为「实测」并标注；不跑则显式标注「历史记录·未复核」。
   导出：「数据库/V_table_counts.csv」（两列：表名 / 行数）
   注：information_schema.tables 的 TABLE_ROWS 在 StarRocks 上是估算值，
       所以这里用 COUNT(*) 精确统计。表多时耗时以分钟计，属正常。
   ─────────────────────────────────────────────────────────────────────────── */
SELECT 'ods_a168_bet02'              AS 表名, COUNT(*) AS 行数 FROM ods_mariadb_2b.ods_a168_bet02
UNION ALL SELECT 'ods_a168_bet01',              COUNT(*) FROM ods_mariadb_2b.ods_a168_bet01
UNION ALL SELECT 'ods_a168_game_info',          COUNT(*) FROM ods_mariadb_2b.ods_a168_game_info
UNION ALL SELECT 'ods_a168_agent',              COUNT(*) FROM ods_mariadb_2b.ods_a168_agent
UNION ALL SELECT 'ods_a168_member_dtl',         COUNT(*) FROM ods_mariadb_2b.ods_a168_member_dtl
UNION ALL SELECT 'ods_a168_dailyreport_member', COUNT(*) FROM ods_mariadb_2b.ods_a168_dailyreport_member
UNION ALL SELECT 'ods_a168_alert_ip_setting',   COUNT(*) FROM ods_mariadb_2b.ods_a168_alert_ip_setting
UNION ALL SELECT 'ods_a168_employee',           COUNT(*) FROM ods_mariadb_2b.ods_a168_employee
UNION ALL SELECT 'ods_a168_game_No',            COUNT(*) FROM ods_mariadb_2b.ods_a168_game_No
ORDER BY 行数 DESC;
/* 若某张表名在本库不存在，删掉对应那一行 UNION 再跑；
   报告侧对缺失的表名会自动落回「历史记录·未复核」，不会报错。 */

/* ───────────────────────────────────────────────────────────────────────────
   §R03b · R03b_player_dealer_daily.csv —— R-03 的**日粒度**版本
   ---------------------------------------------------------------------------
   为什么要它：R-03 是全窗口聚合（一个玩家×荷官一行），没有日期维度，
   因此做不了「需求原规则 vs Z 轨」的时序对照。本查询与 §R03 口径**一字不动**
   （局级去重、玩法基准、排除 Tip），只把聚合键从
       GROUP BY member_id, dealer_id
   改为
       GROUP BY member_id, dealer_id, bet_date
   输出：bet_date, uid, dealer_id, stake_amount, profit_amount, win_rate,
         n_related_orders, n_rounds_eff, p_base_mix, z_score
   ─────────────────────────────────────────────────────────────────────────── */
WITH ranked AS (
  SELECT b.*, ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'
    AND b.bet02 = '101' AND b.category = '1'
),
base AS (
  SELECT r.bet05 AS member_id, r.eid AS dealer_id, r.dt AS bet_date,
         r.bet09 AS bet_side,
         CONCAT_WS('|', r.bet03, r.bet04, r.bet39) AS round_key,
         CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) AS fx,
         CAST(NULLIF(TRIM(r.bet13),'') AS DECIMAL(20,4)) AS stake_raw,
         CAST(NULLIF(TRIM(r.bet14),'') AS DECIMAL(20,4)) AS payout_raw,
         CAST(NULLIF(TRIM(r.bet17),'') AS DECIMAL(20,4)) AS net_raw
  FROM ranked r
  WHERE r.rn = 1 AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND NULLIF(TRIM(r.eid),'') IS NOT NULL
    AND UPPER(TRIM(r.bet09)) NOT LIKE 'TIP\_1\_%'
),
ord AS (
  SELECT member_id, dealer_id, bet_date, bet_side, round_key,
         stake_raw / fx                AS stake,
         (payout_raw - stake_raw) / fx AS game_pnl,
         net_raw / fx                  AS net_pnl
  FROM base
),
side_base AS (
  SELECT bet_side,
         SUM(CASE WHEN game_pnl > 0 THEN 1 ELSE 0 END) * 1.0
           / NULLIF(SUM(CASE WHEN game_pnl <> 0 THEN 1 ELSE 0 END), 0) AS p_base
  FROM ord GROUP BY bet_side
),
pr AS (   -- 局级去重：同一物理局折成一局，避免 Z-score 被 sqrt(k) 放大
  SELECT member_id, dealer_id, bet_date, round_key,
         SUM(stake) AS stake, SUM(game_pnl) AS game_pnl, SUM(net_pnl) AS net_pnl,
         COUNT(*) AS n_orders_in_round, MAX(bet_side) AS main_side
  FROM ord GROUP BY member_id, dealer_id, bet_date, round_key
)
SELECT p.bet_date, p.member_id AS uid, p.dealer_id,
       SUM(p.stake)                                        AS stake_amount,
       SUM(p.game_pnl)                                     AS profit_amount,
       SUM(p.net_pnl)                                      AS net_pnl,
       SUM(CASE WHEN p.game_pnl > 0 THEN 1 ELSE 0 END) * 1.0
         / NULLIF(SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END), 0) AS win_rate,
       SUM(p.n_orders_in_round)                            AS n_related_orders,
       COUNT(*)                                            AS n_rounds_eff,
       AVG(COALESCE(s.p_base, 0.5))                        AS p_base_mix,
       (SUM(CASE WHEN p.game_pnl > 0 THEN 1 ELSE 0 END)
        - SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END) * AVG(COALESCE(s.p_base,0.5)))
         / NULLIF(SQRT(SUM(CASE WHEN p.game_pnl <> 0 THEN 1 ELSE 0 END)
                       * AVG(COALESCE(s.p_base,0.5))
                       * (1 - AVG(COALESCE(s.p_base,0.5)))), 0)        AS z_score
FROM pr p
LEFT JOIN side_base s ON s.bet_side = p.main_side
GROUP BY p.bet_date, p.member_id, p.dealer_id
ORDER BY p.bet_date, z_score DESC;
/* ⚠️ 日粒度下单日有效局数天然偏少，Z-score 噪声比全窗口版大得多。
   本导出**只用于时序对照与趋势观察**，处置判定一律仍以 §R03 全窗口版为准。 */
