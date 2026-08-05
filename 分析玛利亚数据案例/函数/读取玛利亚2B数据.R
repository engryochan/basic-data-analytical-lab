# --- 生产模式示例（需有权限）
bet <- as.data.table(dbGetQuery(con, "
  SELECT bet05 AS player_id, eid AS dealer_id, 
         CAST(bet13 AS DOUBLE) AS bet_amount,
         CAST(bet14 AS DOUBLE) AS win_amount,
         bet03, bet04, bet08 AS start_time, bet02
  FROM ods_mariadb_2b.ods_a168_bet02
  WHERE dt BETWEEN '2026-03-01' AND '2026-07-24'
    AND bet02 = '101'
"))

# 生产模式：直接从 StarRocks 读取（需权限）
if(!require('BBmisc')) {
  install.packages('BBmisc')
}
if(!require('pacman')) {
  install.packages('pacman')
}
library(BBmisc)
library(pacman)
程序包 <- c('DBI', 'RMariaDB', 'data.table')
lib(程序包)
p_load(程序包)

con <- dbConnect(
  RMariaDB::MariaDB(),
  host     = "202.134.97.145",
  port     = 3306,
  dbname   = "MariaDB_2B",
  user     = "ryochan",
  password = "1hYznzkIywuAcNoL"
)

# 1. 百家乐注单（全量概念，实际按分区拉取）
bet <- as.data.table(dbGetQuery(con, "
  SELECT 
    __source_pk,
    dt,
    bet05 AS player_id,
    eid   AS dealer_id,
    bet02 AS game_type,
    bet03 AS session_id,
    bet04 AS round_id,
    bet08 AS start_time,
    bet09 AS bet_direction,
    CAST(bet11 AS DOUBLE) AS exchange_rate,
    CAST(bet13 AS DOUBLE) AS bet_amount,
    CAST(bet14 AS DOUBLE) AS win_amount,
    CAST(validbet AS DOUBLE) AS valid_bet,
    bet39 AS table_id,
    bet40 AS room_id
  FROM ods_a168_bet02
  WHERE dt BETWEEN '2026-03-01' AND '2026-07-24'
    AND bet02 = '101'   -- 百家乐
"))

# 2. 钱包流水
wallet <- as.data.table(dbGetQuery(con, "
  SELECT 
    user AS player_id,
    CAST(money AS DOUBLE) AS money,
    type,
    status,
    requestDate
  FROM ods_a168_wallet_dtl
  WHERE dt BETWEEN '2026-03-01' AND '2026-07-24'
"))

# 3. 会员主表
member <- as.data.table(dbGetQuery(con, "
  SELECT *
  FROM ods_a168_member
  WHERE dt BETWEEN '2026-03-01' AND '2026-07-24'
"))

dbDisconnect(con)

# 去重（按字典设计）
setorder(bet, -sync_time)
bet <- bet[!duplicated(__source_pk)]

