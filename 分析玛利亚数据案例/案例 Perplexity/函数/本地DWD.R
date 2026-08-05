library(DBI); library(arrow); library(duckdb); library(glue)

con <- dbConnect(odbc::odbc(), "starrocks")   # 或 RMariaDB

sql_tpl <- "
WITH ranked AS (
  SELECT * , ROW_NUMBER() OVER (PARTITION BY bet01
             ORDER BY CAST(updatetime AS DATETIME) DESC) rn
  FROM ods_mariadb_2b.ods_a168_bet01
  WHERE dt >= '{d1}' AND dt < '{d2}' AND bet30 = 'N'
), b AS (SELECT * FROM ranked WHERE rn = 1)
SELECT CAST(bet05 AS INT) member_id, bet07 acct_date,
       CAST(bet02 AS INT) game_type, CAST(bet15 AS INT) lv1_id,
       CAST(bet19 AS INT) lv5_id, CAST(eid AS INT) dealer_id,
       CAST(bet31 AS INT) table_id,
       COUNT(DISTINCT bet01) n_bets,
       SUM(CAST(bet13 AS DECIMAL(16,4))*CAST(bet11 AS DECIMAL(16,4))) turnover_base,
       AVG(CAST(bet13 AS DECIMAL(16,4))*CAST(bet11 AS DECIMAL(16,4))) avg_stake,
       STDDEV_SAMP(CAST(bet13 AS DECIMAL(16,4))*CAST(bet11 AS DECIMAL(16,4))) sd_stake,
       MAX(CAST(bet13 AS DECIMAL(16,4))*CAST(bet11 AS DECIMAL(16,4))) max_stake,
       AVG(CAST(bet14 AS DECIMAL(16,4))) avg_rebate_pct,
       COUNT(DISTINCT ip) n_ip, COUNT(DISTINCT bet31) n_tables,
       MIN(CAST(bet08 AS DATETIME)) first_bet_ts,
       MAX(CAST(bet08 AS DATETIME)) last_bet_ts
FROM b GROUP BY 1,2,3,4,5,6,7"

months <- seq(Sys.Date() - 400, Sys.Date(), by = "month")
dir.create("dwd/member_daily", recursive = TRUE, showWarnings = FALSE)

for (i in seq_len(length(months) - 1)) {
  d1 <- months[i]; d2 <- months[i + 1]
  x <- dbGetQuery(con, glue(sql_tpl))
  write_parquet(x, glue("dwd/member_daily/part-{format(d1,'%Y%m')}.parquet"))
  message(d1, " -> ", nrow(x), " rows")
}

# 本地就有完整可查的"视图"了
dd <- dbConnect(duckdb())
dbExecute(dd, "CREATE VIEW dwd_member_daily AS
               SELECT * FROM read_parquet('dwd/member_daily/*.parquet')")
               