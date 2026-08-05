plot_player_network <- function(dt) {
  edges <- dt[risk_score >= 50, .(player_a, player_b, weight = same_round_count)]
  g <- graph_from_data_frame(edges, directed = FALSE)
  plot(g, vertex.size = 5, edge.width = E(g)$weight / 10, 
       main = "高风险玩家同桌网络")
}

plot_risk_distribution <- function(dt) {
  ggplot(dt, aes(x = risk_score, fill = risk_level)) +
    geom_histogram(bins = 30) +
    theme_minimal() +
    labs(title = "风险分数分布", x = "风险分数", y = "频次")
}

plot_time_trend <- function(dt_h) {
  ggplot(dt_h[, .(count = .N), by = .(date = as.Date(last_game_time))], 
         aes(x = date, y = count)) +
    geom_line(color = "steelblue") +
    theme_minimal()
}