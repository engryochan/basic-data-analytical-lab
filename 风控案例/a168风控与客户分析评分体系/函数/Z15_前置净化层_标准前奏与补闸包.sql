/* ╔═══════════════════════════════════════════════════════════════════════════╗
   ║  §Z-15 · 前置净化层 · 标准前奏与补闸包                                      ║
   ║  a168 风控与客户分层评分体系 · 哨兵值与脏值治理                              ║
   ╠═══════════════════════════════════════════════════════════════════════════╣
   ║  立档：2026-08-13                                                          ║
   ║  依据：§Z-13 全包审计（154 条查询逐条核实）                                  ║
   ║  被审本：a168_取数与核验_SQL总包_v2斧正版.sql                                ║
   ║          行数 7,849 · CRLF · UTF-8(无BOM)                                  ║
   ║          MD5(原样)   30d9db43d5e641538c1e9eeb00527e2b                      ║
   ║          MD5(LF归一) ed7a6b1b5c338b79e2ac9e8b9bf0e3b9                      ║
   ║          字节差 7,849 = 行数 → 纯换行制式差异，非版本冲突                    ║
   ╠═══════════════════════════════════════════════════════════════════════════╣
   ║  ⚠ 本包**不改动源文件一字**。所载者为：                                     ║
   ║    ① 标准前奏 CTE（§Z-15A）—— 供缺闸各条按名替换其自造前奏                  ║
   ║    ② 影响量化探针（§Z-15B）—— 先量后改，不量不改                            ║
   ║    ③ 逐条补闸最小 diff（§Z-15C）—— 只列须加的行，不重排任何既有行           ║
   ║    ④ 验收断言（§Z-15D）—— 改毕自证，预期读数写死                            ║
   ╚═══════════════════════════════════════════════════════════════════════════╝


   ═══ 铁律（本包据以裁定，逐条有出处）═══════════════════════════════════════

   【铁律一 · 净化先于聚合】
     任何聚合（SUM/COUNT/AVG/STDDEV/GROUP BY）与任何推算（比率、Z-score、
     熵、分位、回归）之前，其输入必须已剔净：
       ① 公司测试线代理之注单        age022 = '1'（214 条，跨五级）
       ② 同注单号之旧版本            ROW_NUMBER(...) = 1
       ③ 非一般注单                  category <> '1'
       ④ 重对注单                    UPPER(TRIM(bet38)) <> 'N'
       ⑤ 空串 / 空白 / 不可转型值    NULLIF(TRIM(x),'') + CAST
       ⑥ 荷官哨兵                    TRIM(eid) IN ('-1','0')
     唯一豁免：全局表一览与「哨兵值占比」统计本身（§Z-01~§Z-11）——
     那正是用来量哨兵的，剔了就量不着。

   【铁律二 · 标记不等于剔除】
     §R03 / §R03b / §R03inv 只以 is_sentinel_dealer 列**标记**哨兵而不剔除，
     此为**设计意图**（留 L0 事实层备查），不是缺陷。
     但其成立以下游必分层为前提。契约两端：
       · 上游（本包）：必须保证该列存在且取值正确；
       · 下游（报告）：装载处必须一次剔清，并以 stopifnot 断言。
     《精要商业报告》已于 load-core 处立 L0/L1 分层并加断言 —— 契约完整。
     ★ 但凡新增下游消费方，须同时补此断言，否则契约在该处断裂。

   【铁律三 · 一览之名不得成为通道】
     凡产出**分析用交付件**者，一律不得以「一览/普查」为由豁免。
     豁免只给「无交付件」或「Z 系列清单类交付件」。

   ═══ 审计结论（§Z-13 实测，2026-08-13）═════════════════════════════════════
     查询语句总数            154 条
     产出交付件者             79 条
     ✅ 四闸齐备               31 条
     ⛔ 交付件缺闸             14 条   ← 本包 §Z-15C 逐条补
     ⛔ 屏幕核验缺闸            6 条   ← 次级，不阻断取数
     豁免·元数据               20 条
     豁免·一览/哨兵占比        14 条
     旁路·未触注单主表          65 条

     不可见字符与乱码全文扫描：
       U+FFFD 替换符（乱码铁证）      0 行  ✅
       U+00A0 / U+200B / U+FEFF      0 行  ✅
       制表符 TAB                     0 行  ✅
       U+3000 全角空格                1 行  ⚠ 建议清
       全角标点混入**代码区**         13 行  ⚠ 须逐行确认（注释区不计）
     判读：**全文无乱码**。全角标点 13 处集中于 §TL 系列与注释边界，
           须逐行确认其是否落在字符串字面量或标识符内；落在注释内者无碍。

   ═══════════════════════════════════════════════════════════════════════════ */


/* ═══════════════════════════════════════════════════════════════════════════
   §Z-15A · 标准前奏 CTE（唯一净化口径 · 全包共用）
   ---------------------------------------------------------------------------
   用法：把缺闸各条自造的 ranked / base 前奏，整段替换为本前奏，
         其后只改一处 —— 把下游 FROM 指向 bs_clean。
   ★ 本前奏与 §S-01 / §T02 / §K01 等 31 条合规语句的口径**逐字相同**，
     故替换后各条之间可横向对账（同一会员在各表的 stake 必然相等）。
   ★ 列表按需增删，但**四闸与六项净化不可删**。
   ═══════════════════════════════════════════════════════════════════════════ */
-- ▸ 导出：不需要 —— §Z-15A 标准前奏模板（供替换用，本身不单独运行）。
WITH ta AS (                                    -- ① 公司测试线代理（214 条，跨五级）
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent
  WHERE age022 = '1'
),
rk AS (                                         -- ② 同注单号取最新版本（需求 §3.2）
  SELECT b.bet01, b.updatetime, b.sync_time, b.dt,
         b.bet02, b.bet03, b.bet04, b.bet05, b.bet08, b.bet09,
         b.bet11, b.bet13, b.bet14, b.bet16, b.bet17,
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,
         b.bet38, b.bet39, b.category, b.eid, b.ip, b.validbet,
         ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07'   -- 分区剪枝：谓词写在最内层
    AND b.bet02 = '101'
),
vd AS (                                         -- ③④⑤ 四闸 + 空串净化
  SELECT r.*
  FROM rk r
  /* StarRocks 不支持 EXISTS 配多列 IN，故测试线剔除写作五路 LEFT JOIN */
  LEFT JOIN ta t1 ON t1.aid = r.bet18
  LEFT JOIN ta t2 ON t2.aid = r.bet19
  LEFT JOIN ta t3 ON t3.aid = r.bet20
  LEFT JOIN ta t4 ON t4.aid = r.bet21
  LEFT JOIN ta t5 ON t5.aid = r.bet22
  WHERE r.rn = 1
    AND r.category = '1'
    AND UPPER(TRIM(r.bet38)) = 'N'
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
),
bs_clean AS (                                   -- ⑥ 金额正名 + 哨兵标记（不剔，见铁律二）
  SELECT v.bet05 AS member_id,
         v.eid   AS dealer_id,
         CASE WHEN NULLIF(TRIM(v.eid),'') IS NULL
                OR TRIM(v.eid) IN ('-1','0') THEN 1 ELSE 0 END AS is_sentinel_dealer,
         v.ip    AS bet_ip,
         v.bet20 AS lv3,
         v.bet09 AS bet_side,
         v.dt    AS bet_date,
         v.bet39 AS table_id,
         v.bet03 AS shoe_id,
         CAST(NULLIF(TRIM(v.bet04),'') AS INT) AS round_no,
         CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,
         CAST(NULLIF(TRIM(v.bet08),'') AS DATETIME) AS t_bet,
         CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4))
           / NULLIF(CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)),0) AS stake,
         CAST(NULLIF(TRIM(v.validbet),'') AS DECIMAL(20,4))
           / NULLIF(CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)),0) AS valid_bet,
         (CAST(NULLIF(TRIM(v.bet14),'') AS DECIMAL(20,4))
          - CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4)))
           / NULLIF(CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)),0) AS game_pnl,
         CAST(NULLIF(TRIM(v.bet16),'') AS DECIMAL(20,4))
           / NULLIF(CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)),0) AS rebate,
         CAST(NULLIF(TRIM(v.bet17),'') AS DECIMAL(20,4))
           / NULLIF(CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)),0) AS net_pnl
  FROM vd v
)
SELECT COUNT(*) AS n_rows_clean FROM bs_clean;


/* ═══════════════════════════════════════════════════════════════════════════
   §Z-15B · 影响量化探针（★ 先量后改，不量不改）
   ---------------------------------------------------------------------------
   缘由：14 条缺闸语句是否须重跑，取决于测试线在其口径下占多少。
         占比若为 0.00x%，可记录在案、下轮统一处置；
         占比若逾 0.5%，则相关结论（尤其荷官八维）须**立即重跑**。
   本条一跑即知，代价约一次全窗扫描。
   ═══════════════════════════════════════════════════════════════════════════ */
-- ▸ 导出：需要 —— 存为「数据库/Z15B_testline_impact.csv」（§Z-15B 测试线影响量化）。
WITH ta AS (
  SELECT DISTINCT age001 AS aid
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'
),
rk AS (
  SELECT b.bet01, b.updatetime, b.sync_time, b.dt,
         b.bet05, b.bet11, b.bet13, b.bet14, b.bet38, b.bet39, b.eid,
         b.bet18, b.bet19, b.bet20, b.bet21, b.bet22, b.category, b.validbet,
         ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 b
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'
),
tagged AS (
  SELECT r.*,
         CASE WHEN COALESCE(t1.aid,t2.aid,t3.aid,t4.aid,t5.aid) IS NULL
              THEN 0 ELSE 1 END AS is_testline,
         CASE WHEN NULLIF(TRIM(r.eid),'') IS NULL
                OR TRIM(r.eid) IN ('-1','0') THEN 1 ELSE 0 END AS is_sentinel_dealer
  FROM rk r
  LEFT JOIN ta t1 ON t1.aid = r.bet18
  LEFT JOIN ta t2 ON t2.aid = r.bet19
  LEFT JOIN ta t3 ON t3.aid = r.bet20
  LEFT JOIN ta t4 ON t4.aid = r.bet21
  LEFT JOIN ta t5 ON t5.aid = r.bet22
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'
)
SELECT
  '全窗百家乐·去重后'                                    AS 口径,
  COUNT(*)                                              AS n_orders,
  SUM(is_testline)                                      AS n_testline,
  SUM(is_testline) * 1.0 / COUNT(*)                     AS testline_share,
  COUNT(DISTINCT bet05)                                 AS n_member,
  COUNT(DISTINCT CASE WHEN is_testline=1 THEN bet05 END) AS n_member_testline,
  SUM(is_sentinel_dealer)                               AS n_sentinel_dealer,
  SUM(is_sentinel_dealer) * 1.0 / COUNT(*)              AS sentinel_dealer_share,
  SUM(CASE WHEN is_testline=1 AND is_sentinel_dealer=1 THEN 1 ELSE 0 END) AS n_both,
  SUM(CAST(NULLIF(TRIM(validbet),'') AS DECIMAL(20,4))
      / NULLIF(CAST(NULLIF(TRIM(bet11),'') AS DECIMAL(20,8)),0))          AS validbet_all,
  SUM(CASE WHEN is_testline=1 THEN
      CAST(NULLIF(TRIM(validbet),'') AS DECIMAL(20,4))
      / NULLIF(CAST(NULLIF(TRIM(bet11),'') AS DECIMAL(20,8)),0) END)      AS validbet_testline,
  COUNT(DISTINCT CASE WHEN is_testline=1 THEN eid END)                    AS n_dealer_touched
FROM tagged;
/* 判读闸（改动与否之裁定，写死，不容临场解释）：
     testline_share < 0.001            → 记录在案，可随下轮统一处置
     0.001 ≤ testline_share < 0.005    → 荷官/对打类须重跑，其余记录在案
     testline_share ≥ 0.005            → 全部 14 条**立即重跑**，旧 CSV 一律作废
   ★ n_dealer_touched 另有独立分量：测试线只要碰过某荷官，
     该荷官的「客群广度」「对打局占比」两维即被污染，与注单占比高低无关。 */


/* ═══════════════════════════════════════════════════════════════════════════
   §Z-15C · 逐条补闸最小 diff（只列须加的行，不重排任何既有行）
   ---------------------------------------------------------------------------
   ★ 一条一改，改毕即跑 §Z-15D 之对应断言。禁批量改后一次验。
   ═══════════════════════════════════════════════════════════════════════════ */

/* ── C-1 · §R03 家族（四条，同一处补法）· 优先级 P0-最高 ──────────────────
   涉：§R03 (行3341)  §R03b (行4982)  §R03chk (行3523)  §R03inv (行3584)
   病：四条皆缺测试线剔除。**§R03b 是荷官八维之唯一底表**，
       故荷官雷达之「客群广度」「对打局占比」「異常对关联」三维全部受累。
   补：在各条 ranked 之后、base 之前插入 ta，并在 base 的 WHERE 末尾加一行。

   ① 在 WITH 之首插入：
        ta AS (SELECT DISTINCT age001 AS aid
               FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'),
   ② ranked 的 SELECT 列表补五列：
        b.bet18, b.bet19, b.bet20, b.bet21, b.bet22,
   ③ base 的 FROM ranked r 之后补五路：
        LEFT JOIN ta t1 ON t1.aid = r.bet18
        LEFT JOIN ta t2 ON t2.aid = r.bet19
        LEFT JOIN ta t3 ON t3.aid = r.bet20
        LEFT JOIN ta t4 ON t4.aid = r.bet21
        LEFT JOIN ta t5 ON t5.aid = r.bet22
   ④ base 的 WHERE 末尾补一行：
        AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL
   ⚠ §R03b 之 is_sentinel_dealer 列**保留不动**（铁律二），只补测试线。
──────────────────────────────────────────────────────────────────────────── */

/* ── C-2 · §R02 (行3132) · 优先级 P0 ──────────────────────────────────────
   病：缺测试线 **且缺版本去重**。后者更重——同注单号多版本会令
       same_rounds 与 rounds_i 同时虚增，而 Jaccard 之分子分母虚增比例不同，
       Lift 遂系统性偏移，方向不定。
   补：mr 之 FROM ods_a168_bet02 改为取自 §Z-15A 之 bs_clean，
       或按 C-1 之四步就地补齐（本条无 ranked，须整段加）。
   ★ 本条改后须重跑 §R02-1a 桌台体量，分批切点可能变。
──────────────────────────────────────────────────────────────────────────── */

/* ── C-3 · §DX-04 (行4810) · 优先级 P1 ────────────────────────────────────
   病：缺测试线。三闸俱在（rn=1 / category / bet38）。
   影响：玩法层 hold% 实测值被测试线污染；因测试线多为小额高频，
         其对 hold% 之拉动方向不定，不可假定「量小无碍」。
   补：按 C-1 之四步。
──────────────────────────────────────────────────────────────────────────── */

/* ── C-4 · §A-01 (行2555) / §V-01 (行2573) · 优先级 P1 ────────────────────
   病：四闸全缺。A-01 以 LEFT JOIN 直取原表计数，
       n_orders 含旧版本重复计（去重率实测 0.74%，故约高估 0.74%）。
   补：JOIN 的右侧由 ods_a168_bet02 改为 §Z-15A 之 bs_clean。
   ★ V-01 之用途为「game_log.ip 系网关」之存档证据，
     其结论对哨兵不敏感；补闸只为口径一致，不改结论。
──────────────────────────────────────────────────────────────────────────── */

/* ── C-5 · §P0C 家族（行6587 / 6627 / 6665 / 6789）· 优先级 P0 ────────────
   病：四条皆四闸全缺，且皆为**因果推断类**（同日泄漏检验、标记时点定位、
       LabelB 骨架、安慰剂检验）。
   ★★ 因果类对污染最敏感：测试线之注单行为与真人不同分布，
      混入即令处置组与对照组的**可比性假设**失效——
      这不是精度问题，是**识别策略失效**，结论不可用而非不精确。
   补：四条之 FROM ods_a168_bet02 一律改取 bs_clean；
       其取自 dailyreport_member 之 risk 侧不受影响，不动。
──────────────────────────────────────────────────────────────────────────── */

/* ── C-6 · §TL-11 (行7519) / §TL-14 (行3922) · 优先级 P2 ──────────────────
   病：缺测试线等闸。二条主料源为 log_mem_change / bet_limit_default，
       与注单表为旁路关联。
   补：其关联注单侧改取 bs_clean 即可；主料源侧另须确认
       member_id 是否含测试线会员（见 §Z-15D 之 D-4 断言）。
──────────────────────────────────────────────────────────────────────────── */


/* ═══════════════════════════════════════════════════════════════════════════
   §Z-15D · 验收断言（改毕自证 · 预期读数写死，不容临场解释）
   ═══════════════════════════════════════════════════════════════════════════ */

/* ── D-1 · 测试线零残留断言（改后每条必跑）────────────────────────────────
   预期：n_leak = 0。非零即补闸未生效。 */
-- ▸ 导出：不需要 —— §Z-15D-1 屏幕断言（测试线零残留）。
WITH ta AS (SELECT DISTINCT age001 AS aid
            FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1')
SELECT COUNT(*) AS n_leak
FROM <改后之交付件对应查询> q
JOIN ta ON ta.aid IN (q.lv3);      -- 按该条实际保留的代理线列调整

/* ── D-2 · 版本去重断言 ───────────────────────────────────────────────────
   预期：n_dup = 0（每个 bet01 只应出现一次）。 */
-- ▸ 导出：不需要 —— §Z-15D-2 屏幕断言（版本去重）。
SELECT COUNT(*) AS n_dup FROM (
  SELECT bet01, COUNT(*) AS c
  FROM <改后之最内层去重 CTE>
  GROUP BY bet01 HAVING COUNT(*) > 1) t;

/* ── D-3 · 横向对账断言（★ 本包最有力的一条）──────────────────────────────
   同一会员在任意两份交付件中的 stake / valid_bet 必然相等——
   若不等，即证二者口径未统一，补闸未竟全功。
   预期：n_mismatch = 0（容差 1e-6，浮点舍入之内）。 */
-- ▸ 导出：不需要 —— §Z-15D-3 屏幕断言（跨交付件横向对账）。
SELECT COUNT(*) AS n_mismatch
FROM (
  SELECT a.member_id, a.validbet AS v_k01, b.流水贡献 AS v_s01
  FROM <K01_risk_feature_matrix> a
  JOIN <S01_player_score> b ON b.member_id = a.member_id
) t
WHERE ABS(v_k01 - v_s01) > 1e-6;
/* ⚠ 本断言现阶段**预期不为 0** —— 因 §17.2 之「流水贡献」定义为
   validbet × (1 − hedge_rate)，与 K01 之 validbet 本就不同。
   故本断言须待两侧口径统一后方可启用；在此之前作为**已知差异**登记，
   不得当作补闸失败。详见《能力值口径解读 v2》之桥接层一节。 */

/* ── D-4 · 哨兵值定性复核（承 §Z-10）─────────────────────────────────────
   预期：eid ∈ {'-1','0',''} 之占比与 §Z-07 普查读数一致；
         不一致即说明上游分层在某处失效。 */
-- ▸ 导出：需要 —— 存为「数据库/Z15D_sentinel_recheck.csv」（§Z-15D-4 哨兵复核）。
SELECT
  CASE WHEN NULLIF(TRIM(eid),'') IS NULL THEN '空串/NULL'
       WHEN TRIM(eid) = '-1'             THEN '-1'
       WHEN TRIM(eid) = '0'              THEN '0'
       ELSE '正常工号' END                          AS eid_class,
  COUNT(*)                                          AS n_orders,
  COUNT(*) * 1.0 / SUM(COUNT(*)) OVER ()            AS share,
  COUNT(DISTINCT bet05)                             AS n_member,
  COUNT(DISTINCT bet39)                             AS n_table
FROM ods_mariadb_2b.ods_a168_bet02
WHERE dt >= '2026-03-21' AND dt < '2026-08-07' AND bet02 = '101'
GROUP BY 1
ORDER BY n_orders DESC;


/* ═══════════════════════════════════════════════════════════════════════════
   §Z-15E · 全角标点与不可见字符清理清单（13 + 1 处）
   ---------------------------------------------------------------------------
   全文扫描结论：**无乱码**（U+FFFD 零命中）。以下为形近风险，须逐行确认：
     · 全角空格 U+3000        1 行
     · 全角标点混入代码区     13 行（首现：898、3736、4791、4897、7788…）
   判读规则：
     ① 落在**注释区**者，无碍，不动 —— 行文用全角是应当的；
     ② 落在**字符串字面量**内者，须与库内实际值比对，
        库内为半角而此处写全角，即为静默零行之根源（同 §C-06 判庄闲之旧病）；
     ③ 落在**标识符或运算符**位置者，必致语法错，跑即报错，不会静默。
   处置：只清 ② 类。清前后各跑一次该条，行数须一致。
   ═══════════════════════════════════════════════════════════════════════════ */
-- ▸ 导出：不需要 —— §Z-15E 屏幕核对（形近字符逐行确认，须人工判读）。


/* ═══════════════════════════════════════════════════════════════════════════
   变更记录
   ---------------------------------------------------------------------------
   2026-08-13  v1  立档。依 §Z-13 全包 154 条查询逐条审计结果编成。
                   本包不改源文件；补闸落地后，须于源文件头部
                   「常数集中登记」下方新增一行记明本包版本与落地日期，
                   并重算源文件之六元组。
   ═══════════════════════════════════════════════════════════════════════════ */
