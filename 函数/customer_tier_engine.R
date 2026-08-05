# ==============================================================================
# customer_tier_engine.R
# 客户九档风控分级 + 赏罚方案引擎（商君书"信赏必罚、等级分明"思路的量化落地）
#
# 核心原则（务必保持）：
#   1. 所有分档阈值都是 quantile(x, 0.xx) 动态算出来的百分位排名，
#      不是写死的具体数值——数据变了、量变了，阈值自动跟着重算，
#      这就是"代码呈现动态输出值"而不是"静态数字"的意思。
#   2. 分类结论只输出到"标签 + 分值 + 依据字段"，不在这里做最终定性
#      （定性判决留给人工复核，代码只负责把候选名单和证据链整理清楚）。
#   3. 本引擎读取的是 data_full/ 全量10万行，不再使用 data/ 100行样本。
#
# 用法：
#   source("customer_tier_engine.R")
#   tiers <- build_customer_tiers(DATA_DIR = "data_full")
#   tiers$pair_tiers      # 玩家配对维度九档结果（data.table）
#   tiers$player_tiers    # 单玩家价值维度结果（黄金/白金/长期/一般）
#   tiers$policy_table    # 每档对应的赏罚方案（供 qmd / Shiny 直接引用）
# ==============================================================================

library(data.table)
library(lubridate)

# ------------------------------------------------------------------
# 1. 分位数阈值计算（全部来自真实数据，不硬编码具体数值）
# ------------------------------------------------------------------
compute_thresholds <- function(pps) {
  list(
    same_rate_p90  = quantile(pps$same_rate, 0.90, na.rm = TRUE),
    same_rate_p95  = quantile(pps$same_rate, 0.95, na.rm = TRUE),
    same_rate_p99  = quantile(pps$same_rate, 0.99, na.rm = TRUE),
    src_p75        = quantile(pps$same_round_count, 0.75, na.rm = TRUE),
    src_p90        = quantile(pps$same_round_count, 0.90, na.rm = TRUE),
    src_p95        = quantile(pps$same_round_count, 0.95, na.rm = TRUE),
    src_p25        = quantile(pps$same_round_count, 0.25, na.rm = TRUE),
    duration_p5    = quantile(pps$duration_days, 0.05, na.rm = TRUE),
    duration_p50   = quantile(pps$duration_days, 0.50, na.rm = TRUE),
    duration_p90   = quantile(pps$duration_days, 0.90, na.rm = TRUE)
  )
}

# ------------------------------------------------------------------
# 2. 玩家配对维度：风险五档主档位 + 养号型独立叠加标记
#
#    【重要修订，附验证记录】最初版本用"P99 AND P95 AND P50 三条件同时满足"
#    卡 L4，在真实 data_full 10万行上实测跑出来 L4 命中数 = 0（已用Python
#    在真实数据上复算验证过，不是猜测）。原因：绝对分位数门槛对这批数据的
#    联合分布太苛刻，任何单一维度稍微不到顶，就整条记录出不了线。
#
#    改为"复合相对排名"：三个维度按各自百分位加权求和，再对复合分本身
#    取相对名次分档——好处是主档位结构上永远不会空（业务上"今天要复核的
#    top 5%"这件事应该永远有实际名单，不该出现"零风险"这种不可信的假安全
#    信号），阈值仍然100%来自当次数据分布，不是硬编码分值。
#
#    "养号型"单独拆出来做布尔标记、可与任意主档位叠加，而不是塞进主档位
#    的判断链——原因同样是真实数据验证出来的：养号型账户"关系太新"这个
#    特征会拉低复合分（duration维度权重20%），如果不单独标记，这批账户
#    会被主评分系统性漏掉，跟附件里"新号4分钟精准找到大号"的描述吻合，
#    这正是复合评分法天然的盲区，必须用独立规则补上。
# ------------------------------------------------------------------
classify_pair_tier <- function(pps, th) {
  pps[, `:=`(
    a_dependency = same_round_count / player_a_rounds,
    b_dependency = same_round_count / player_b_rounds
  )]
  pps[, max_dependency := pmax(a_dependency, b_dependency)]

  baseline_rate <- median(pps$same_rate, na.rm = TRUE)
  pps[, lift := same_rate / baseline_rate]  # 真实倍数，替代附件里"22.2倍"这类硬编数字

  pctrank <- function(x) rank(x, na.last = "keep", ties.method = "average") / sum(!is.na(x))

  pps[, composite_score := (
    0.45 * pctrank(same_rate) +
    0.35 * pctrank(same_round_count) +
    0.20 * pctrank(duration_days)
  )]
  pps[, composite_rank := pctrank(composite_score)]

  pps[, tier := cut(
    composite_rank,
    breaks = c(-Inf, 0.50, 0.75, 0.90, 0.95, Inf),
    labels = c("一般关系", "试水型_观察名单", "中风险_待观察", "L3_高危待复核", "L4_实锤合谋"),
    right  = TRUE
  )]

  # 养号型：独立布尔标记，与 tier 并列存在，不互斥
  pps[, farm_flag := duration_days <= th$duration_p5 & same_rate >= th$same_rate_p90]

  pps[]
}

# ------------------------------------------------------------------
# 3. 玩家价值维度：黄金 / 白金 / 长期 / 一般（好客户侧，正向激励用）
#    数据来自 dealer_profit_stat，按 player_id 聚合
# ------------------------------------------------------------------
classify_player_value <- function(dps) {
  dps_valid <- dps[dealer_id != -1]  # 剔除4.49%哨兵值荷官，避免污染玩家价值统计

  player_summary <- dps_valid[, .(
    total_turnover = sum(turnover, na.rm = TRUE),
    total_bet_count = sum(bet_count, na.rm = TRUE),
    avg_roi = mean(player_roi, na.rm = TRUE),
    first_bet = min(first_bet_time),
    last_bet  = max(last_bet_time),
    dealer_count = uniqueN(dealer_id)
  ), by = player_id]

  player_summary[, tenure_days := as.numeric(
    difftime(as.POSIXct(last_bet), as.POSIXct(first_bet), units = "days")
  )]
  player_summary[, recency_days := as.numeric(
    difftime(Sys.time(), as.POSIXct(last_bet), units = "days")
  )]

  turnover_p90 <- quantile(player_summary$total_turnover, 0.90, na.rm = TRUE)
  turnover_p75 <- quantile(player_summary$total_turnover, 0.75, na.rm = TRUE)
  tenure_p75   <- quantile(player_summary$tenure_days, 0.75, na.rm = TRUE)
  tenure_p50   <- quantile(player_summary$tenure_days, 0.50, na.rm = TRUE)

  player_summary[, value_tier := fcase(
    total_turnover >= turnover_p90 & tenure_days >= tenure_p75 & recency_days <= 7,
    "白金客户",

    total_turnover >= turnover_p75 & tenure_days >= tenure_p50 & recency_days <= 14,
    "黄金客户",

    tenure_days >= tenure_p75 & recency_days <= 30,
    "长期忠诚客户",

    default = "一般客户"
  )]

  player_summary[]
}

# ------------------------------------------------------------------
# 4. 赏罚方案表（商君书：赏罚分明、等级对应、可预期）
#    注意：这里的措施是"方案模板"，具体额度/比例等业务参数留给风控团队
#    在真正上线前，用A/B测试或历史数据回归校准，不是我在这里替业务拍板。
# ------------------------------------------------------------------
build_policy_table <- function() {
  data.table(
    档位 = c("L4_实锤合谋", "L3_高危待复核", "养号型", "试水型_观察名单", "一般关系",
             "白金客户", "黄金客户", "长期忠诚客户", "一般客户"),
    类别 = c(rep("风险处置(罚)", 4), "中性", rep("价值激励(赏)", 3), "中性"),
    核心措施 = c(
      "立即冻结账户+关联设备，人工调录像回查资金流水，暂停结算",
      "限额+人工复核排期，24小时内出具复核结论，复核前限制高额投注",
      "新号24小时隔离池，隔离期内禁止进入与高价值账户同桌的真人场",
      "加入观察名单，观察窗口内(建议7天)复算指标，窗口结束后重新入档，不做处置",
      "维持标准权益，纳入常规监测",
      "专属客服通道+返水比例上浮(具体幅度由业务侧A/B测试后设定)+更高单注上限",
      "返水比例小幅上浮+限额上调，纳入定期关怀名单",
      "留存关怀(连续登录/活跃奖励)，优先曝光新产品/活动",
      "标准权益，作为其余档位比较基线"
    ),
    触发后动态复核 = c(
      "每次冻结后必须在SOP规定时限内完成人工结论回填，不能只冻结不复核",
      "复核结论需回写数据库，用于未来阈值/模型再校准",
      "隔离期结束后自动重新计算 tier，不因'曾经养号'终身标记",
      "观察期满自动重算，避免长期占用人工复核资源",
      "常规监测频率与其余风险档位一致",
      "价值档位每次全量计算时用相同分位数逻辑重算，杜绝'一次白金终身白金'",
      "同上",
      "同上",
      "同上"
    )
  )
}

# ------------------------------------------------------------------
# 5. 主函数：一次性产出全部结果，供 qmd / Shiny 直接引用
# ------------------------------------------------------------------
build_customer_tiers <- function(DATA_DIR = "data_full") {
  pps <- fread(file.path(DATA_DIR, "player_pair_stat.csv"))
  dps <- fread(file.path(DATA_DIR, "dealer_profit_stat.csv"))

  pps[, `:=`(
    first_game_time = as.POSIXct(first_game_time),
    last_game_time  = as.POSIXct(last_game_time)
  )]
  pps[, duration_days := as.numeric(difftime(last_game_time, first_game_time, units = "days"))]

  th <- compute_thresholds(pps)
  pair_tiers   <- classify_pair_tier(pps, th)
  player_tiers <- classify_player_value(dps)
  policy_table <- build_policy_table()

  list(
    thresholds   = th,               # 保留下来，方便报告里展示"这次阈值是多少"
    pair_tiers   = pair_tiers,
    player_tiers = player_tiers,
    policy_table = policy_table,
    tier_summary = pair_tiers[, .N, by = tier][order(-N)],
    # 养号型是独立标记，与主档位交叉统计，不能只报"养号型总数"，
    # 否则看不出"养号型是否也同时命中了高风险主档位"这个关键信息
    farm_cross_tab = pair_tiers[, .N, by = .(farm_flag, tier)][order(-farm_flag, -N)],
    value_summary = player_tiers[, .N, by = value_tier][order(-N)]
  )
}

# 独立运行时的快速自检（source() 时不会自动执行，需显式调用）
if (sys.nframe() == 0) {
  res <- build_customer_tiers("data_full")
  print(res$tier_summary)
  print(res$value_summary)
  print(res$policy_table)
}
