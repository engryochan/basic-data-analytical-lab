/* ═══════════════════════════════════════════════════════════════════════
   D-06X · S_player_tail 覆盖率与商业价值审计（派生自 D-06，血统标记 X）
   用途：证明 HAVING COUNT(*)>=30 这道闸筛掉了多少人、多少局、多少钱、
         占整盘生意多大比例——供商业方案「结论先行」章节引用
   ▸ 不导出交付件，仅供 Superset SQL Lab 内直接阅读
   ▸ 前七层（ta/rk/vd/bs/ord/prd/fl）与 D-06 逐字一致，唯 vd 层新增两行
     防御性局键哨兵闸（对应过去会话已知的 102 行局键哨兵残量，零成本可挡）
   ▸ eid 哨兵（-1/0）刻意不在此处过滤——该字段不属本管道选取范围，
     其唯一已证实的适用场景是荷官线 S-02／R03／DX-05／EX-05，混用即范畴错误
   ▸ 电投批次（bet03=0∧bet39=0∧gametype=3）不另设过滤——过去会话已实证
     「限百家乐后全数消失」，本管道既有 bet02='101' 闸已结构性挡下，重复
     过滤属冗余判断
   ═══════════════════════════════════════════════════════════════════════ */
-- 导出为 CSV，文件名改为 D-06X_population_summary.csv
WITH ta AS (                                                                                        -- 测试线代理名册，与 D-06 完全一致
  SELECT DISTINCT age001 AS aid                                                                     -- 取列：产出「aid」
  FROM ods_mariadb_2b.ods_a168_agent WHERE age022 = '1'                                             -- 取数来源：取自代理主档（五级代理线归属来源）
),                                                                                                  -- 续行：收束上方的子查询或函数括号
rk AS (                                                                                             -- 版本去重 + 窗口/游戏类别切分，与 D-06 完全一致
  SELECT b.bet01, b.updatetime, b.sync_time, b.dt, b.bet02,
         b.bet03, b.bet04, b.bet05, b.bet08, b.bet11,
         b.bet13, b.bet14, b.bet16, b.bet17, b.bet18,
         b.bet19, b.bet20, b.bet21, b.bet22, b.bet38,
         b.bet39, b.category, b.validbet,
         ROW_NUMBER() OVER (
           PARTITION BY b.bet01
           ORDER BY b.updatetime DESC, b.sync_time DESC, b.dt DESC) AS rn                           -- 排序：导出必带排序，否则分页无稳定序
  FROM ods_mariadb_2b.ods_a168_bet02 b                                                              -- 取数来源：取自注单明细表
  WHERE b.dt >= '2026-03-21' AND b.dt < '2026-08-07' AND b.bet02 = '101'                            -- 过滤条件：左闭右开 139 营业日，限百家乐
),                                                                                                  -- 续行
vd AS (                                                                                             -- 主体准入：D-06 六项条件完全一致，末两行为本次新增防御闸
  SELECT r.*                                                                                        -- 取列：整体承接上游结果集全部字段
  FROM rk r
  LEFT JOIN ta t1 ON t1.aid = r.bet18
  LEFT JOIN ta t2 ON t2.aid = r.bet19
  LEFT JOIN ta t3 ON t3.aid = r.bet20
  LEFT JOIN ta t4 ON t4.aid = r.bet21
  LEFT JOIN ta t5 ON t5.aid = r.bet22
  WHERE r.rn = 1 AND r.category = '1' AND UPPER(TRIM(r.bet38)) = 'N'                                -- 过滤条件：最新版本、正式类别、非测试标识
    AND CAST(NULLIF(TRIM(r.bet05),'') AS BIGINT) > 0                                                -- 并列条件：会员号有效
    AND CAST(NULLIF(TRIM(r.bet11),'') AS DECIMAL(20,8)) > 0                                         -- 并列条件：汇率有效
    AND NULLIF(TRIM(r.bet08),'') IS NOT NULL                                                        -- 并列条件：下注时间非空
    AND COALESCE(t1.aid, t2.aid, t3.aid, t4.aid, t5.aid) IS NULL                                    -- 并列条件：五级代理线均非测试线
    AND NULLIF(TRIM(r.bet03), '0') IS NOT NULL                                                      -- 新增：局键哨兵闸，剔 bet03='0'（对照既知 102 行残量）
    AND NULLIF(TRIM(r.bet39), '0') IS NOT NULL                                                      -- 新增：同上，桌号哨兵一并剔除
),                                                                                                  -- 续行
bs AS (                                                                                             -- 口径归一层，与 D-06 完全一致；符号一律玩家视角（负=玩家输=平台赢）
  SELECT v.bet05 AS member_id,
         CONCAT_WS('|', v.bet03, v.bet04, v.bet39) AS round_key,
         v.bet39 AS table_id,
         CAST(NULLIF(TRIM(v.bet08),'') AS DATETIME) AS t_bet,
         CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS stake,                              -- 下注额（经汇率归一，玩家视角流水）
         CAST(NULLIF(TRIM(v.validbet),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS valid_bet,                          -- 洗码量（validbet 定义未锁，见 D-06 审计 F-02，此处沿用现行口径）
         (CAST(NULLIF(TRIM(v.bet14),'') AS DECIMAL(20,4))
          - CAST(NULLIF(TRIM(v.bet13),'') AS DECIMAL(20,4)))
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS game_pnl,                           -- 游戏净输赢（玩家视角，不含退水）
         CAST(NULLIF(TRIM(v.bet16),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS rebate,                             -- 退水（平台成本）
         CAST(NULLIF(TRIM(v.bet17),'') AS DECIMAL(20,4))
           / CAST(NULLIF(TRIM(v.bet11),'') AS DECIMAL(20,8)) AS net_pnl                             -- 会员净输赢（玩家视角，含退水）
  FROM vd v
),                                                                                                  -- 续行
ord AS (                                                                                            -- 局内时序定标，与 D-06 完全一致
  SELECT b.*, PERCENT_RANK() OVER (PARTITION BY round_key ORDER BY t_bet) AS pr_in_round,
              COUNT(*)      OVER (PARTITION BY round_key)                 AS n_in_round
  FROM bs b
),                                                                                                  -- 续行
prd AS (                                                                                            -- 玩家-局聚合（L6 密度闸），与 D-06 完全一致
  SELECT member_id, round_key, table_id,
         MAX(pr_in_round) AS max_pr,
         MAX(n_in_round)  AS n_in_round,
         SUM(stake) AS stake, SUM(valid_bet) AS valid_bet,
         SUM(game_pnl) AS game_pnl, SUM(rebate) AS rebate, SUM(net_pnl) AS net_pnl,
         CASE WHEN SUM(game_pnl) > 0 THEN 1 ELSE 0 END AS is_win,
         CASE WHEN SUM(game_pnl) < 0 THEN 1 ELSE 0 END AS is_lose
  FROM ord WHERE n_in_round >= 5
  GROUP BY member_id, round_key, table_id
),                                                                                                  -- 续行
fl AS (                                                                                             -- 尾段判定，与 D-06 完全一致
  SELECT p.*, CASE WHEN p.max_pr >= 0.80 THEN 1 ELSE 0 END AS is_tail
  FROM prd p
),                                                                                                  -- 续行
member_agg AS (                                                                                     -- 玩家级预聚合（本文件新增，非 D-06 原有）
  SELECT member_id,
         COUNT(*)       AS n_rounds_all,                                                            -- 合格局数
         SUM(is_tail)   AS n_rounds_tail,                                                           -- 尾段局数
         SUM(stake)     AS stake,
         SUM(valid_bet) AS valid_bet,
         SUM(game_pnl)  AS game_pnl,
         SUM(rebate)    AS rebate,
         SUM(net_pnl)   AS net_pnl
  FROM fl
  GROUP BY member_id
),                                                                                                  -- 续行
labeled AS (                                                                                        -- 按 HAVING>=30 这道闸二分总体
  SELECT *,
    CASE WHEN n_rounds_all >= 30 THEN 'S_player_tail' ELSE '非S_player_tail' END AS population      -- 与 D-06 末段的 HAVING 阈值一字不差对齐
  FROM member_agg
),                                                                                                  -- 续行
pop_stats AS (                                                                                      -- 两群分别聚合；GGR/NGR 口径见下方注释，符号已转为平台视角
  SELECT
    population,
    COUNT(*)                                          AS n_members,
    SUM(n_rounds_all)                                 AS total_rounds,
    SUM(n_rounds_tail)                                AS total_tail_rounds,
    SUM(n_rounds_tail) * 1.0 / NULLIF(SUM(n_rounds_all), 0) AS overall_tail_share,
    AVG(n_rounds_all * 1.0)                           AS avg_rounds_per_member,
    MIN(n_rounds_all)                                 AS min_rounds,
    MAX(n_rounds_all)                                 AS max_rounds,
    SUM(stake)                                        AS total_stake,                               -- 总下注额（流水）
    SUM(valid_bet)                                    AS total_valid_bet,                           -- 总洗码量（handle，代理返点计算基准）
    SUM(game_pnl)                                     AS total_game_pnl,                            -- 玩家视角：负=玩家总体输钱
    SUM(rebate)                                       AS total_rebate,
    SUM(net_pnl)                                      AS total_net_pnl,                             -- 玩家视角：负=玩家含退水后仍净输
    -SUM(game_pnl)                                    AS total_ggr,                                 -- GGR = -Σgame_pnl；符号翻转=转为平台视角
    -SUM(net_pnl)                                     AS total_ngr                                  -- NGR = -Σnet_pnl = GGR − 退水成本；恒等式 NGR=GGR-Σrebate 可自校验
  FROM labeled
  GROUP BY population
),                                                                                                  -- 续行
grand_total AS (                                                                                    -- 合计行：不分群，供占比计算当分母（取代 SUM(SUM())OVER() 的边缘语法）
  SELECT
    '合计' AS population,
    COUNT(*)                                          AS n_members,
    SUM(n_rounds_all)                                 AS total_rounds,
    SUM(n_rounds_tail)                                AS total_tail_rounds,
    SUM(n_rounds_tail) * 1.0 / NULLIF(SUM(n_rounds_all), 0) AS overall_tail_share,
    AVG(n_rounds_all * 1.0)                           AS avg_rounds_per_member,
    MIN(n_rounds_all)                                 AS min_rounds,
    MAX(n_rounds_all)                                 AS max_rounds,
    SUM(stake)                                        AS total_stake,
    SUM(valid_bet)                                    AS total_valid_bet,
    SUM(game_pnl)                                     AS total_game_pnl,
    SUM(rebate)                                       AS total_rebate,
    SUM(net_pnl)                                      AS total_net_pnl,
    -SUM(game_pnl)                                    AS total_ggr,
    -SUM(net_pnl)                                     AS total_ngr
  FROM labeled
),                                                                                                  -- 续行
combined AS (                                                                                       -- 两群 + 合计，纵向拼接为三行
  SELECT * FROM pop_stats
  UNION ALL
  SELECT * FROM grand_total
),                                                                                                  -- 续行
denom AS (                                                                                          -- 单独摘出「合计」行的关键字段，供下方逐项占比计算当分母
  SELECT n_members AS d_members, total_rounds AS d_rounds,
         total_ggr AS d_ggr, total_ngr AS d_ngr,
         total_valid_bet AS d_valid_bet, total_stake AS d_stake
  FROM grand_total
)                                                                                                   -- 续行
SELECT
  c.population,                                                                                     -- 人群标签：S_player_tail／非S_player_tail／合计（三行，合计行占比恒为 100% 作自洽性校验）
  c.n_members,                                                                                       -- 会员数
  c.n_members * 1.0 / NULLIF(d.d_members, 0)          AS share_of_members,                          -- 市场份额·人群维度
  c.total_rounds,                                                                                    -- 总局数
  c.total_rounds * 1.0 / NULLIF(d.d_rounds, 0)        AS share_of_rounds,                           -- 市场份额·活动量维度
  c.overall_tail_share,                                                                              -- 该群整体尾段局占比（延续 D-06 既有分析）
  c.avg_rounds_per_member,                                                                           -- 人均局数
  c.min_rounds, c.max_rounds,                                                                        -- 局数分布边界
  c.total_stake,                                                                                     -- 总下注额（流水）
  c.total_valid_bet,                                                                                 -- 总洗码量（营业额，代理返点基准）
  c.total_valid_bet * 1.0 / NULLIF(d.d_valid_bet, 0)  AS share_of_valid_bet,                        -- 市场份额·营业额维度
  c.total_game_pnl,                                                                                  -- 玩家视角游戏净输赢
  c.total_rebate,                                                                                    -- 退水成本
  c.total_net_pnl,                                                                                   -- 玩家视角会员净输赢
  c.total_ggr,                                                                                       -- 毛游戏收入（平台视角，= -Σgame_pnl）
  c.total_ggr * 1.0 / NULLIF(d.d_ggr, 0)              AS share_of_ggr,                              -- 市场份额·毛利润维度
  c.total_ngr,                                                                                       -- 净游戏收入（平台视角，已扣退水成本）
  c.total_ngr * 1.0 / NULLIF(d.d_ngr, 0)              AS share_of_ngr,                              -- 市场份额·净利润维度
  c.total_ggr / NULLIF(c.total_valid_bet, 0)          AS hold_pct_on_valid_bet,                     -- 抽水率口径一：GGR/洗码量（亚洲代理体系常用）
  c.total_ggr / NULLIF(c.total_stake, 0)              AS hold_pct_on_stake,                         -- 抽水率口径二：GGR/下注额（西式 handle 口径）——两口径孰为公司内部标准，须您确认，本文件不擅自裁定
  c.total_ggr / NULLIF(c.n_members, 0)                AS avg_ggr_per_member,                        -- 人均 GGR
  c.total_ggr / NULLIF(c.total_rounds, 0)             AS avg_ggr_per_round,                         -- 局均 GGR（两群相减即「结构性缺口」，详见配套报告模板的方法论边界说明）
  c.total_ngr / NULLIF(c.n_members, 0)                AS avg_ngr_per_member,                        -- 人均 NGR
  c.total_ngr / NULLIF(c.total_rounds, 0)             AS avg_ngr_per_round                          -- 局均 NGR
FROM combined c
CROSS JOIN denom d
ORDER BY CASE c.population WHEN 'S_player_tail' THEN 1 WHEN '非S_player_tail' THEN 2 ELSE 3 END;    -- 固定行序：S 群、非 S 群、合计
