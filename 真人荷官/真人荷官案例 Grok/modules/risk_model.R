calculate_risk_scores <- function(dt) {
  dt[, risk_score := 
       same_round_count * 0.4 + 
       same_rate * 35 + 
       as.numeric(difftime(last_game_time, first_game_time, units = "days")) * 0.25]
  
  dt[, risk_level := fcase(
    risk_score >= 85, "极高风险",
    risk_score >= 70, "高风险",
    risk_score >= 50, "中风险",
    default = "低风险"
  )]
  dt
}
