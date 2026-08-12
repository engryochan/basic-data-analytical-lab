/* ============================================================================
   项目代号：a168
   文件名  ：a168_口径补充_去重有效单与盈亏胜率_SQL_v1.sql
   性质    ：独立新增文件。本文件不修改、不覆盖、不引用既有
             `a168_取数与核验_SQL总包.sql` 的任何语句与编号。
   方言    ：StarRocks（Superset SQL Lab，只读）
   数据源  ：ods_mariadb_2b.ods_a168_bet02
   ----------------------------------------------------------------------------
   【固定口径（§2.1 / §2.2 / §3.3 / §3.4）】
     游戏范围  ：bet02 = '101'
     时间字段  ：bet08          玩家ID：bet05          IP：ip
     物理局键  ：bet03 + bet04 + bet39（'|' 分隔，全部显式 CAST 为 VARCHAR）
     版本去重  ：同一 bet01 取 updatetime DESC, sync_time DESC, dt DESC 之首行
     有效订单  ：category = 1 且 UPPER(TRIM(bet38)) = 'N' 且 bet05 > 0
                 且 bet11 > 0 且 bet08 有效
     金额口径  ：投注金额 = bet13 / bet11
                 游戏盈利 = (bet14 - bet13) / bet11
                 返水     = bet16 / bet11
                 净盈利   = bet17 / bet11
     盈亏判定  ：窗口内 SUM(净盈利) > 0 判为盈利账户
     胜率口径  ：按「玩家物理局」聚合后判定，和局不入分母
                 胜率 = 胜局数 / (胜局数 + 负局数)

   【执行顺序的口径声明】
     先去重、后过滤。即：先在 bet01 全部版本中取最新一版，再对该最新版施加
     category / bet38 / bet05 / bet11 / bet08 五项有效性条件。若反序执行
     （先过滤后去重），会把「最新版已失效、旧版仍有效」的订单错误保留，
     §C-01 漏斗表可直接量化二者差额。bet02 = '101' 属游戏范围而非有效性条件，
     置于去重之前，以便分区裁剪。

   【类型处理】
     bet05 / bet11 / bet13 / bet14 / bet16 / bet17 / category 若以 varchar 存储，
     本文件已全部显式 CAST。若 bet05 存在非纯数字取值，CAST(... AS BIGINT) 将
     产生 NULL 并被 `> 0` 过滤剔除，该剔除量已在 §C-01 漏斗中单列，可核对。

   【缺失与待确认（按 文件 / SQL 编号 / 受影响产出 列示）】
     缺-01 局开始下注时间与封盘时间表：表名与字段名未确认。
           受影响 SQL：本文件全部语句均未实现「尾秒」切片。
           受影响产出：尾秒下注的胜率与游戏盈利（§3.3 / §3.4 的尾秒专项）。
           说明：尾秒定义依赖封盘时刻，缺此表则无法界定，本文件一律输出
                 全体订单口径，不以任何替代物冒充尾秒口径。
     缺-02 公司出口 / 测试环境 / 内部代理 / 白名单 IP 清单未获授权名单。
           受影响 SQL：§C-00 的 ip_exclude 仅内置结构性无效地址三条。
           受影响产出：§C-02 之后的一切 IP 维度结论。
           解除条件：业务侧提供名单后，逐行追加至 ip_exclude 的 UNION ALL 列。
     缺-03 其他公共网络 IP 是否排除，须由业务确认。
           对应 SQL：§C-03 输出待确认清单及其影响量化，供业务裁决，
                     本文件不自行决定其去留。
   ========================================================================= */


/* ===========================================================================
   §C-00  排除名单（结构性无效地址，非业务名单）
   说明：本节仅为下述各语句内联 CTE 的书面留档，不单独执行。
         业务名单未到位前，ip_exclude 仅含三条结构性无效地址：
           '0.0.0.0'    未指定地址
           '127.0.0.1'  IPv4 回环
           '::1'        IPv6 回环
         业务名单到位后，在各语句的 ip_exclude CTE 内以 UNION ALL 逐行追加。
   ▸ 导出：不需要
   ========================================================================= */


/* ===========================================================================
   §C-01  去重与有效订单漏斗核对
   目的：逐级量化「原始行 → 最新版本 → 五项有效性条件」的折损，确立后续
         一切比率的分母，并核对去重前后差额。
   ▸ 导出：需要 → C01_有效订单漏斗核对.csv
   ========================================================================= */
WITH v AS (
  SELECT
      t.bet01, t.bet05, t.bet08, t.bet11, t.bet38, t.category,
      ROW_NUMBER() OVER (
          PARTITION BY t.bet01
          ORDER BY t.updatetime DESC, t.sync_time DESC, t.dt DESC
      ) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 t
  WHERE t.bet02 = '101'
),
latest AS (
  SELECT * FROM v WHERE rn = 1
)
SELECT
    (SELECT COUNT(*) FROM v)                              AS S0_原始行数_含全部版本,
    (SELECT COUNT(*) FROM latest)                         AS S1_去重后订单数,
    (SELECT COUNT(*) FROM v) - (SELECT COUNT(*) FROM latest) AS S1_被去重的历史版本行数,
    SUM(CASE WHEN CAST(category AS VARCHAR) = '1' THEN 1 ELSE 0 END)          AS S2_category等于1,
    SUM(CASE WHEN CAST(category AS VARCHAR) = '1'
              AND UPPER(TRIM(CAST(bet38 AS VARCHAR))) = 'N' THEN 1 ELSE 0 END) AS S3_再叠加bet38为N,
    SUM(CASE WHEN CAST(category AS VARCHAR) = '1'
              AND UPPER(TRIM(CAST(bet38 AS VARCHAR))) = 'N'
              AND CAST(bet05 AS BIGINT) > 0 THEN 1 ELSE 0 END)                 AS S4_再叠加bet05大于0,
    SUM(CASE WHEN CAST(category AS VARCHAR) = '1'
              AND UPPER(TRIM(CAST(bet38 AS VARCHAR))) = 'N'
              AND CAST(bet05 AS BIGINT) > 0
              AND CAST(bet11 AS DOUBLE) > 0 THEN 1 ELSE 0 END)                 AS S5_再叠加bet11大于0,
    SUM(CASE WHEN CAST(category AS VARCHAR) = '1'
              AND UPPER(TRIM(CAST(bet38 AS VARCHAR))) = 'N'
              AND CAST(bet05 AS BIGINT) > 0
              AND CAST(bet11 AS DOUBLE) > 0
              AND bet08 IS NOT NULL
              AND bet08 > '1970-01-01 00:00:00' THEN 1 ELSE 0 END)             AS S6_有效订单数,
    SUM(CASE WHEN CAST(bet05 AS BIGINT) IS NULL THEN 1 ELSE 0 END)             AS 附_bet05非数值行数,
    SUM(CASE WHEN bet08 IS NULL
                OR bet08 <= '1970-01-01 00:00:00' THEN 1 ELSE 0 END)           AS 附_bet08无效行数
FROM latest;


/* ===========================================================================
   §C-02  IP 清洗漏斗与排除影响量化
   目的：量化「空值 / 空串 / 格式错误 / 结构性无效地址」各自剔除的订单数、
         会员数与金额规模，作为 IP 维度分析可用性的前置声明。
   ▸ 导出：需要 → C02_IP清洗影响量化.csv
   ========================================================================= */
WITH v AS (
  SELECT
      t.bet01, t.bet05, t.ip, t.bet08, t.bet11, t.bet13, t.bet38, t.category,
      ROW_NUMBER() OVER (
          PARTITION BY t.bet01
          ORDER BY t.updatetime DESC, t.sync_time DESC, t.dt DESC
      ) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 t
  WHERE t.bet02 = '101'
),
valid AS (
  SELECT
      CAST(bet05 AS VARCHAR) AS member_id,
      CAST(ip    AS VARCHAR) AS ip_addr,
      CAST(bet13 AS DOUBLE) / CAST(bet11 AS DOUBLE) AS stake_amt
  FROM v
  WHERE rn = 1
    AND CAST(category AS VARCHAR) = '1'
    AND UPPER(TRIM(CAST(bet38 AS VARCHAR))) = 'N'
    AND CAST(bet05 AS BIGINT) > 0
    AND CAST(bet11 AS DOUBLE) > 0
    AND bet08 IS NOT NULL
    AND bet08 > '1970-01-01 00:00:00'
),
flagged AS (
  SELECT
      member_id,
      ip_addr,
      stake_amt,
      CASE WHEN ip_addr IS NULL THEN 1 ELSE 0 END AS f_null,
      CASE WHEN ip_addr = ''    THEN 1 ELSE 0 END AS f_blank,
      CASE
        WHEN ip_addr IS NULL OR ip_addr = '' THEN 0
        WHEN ip_addr REGEXP '^([0-9]{1,3}\\.){3}[0-9]{1,3}$'
             AND CAST(split_part(ip_addr, '.', 1) AS INT) BETWEEN 0 AND 255
             AND CAST(split_part(ip_addr, '.', 2) AS INT) BETWEEN 0 AND 255
             AND CAST(split_part(ip_addr, '.', 3) AS INT) BETWEEN 0 AND 255
             AND CAST(split_part(ip_addr, '.', 4) AS INT) BETWEEN 0 AND 255 THEN 0
        WHEN ip_addr REGEXP '^[0-9A-Fa-f:]+:[0-9A-Fa-f:]*$' THEN 0
        ELSE 1
      END AS f_malformed,
      CASE WHEN ip_addr IN ('0.0.0.0', '127.0.0.1', '::1') THEN 1 ELSE 0 END AS f_reserved
  FROM valid
)
SELECT
    COUNT(*)                                                    AS 有效订单数,
    COUNT(DISTINCT member_id)                                   AS 有效订单会员数,
    SUM(f_null)                                                 AS IP为空值_订单数,
    SUM(f_blank)                                                AS IP为空串_订单数,
    SUM(f_malformed)                                            AS IP格式错误_订单数,
    SUM(f_reserved)                                             AS 结构性无效地址_订单数,
    SUM(CASE WHEN f_null + f_blank + f_malformed + f_reserved > 0
             THEN 1 ELSE 0 END)                                 AS 合计被剔除_订单数,
    COUNT(DISTINCT CASE WHEN f_null + f_blank + f_malformed + f_reserved > 0
                        THEN member_id END)                     AS 合计被剔除_涉及会员数,
    SUM(CASE WHEN f_null + f_blank + f_malformed + f_reserved > 0
             THEN stake_amt ELSE 0 END)                         AS 合计被剔除_投注金额,
    CAST(SUM(CASE WHEN f_null + f_blank + f_malformed + f_reserved > 0
                  THEN 1 ELSE 0 END) AS DOUBLE)
        / NULLIF(COUNT(*), 0)                                   AS 合计被剔除_订单占比,
    SUM(CASE WHEN f_null + f_blank + f_malformed + f_reserved = 0
             THEN 1 ELSE 0 END)                                 AS 可用于IP分析_订单数
FROM flagged;


/* ===========================================================================
   §C-03  高聚集 IP 待业务确认清单（对应「缺-03」）
   目的：其他公共网络 IP 是否排除，由业务裁决。本语句只列示候选与其影响量，
         不作任何排除动作。
   门槛：承载会员数的 P99.9，由本语句内 PERCENTILE_APPROX 自数据推导，
         无手工设定阈值；门槛值随结果一并输出以便追溯。
   ▸ 导出：需要 → C03_高聚集IP待确认清单.csv
   ========================================================================= */
WITH v AS (
  SELECT
      t.bet01, t.bet05, t.ip, t.bet08, t.bet11, t.bet13, t.bet14, t.bet17,
      t.bet38, t.category,
      ROW_NUMBER() OVER (
          PARTITION BY t.bet01
          ORDER BY t.updatetime DESC, t.sync_time DESC, t.dt DESC
      ) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 t
  WHERE t.bet02 = '101'
),
valid AS (
  SELECT
      CAST(bet05 AS VARCHAR) AS member_id,
      CAST(ip    AS VARCHAR) AS ip_addr,
      DATE(bet08)            AS bet_date,
      CAST(bet13 AS DOUBLE) / CAST(bet11 AS DOUBLE) AS stake_amt,
      (CAST(bet14 AS DOUBLE) - CAST(bet13 AS DOUBLE)) / CAST(bet11 AS DOUBLE) AS game_pl,
      CAST(bet17 AS DOUBLE) / CAST(bet11 AS DOUBLE) AS net_pl
  FROM v
  WHERE rn = 1
    AND CAST(category AS VARCHAR) = '1'
    AND UPPER(TRIM(CAST(bet38 AS VARCHAR))) = 'N'
    AND CAST(bet05 AS BIGINT) > 0
    AND CAST(bet11 AS DOUBLE) > 0
    AND bet08 IS NOT NULL
    AND bet08 > '1970-01-01 00:00:00'
    AND ip IS NOT NULL AND CAST(ip AS VARCHAR) <> ''
    AND CAST(ip AS VARCHAR) NOT IN ('0.0.0.0', '127.0.0.1', '::1')
),
per_ip AS (
  SELECT
      ip_addr,
      COUNT(DISTINCT member_id) AS n_member,
      COUNT(*)                  AS n_orders,
      COUNT(DISTINCT bet_date)  AS n_days,
      SUM(stake_amt)            AS stake_amt,
      SUM(game_pl)              AS game_pl,
      SUM(net_pl)               AS net_pl
  FROM valid
  GROUP BY ip_addr
),
cut AS (
  SELECT CAST(PERCENTILE_APPROX(CAST(n_member AS DOUBLE), 0.999) AS BIGINT) AS m_cut
  FROM per_ip
),
tot AS (
  SELECT COUNT(*) AS t_orders, SUM(stake_amt) AS t_stake FROM valid
)
SELECT
    p.ip_addr                                        AS IP,
    p.n_member                                       AS 承载会员数,
    p.n_orders                                       AS 订单数,
    p.n_days                                         AS 活跃天数,
    p.stake_amt                                      AS 投注金额,
    p.game_pl                                        AS 游戏盈利,
    p.net_pl                                         AS 净盈利,
    CAST(p.n_orders AS DOUBLE) / NULLIF(t.t_orders, 0) AS 订单占全量比,
    CAST(p.stake_amt AS DOUBLE) / NULLIF(t.t_stake, 0) AS 投注额占全量比,
    c.m_cut                                          AS 入选门槛_承载会员数P999
FROM per_ip p
CROSS JOIN cut c
CROSS JOIN tot t
WHERE p.n_member >= c.m_cut
ORDER BY p.n_member DESC, p.n_orders DESC;


/* ===========================================================================
   §C-04  金额与盈利口径日度对账
   目的：四项金额口径同时输出，供逐日核对；避免返水混入而误判下注优势。
         恒等关系核验：净盈利 - (游戏盈利 + 返水) 的日度残差应为 0，
         若非 0，则 bet17 与 (bet14 - bet13 + bet16) 之间存在未知项，须查证。
   ▸ 导出：需要 → C04_金额盈利口径日度对账.csv
   ========================================================================= */
WITH v AS (
  SELECT
      t.bet01, t.bet05, t.bet08, t.bet11, t.bet13, t.bet14, t.bet16, t.bet17,
      t.bet38, t.category,
      ROW_NUMBER() OVER (
          PARTITION BY t.bet01
          ORDER BY t.updatetime DESC, t.sync_time DESC, t.dt DESC
      ) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 t
  WHERE t.bet02 = '101'
),
valid AS (
  SELECT
      CAST(bet05 AS VARCHAR) AS member_id,
      DATE(bet08)            AS bet_date,
      CAST(bet13 AS DOUBLE) / CAST(bet11 AS DOUBLE) AS stake_amt,
      (CAST(bet14 AS DOUBLE) - CAST(bet13 AS DOUBLE)) / CAST(bet11 AS DOUBLE) AS game_pl,
      CAST(bet16 AS DOUBLE) / CAST(bet11 AS DOUBLE) AS rebate_amt,
      CAST(bet17 AS DOUBLE) / CAST(bet11 AS DOUBLE) AS net_pl
  FROM v
  WHERE rn = 1
    AND CAST(category AS VARCHAR) = '1'
    AND UPPER(TRIM(CAST(bet38 AS VARCHAR))) = 'N'
    AND CAST(bet05 AS BIGINT) > 0
    AND CAST(bet11 AS DOUBLE) > 0
    AND bet08 IS NOT NULL
    AND bet08 > '1970-01-01 00:00:00'
)
SELECT
    bet_date                                          AS 日期,
    COUNT(*)                                          AS 有效订单数,
    COUNT(DISTINCT member_id)                         AS 活跃会员数,
    SUM(stake_amt)                                    AS 投注金额,
    SUM(game_pl)                                      AS 游戏盈利,
    SUM(rebate_amt)                                   AS 返水,
    SUM(net_pl)                                       AS 净盈利,
    SUM(net_pl) - (SUM(game_pl) + SUM(rebate_amt))    AS 恒等残差_净减游戏加返水,
    SUM(game_pl)   / NULLIF(SUM(stake_amt), 0)        AS 游戏盈利率,
    SUM(rebate_amt)/ NULLIF(SUM(stake_amt), 0)        AS 返水率,
    SUM(net_pl)    / NULLIF(SUM(stake_amt), 0)        AS 净盈利率
FROM valid
GROUP BY bet_date
ORDER BY bet_date;


/* ===========================================================================
   §C-05  玩家物理局聚合基表（局级明细）
   目的：同一玩家在同一物理局的多笔订单先行聚合，作为 §C-06 至 §C-09 的
         唯一局级来源；胜负和判定一律在本层完成，禁止在订单层判定。
   说明：导出量级约等于「会员 × 参与局」，如需落地请采用键集分页
         （按 member_id, round_key 升序），不得使用 OFFSET。
   ▸ 导出：不需要
   ========================================================================= */
WITH v AS (
  SELECT
      t.bet01, t.bet03, t.bet04, t.bet05, t.bet08, t.bet11, t.bet13, t.bet14,
      t.bet16, t.bet17, t.bet38, t.bet39, t.category,
      ROW_NUMBER() OVER (
          PARTITION BY t.bet01
          ORDER BY t.updatetime DESC, t.sync_time DESC, t.dt DESC
      ) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 t
  WHERE t.bet02 = '101'
),
valid AS (
  SELECT
      CAST(bet05 AS VARCHAR) AS member_id,
      CONCAT_WS('|',
          CAST(bet03 AS VARCHAR),
          CAST(bet04 AS VARCHAR),
          CAST(bet39 AS VARCHAR)) AS round_key,
      bet08                  AS bet_time,
      DATE(bet08)            AS bet_date,
      CAST(bet13 AS DOUBLE) / CAST(bet11 AS DOUBLE) AS stake_amt,
      (CAST(bet14 AS DOUBLE) - CAST(bet13 AS DOUBLE)) / CAST(bet11 AS DOUBLE) AS game_pl,
      CAST(bet16 AS DOUBLE) / CAST(bet11 AS DOUBLE) AS rebate_amt,
      CAST(bet17 AS DOUBLE) / CAST(bet11 AS DOUBLE) AS net_pl
  FROM v
  WHERE rn = 1
    AND CAST(category AS VARCHAR) = '1'
    AND UPPER(TRIM(CAST(bet38 AS VARCHAR))) = 'N'
    AND CAST(bet05 AS BIGINT) > 0
    AND CAST(bet11 AS DOUBLE) > 0
    AND bet08 IS NOT NULL
    AND bet08 > '1970-01-01 00:00:00'
)
SELECT
    member_id                       AS 会员ID,
    round_key                       AS 物理局键,
    MIN(bet_date)                   AS 局日期,
    MIN(bet_time)                   AS 局内首单时间,
    MAX(bet_time)                   AS 局内末单时间,
    COUNT(*)                        AS 局内订单数,
    SUM(stake_amt)                  AS 局投注金额,
    SUM(game_pl)                    AS 局游戏盈利,
    SUM(rebate_amt)                 AS 局返水,
    SUM(net_pl)                     AS 局净盈利,
    CASE WHEN SUM(game_pl) > 0 THEN '胜局'
         WHEN SUM(game_pl) < 0 THEN '负局'
         ELSE '和局' END            AS 局结果
FROM valid
GROUP BY member_id, round_key
ORDER BY member_id, round_key;


/* ===========================================================================
   §C-06  会员盈亏判定（全量历史窗口）
   判定：窗口内 SUM(净盈利) > 0 为盈利账户。净盈利、游戏盈利、返水同时输出，
         以便区分「靠下注优势盈利」与「靠返水盈利」两类账户。
   ▸ 导出：需要 → C06_会员盈亏判定_全量窗口.csv
   ========================================================================= */
WITH v AS (
  SELECT
      t.bet01, t.bet03, t.bet04, t.bet05, t.bet08, t.bet11, t.bet13, t.bet14,
      t.bet16, t.bet17, t.bet38, t.bet39, t.category,
      ROW_NUMBER() OVER (
          PARTITION BY t.bet01
          ORDER BY t.updatetime DESC, t.sync_time DESC, t.dt DESC
      ) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 t
  WHERE t.bet02 = '101'
),
valid AS (
  SELECT
      CAST(bet05 AS VARCHAR) AS member_id,
      CONCAT_WS('|',
          CAST(bet03 AS VARCHAR),
          CAST(bet04 AS VARCHAR),
          CAST(bet39 AS VARCHAR)) AS round_key,
      DATE(bet08)            AS bet_date,
      CAST(bet13 AS DOUBLE) / CAST(bet11 AS DOUBLE) AS stake_amt,
      (CAST(bet14 AS DOUBLE) - CAST(bet13 AS DOUBLE)) / CAST(bet11 AS DOUBLE) AS game_pl,
      CAST(bet16 AS DOUBLE) / CAST(bet11 AS DOUBLE) AS rebate_amt,
      CAST(bet17 AS DOUBLE) / CAST(bet11 AS DOUBLE) AS net_pl
  FROM v
  WHERE rn = 1
    AND CAST(category AS VARCHAR) = '1'
    AND UPPER(TRIM(CAST(bet38 AS VARCHAR))) = 'N'
    AND CAST(bet05 AS BIGINT) > 0
    AND CAST(bet11 AS DOUBLE) > 0
    AND bet08 IS NOT NULL
    AND bet08 > '1970-01-01 00:00:00'
),
round_agg AS (
  SELECT
      member_id, round_key,
      MIN(bet_date)  AS bet_date,
      SUM(stake_amt) AS stake_amt,
      SUM(game_pl)   AS game_pl,
      SUM(rebate_amt) AS rebate_amt,
      SUM(net_pl)    AS net_pl
  FROM valid
  GROUP BY member_id, round_key
)
SELECT
    member_id                                              AS 会员ID,
    COUNT(*)                                               AS 参与局数,
    COUNT(DISTINCT bet_date)                               AS 活跃天数,
    SUM(stake_amt)                                         AS 投注金额,
    SUM(game_pl)                                           AS 游戏盈利,
    SUM(rebate_amt)                                        AS 返水,
    SUM(net_pl)                                            AS 净盈利,
    CASE WHEN SUM(net_pl)  > 0 THEN 1 ELSE 0 END           AS 是否净盈利,
    CASE WHEN SUM(game_pl) > 0 THEN 1 ELSE 0 END           AS 是否游戏盈利,
    CASE WHEN SUM(net_pl) > 0 AND SUM(game_pl) <= 0
         THEN 1 ELSE 0 END                                 AS 是否仅靠返水转正,
    SUM(CASE WHEN game_pl > 0 THEN 1 ELSE 0 END)           AS 胜局数,
    SUM(CASE WHEN game_pl < 0 THEN 1 ELSE 0 END)           AS 负局数,
    SUM(CASE WHEN game_pl = 0 THEN 1 ELSE 0 END)           AS 和局数,
    CAST(SUM(CASE WHEN game_pl > 0 THEN 1 ELSE 0 END) AS DOUBLE)
        / NULLIF(SUM(CASE WHEN game_pl > 0 THEN 1 ELSE 0 END)
               + SUM(CASE WHEN game_pl < 0 THEN 1 ELSE 0 END), 0) AS 胜率,
    SUM(game_pl) / NULLIF(SUM(stake_amt), 0)               AS 游戏盈利率,
    SUM(net_pl)  / NULLIF(SUM(stake_amt), 0)               AS 净盈利率
FROM round_agg
GROUP BY member_id
ORDER BY 净盈利 DESC;


/* ===========================================================================
   §C-07  月度稳定性面板（自然月，局级胜率 + 三项盈利口径）
   注意：首尾月通常不满月，须结合「当月有下注天数」判读。
   ▸ 导出：需要 → C07_月度稳定性面板.csv
   ========================================================================= */
WITH v AS (
  SELECT
      t.bet01, t.bet03, t.bet04, t.bet05, t.bet08, t.bet11, t.bet13, t.bet14,
      t.bet16, t.bet17, t.bet38, t.bet39, t.category,
      ROW_NUMBER() OVER (
          PARTITION BY t.bet01
          ORDER BY t.updatetime DESC, t.sync_time DESC, t.dt DESC
      ) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 t
  WHERE t.bet02 = '101'
),
valid AS (
  SELECT
      CAST(bet05 AS VARCHAR) AS member_id,
      CONCAT_WS('|',
          CAST(bet03 AS VARCHAR),
          CAST(bet04 AS VARCHAR),
          CAST(bet39 AS VARCHAR)) AS round_key,
      DATE(bet08)                 AS bet_date,
      DATE_FORMAT(bet08, '%Y-%m') AS ym,
      CAST(bet13 AS DOUBLE) / CAST(bet11 AS DOUBLE) AS stake_amt,
      (CAST(bet14 AS DOUBLE) - CAST(bet13 AS DOUBLE)) / CAST(bet11 AS DOUBLE) AS game_pl,
      CAST(bet16 AS DOUBLE) / CAST(bet11 AS DOUBLE) AS rebate_amt,
      CAST(bet17 AS DOUBLE) / CAST(bet11 AS DOUBLE) AS net_pl
  FROM v
  WHERE rn = 1
    AND CAST(category AS VARCHAR) = '1'
    AND UPPER(TRIM(CAST(bet38 AS VARCHAR))) = 'N'
    AND CAST(bet05 AS BIGINT) > 0
    AND CAST(bet11 AS DOUBLE) > 0
    AND bet08 IS NOT NULL
    AND bet08 > '1970-01-01 00:00:00'
),
round_agg AS (
  SELECT
      ym, member_id, round_key,
      MIN(bet_date)   AS bet_date,
      SUM(stake_amt)  AS stake_amt,
      SUM(game_pl)    AS game_pl,
      SUM(rebate_amt) AS rebate_amt,
      SUM(net_pl)     AS net_pl
  FROM valid
  GROUP BY ym, member_id, round_key
)
SELECT
    ym                                                     AS 年月,
    COUNT(DISTINCT bet_date)                               AS 当月有下注天数,
    COUNT(DISTINCT member_id)                              AS 活跃会员数,
    COUNT(DISTINCT round_key)                              AS 物理局数,
    COUNT(*)                                               AS 玩家局数,
    SUM(stake_amt)                                         AS 投注金额,
    SUM(game_pl)                                           AS 游戏盈利,
    SUM(rebate_amt)                                        AS 返水,
    SUM(net_pl)                                            AS 净盈利,
    SUM(CASE WHEN game_pl > 0 THEN 1 ELSE 0 END)           AS 胜局数,
    SUM(CASE WHEN game_pl < 0 THEN 1 ELSE 0 END)           AS 负局数,
    SUM(CASE WHEN game_pl = 0 THEN 1 ELSE 0 END)           AS 和局数,
    CAST(SUM(CASE WHEN game_pl > 0 THEN 1 ELSE 0 END) AS DOUBLE)
        / NULLIF(SUM(CASE WHEN game_pl > 0 THEN 1 ELSE 0 END)
               + SUM(CASE WHEN game_pl < 0 THEN 1 ELSE 0 END), 0) AS 胜率,
    SUM(game_pl) / NULLIF(SUM(stake_amt), 0)               AS 游戏盈利率,
    SUM(net_pl)  / NULLIF(SUM(stake_amt), 0)               AS 净盈利率
FROM round_agg
GROUP BY ym
ORDER BY ym;


/* ===========================================================================
   §C-08  滚动 30 日稳定性面板（局级胜率 + 三项盈利口径）
   实现：以事实表内实际存在的下注日期为窗口右端点自连接，不引入外部日历表。
         窗口长度 30 日来源于分析口径定义，非统计阈值。
   ▸ 导出：需要 → C08_滚动30日稳定性面板.csv
   ========================================================================= */
WITH v AS (
  SELECT
      t.bet01, t.bet03, t.bet04, t.bet05, t.bet08, t.bet11, t.bet13, t.bet14,
      t.bet16, t.bet17, t.bet38, t.bet39, t.category,
      ROW_NUMBER() OVER (
          PARTITION BY t.bet01
          ORDER BY t.updatetime DESC, t.sync_time DESC, t.dt DESC
      ) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 t
  WHERE t.bet02 = '101'
),
valid AS (
  SELECT
      CAST(bet05 AS VARCHAR) AS member_id,
      CONCAT_WS('|',
          CAST(bet03 AS VARCHAR),
          CAST(bet04 AS VARCHAR),
          CAST(bet39 AS VARCHAR)) AS round_key,
      DATE(bet08)            AS bet_date,
      CAST(bet13 AS DOUBLE) / CAST(bet11 AS DOUBLE) AS stake_amt,
      (CAST(bet14 AS DOUBLE) - CAST(bet13 AS DOUBLE)) / CAST(bet11 AS DOUBLE) AS game_pl,
      CAST(bet16 AS DOUBLE) / CAST(bet11 AS DOUBLE) AS rebate_amt,
      CAST(bet17 AS DOUBLE) / CAST(bet11 AS DOUBLE) AS net_pl
  FROM v
  WHERE rn = 1
    AND CAST(category AS VARCHAR) = '1'
    AND UPPER(TRIM(CAST(bet38 AS VARCHAR))) = 'N'
    AND CAST(bet05 AS BIGINT) > 0
    AND CAST(bet11 AS DOUBLE) > 0
    AND bet08 IS NOT NULL
    AND bet08 > '1970-01-01 00:00:00'
),
round_agg AS (
  SELECT
      member_id, round_key,
      MIN(bet_date)   AS bet_date,
      SUM(stake_amt)  AS stake_amt,
      SUM(game_pl)    AS game_pl,
      SUM(rebate_amt) AS rebate_amt,
      SUM(net_pl)     AS net_pl
  FROM valid
  GROUP BY member_id, round_key
),
spine AS (
  SELECT DISTINCT bet_date FROM round_agg
)
SELECT
    s.bet_date                                             AS 窗口右端日,
    DATE_SUB(s.bet_date, INTERVAL 29 DAY)                  AS 窗口左端日,
    COUNT(DISTINCT r.bet_date)                             AS 窗口内有下注天数,
    CASE WHEN COUNT(DISTINCT r.bet_date) >= 30 THEN 1 ELSE 0 END AS 是否满窗,
    COUNT(DISTINCT r.member_id)                            AS 活跃会员数,
    COUNT(DISTINCT r.round_key)                            AS 物理局数,
    COUNT(*)                                               AS 玩家局数,
    SUM(r.stake_amt)                                       AS 投注金额,
    SUM(r.game_pl)                                         AS 游戏盈利,
    SUM(r.rebate_amt)                                      AS 返水,
    SUM(r.net_pl)                                          AS 净盈利,
    SUM(CASE WHEN r.game_pl > 0 THEN 1 ELSE 0 END)         AS 胜局数,
    SUM(CASE WHEN r.game_pl < 0 THEN 1 ELSE 0 END)         AS 负局数,
    SUM(CASE WHEN r.game_pl = 0 THEN 1 ELSE 0 END)         AS 和局数,
    CAST(SUM(CASE WHEN r.game_pl > 0 THEN 1 ELSE 0 END) AS DOUBLE)
        / NULLIF(SUM(CASE WHEN r.game_pl > 0 THEN 1 ELSE 0 END)
               + SUM(CASE WHEN r.game_pl < 0 THEN 1 ELSE 0 END), 0) AS 胜率,
    SUM(r.game_pl) / NULLIF(SUM(r.stake_amt), 0)           AS 游戏盈利率,
    SUM(r.net_pl)  / NULLIF(SUM(r.stake_amt), 0)           AS 净盈利率
FROM spine s
JOIN round_agg r
  ON r.bet_date >  DATE_SUB(s.bet_date, INTERVAL 30 DAY)
 AND r.bet_date <= s.bet_date
GROUP BY s.bet_date
ORDER BY s.bet_date;


/* ===========================================================================
   §C-09  会员 × 月度 盈亏与胜率面板（用于同一账户跨窗口的稳定性判读）
   目的：§C-06 给出全量窗口的账户级判定，本语句给出同一账户逐月的判定序列，
         用以区分「持续盈利」与「单月爆发」。
   ▸ 导出：需要 → C09_会员月度盈亏胜率面板.csv
   ========================================================================= */
WITH v AS (
  SELECT
      t.bet01, t.bet03, t.bet04, t.bet05, t.bet08, t.bet11, t.bet13, t.bet14,
      t.bet16, t.bet17, t.bet38, t.bet39, t.category,
      ROW_NUMBER() OVER (
          PARTITION BY t.bet01
          ORDER BY t.updatetime DESC, t.sync_time DESC, t.dt DESC
      ) AS rn
  FROM ods_mariadb_2b.ods_a168_bet02 t
  WHERE t.bet02 = '101'
),
valid AS (
  SELECT
      CAST(bet05 AS VARCHAR) AS member_id,
      CONCAT_WS('|',
          CAST(bet03 AS VARCHAR),
          CAST(bet04 AS VARCHAR),
          CAST(bet39 AS VARCHAR)) AS round_key,
      DATE(bet08)                 AS bet_date,
      DATE_FORMAT(bet08, '%Y-%m') AS ym,
      CAST(bet13 AS DOUBLE) / CAST(bet11 AS DOUBLE) AS stake_amt,
      (CAST(bet14 AS DOUBLE) - CAST(bet13 AS DOUBLE)) / CAST(bet11 AS DOUBLE) AS game_pl,
      CAST(bet16 AS DOUBLE) / CAST(bet11 AS DOUBLE) AS rebate_amt,
      CAST(bet17 AS DOUBLE) / CAST(bet11 AS DOUBLE) AS net_pl
  FROM v
  WHERE rn = 1
    AND CAST(category AS VARCHAR) = '1'
    AND UPPER(TRIM(CAST(bet38 AS VARCHAR))) = 'N'
    AND CAST(bet05 AS BIGINT) > 0
    AND CAST(bet11 AS DOUBLE) > 0
    AND bet08 IS NOT NULL
    AND bet08 > '1970-01-01 00:00:00'
),
round_agg AS (
  SELECT
      ym, member_id, round_key,
      MIN(bet_date)   AS bet_date,
      SUM(stake_amt)  AS stake_amt,
      SUM(game_pl)    AS game_pl,
      SUM(rebate_amt) AS rebate_amt,
      SUM(net_pl)     AS net_pl
  FROM valid
  GROUP BY ym, member_id, round_key
)
SELECT
    member_id                                              AS 会员ID,
    ym                                                     AS 年月,
    COUNT(DISTINCT bet_date)                               AS 当月活跃天数,
    COUNT(*)                                               AS 参与局数,
    SUM(stake_amt)                                         AS 投注金额,
    SUM(game_pl)                                           AS 游戏盈利,
    SUM(rebate_amt)                                        AS 返水,
    SUM(net_pl)                                            AS 净盈利,
    CASE WHEN SUM(net_pl)  > 0 THEN 1 ELSE 0 END           AS 是否净盈利,
    CASE WHEN SUM(game_pl) > 0 THEN 1 ELSE 0 END           AS 是否游戏盈利,
    SUM(CASE WHEN game_pl > 0 THEN 1 ELSE 0 END)           AS 胜局数,
    SUM(CASE WHEN game_pl < 0 THEN 1 ELSE 0 END)           AS 负局数,
    SUM(CASE WHEN game_pl = 0 THEN 1 ELSE 0 END)           AS 和局数,
    CAST(SUM(CASE WHEN game_pl > 0 THEN 1 ELSE 0 END) AS DOUBLE)
        / NULLIF(SUM(CASE WHEN game_pl > 0 THEN 1 ELSE 0 END)
               + SUM(CASE WHEN game_pl < 0 THEN 1 ELSE 0 END), 0) AS 胜率,
    SUM(game_pl) / NULLIF(SUM(stake_amt), 0)               AS 游戏盈利率,
    SUM(net_pl)  / NULLIF(SUM(stake_amt), 0)               AS 净盈利率
FROM round_agg
GROUP BY member_id, ym
ORDER BY member_id, ym;


/* ============================================================================
   【导出汇总（与语句一一对应）】
     §C-00  不需要
     §C-01  C01_有效订单漏斗核对.csv
     §C-02  C02_IP清洗影响量化.csv
     §C-03  C03_高聚集IP待确认清单.csv
     §C-04  C04_金额盈利口径日度对账.csv
     §C-05  不需要
     §C-06  C06_会员盈亏判定_全量窗口.csv
     §C-07  C07_月度稳定性面板.csv
     §C-08  C08_滚动30日稳定性面板.csv
     §C-09  C09_会员月度盈亏胜率面板.csv

   【读取端约定】Superset 导出为 GBK/GB18030，沿用既定编码自适应读取器
     （UTF-8-sig → UTF-8 → GB18030 → GBK → Big5 → Latin1），R 与 Python 两侧
     共用同一 DATA_DIR 常量。
   ========================================================================= */
