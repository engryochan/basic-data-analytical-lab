SELECT

bet05,

COUNT(DISTINCT ip) AS ip_count,

COUNT(*) AS bets,

COUNT(*)/
NULLIF(COUNT(DISTINCT ip),0) AS bets_per_ip

FROM ods_mariadb_2b.ods_a168_bet01

GROUP BY bet05;
