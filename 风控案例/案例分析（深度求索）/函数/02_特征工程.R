# ============================================================
# 文件：02_特征工程.R
# 用途：基于原始投注数据生成用于建模的特征集
# 作者：OGDIL 实验室
# 日期：2026-07-29
# ============================================================

library(data.table)
library(lubridate)

# 假设已通过数据库连接获取了 ods_a168_bet01 全部数据
# 此处仅展示特征计算逻辑，实际使用时需先读取数据

# 1. 读取数据（示意）
# bet_dt <- fread("ods_a168_bet01.csv")
# 或通过数据库连接读取

# 2. 基础清洗
bet_dt <- bet_dt[bet30 == 'N']  # 仅有效注单
bet_dt[, bet13 := as.numeric(bet13)]  # 金额转数值

# 3. 会员级别特征
member_features <- bet_dt[, .(
  total_bet = sum(bet13, na.rm = TRUE),
  avg_bet = mean(bet13, na.rm = TRUE),
  max_bet = max(bet13, na.rm = TRUE),
  bet_count = .N,
  distinct_dealers = uniqueN(eid),
  distinct_tables = uniqueN(bet31),
  distinct_days = uniqueN(dt),
  first_bet_date = min(dt),
  last_bet_date = max(dt),
  total_profit = sum(bet13 * 0.05, na.rm = TRUE)
), by = bet05]

# 4. 会员最近活跃度（近7天、30天）
last_date <- max(bet_dt$dt)
bet_dt[, days_since := as.numeric(last_date - dt)]
recent_7 <- bet_dt[days_since <= 7, .(bet_7d = .N, bet_amount_7d = sum(bet13)), by = bet05]
recent_30 <- bet_dt[days_since <= 30, .(bet_30d = .N, bet_amount_30d = sum(bet13)), by = bet05]

# 5. 大额异常标记
member_features[, flag_high_bet := ifelse(max_bet > 50000, 1, 0)]
member_features[, flag_freq_high := ifelse(bet_count > 100, 1, 0)]

# 6. 荷官特征
dealer_features <- bet_dt[, .(
  total_bet = sum(bet13, na.rm = TRUE),
  avg_bet = mean(bet13, na.rm = TRUE),
  bet_count = .N,
  unique_players = uniqueN(bet05),
  total_profit = sum(bet13 * 0.05, na.rm = TRUE)
), by = eid]

# 7. 同桌率特征（会员对级别）
# 注意：该计算在数据量大时可能耗时，建议分批或使用SQL
pair_features <- bet_dt[, {
  # 按桌子和日期分组，生成会员对
  .SD[, CJ(bet05, bet05, unique = TRUE), by = .(bet31, dt)]
}, by = .(bet31, dt)]
# 实际实现需优化，此处仅示例

# 8. 保存特征集
fwrite(member_features, "features_member.csv")
fwrite(dealer_features, "features_dealer.csv")
