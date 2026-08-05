WITH table_players AS(

SELECT

bet31,

COUNT(DISTINCT bet05) AS players

FROM ods_mariadb_2b.ods_a168_bet01

GROUP BY bet31

)

SELECT

a.bet05,

AVG(players) AS avg_players,

MAX(players) AS max_players

FROM ods_mariadb_2b.ods_a168_bet01 a

JOIN table_players b

ON a.bet31=b.bet31

GROUP BY a.bet05;
