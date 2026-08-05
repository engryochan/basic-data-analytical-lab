SELECT bet05 AS player_id, eid AS dealer_id, 
         CAST(bet13 AS DOUBLE) AS bet_amount,
         CAST(bet14 AS DOUBLE) AS win_amount,
         bet03, bet04, bet08 AS start_time, bet02
  FROM ods_mariadb_2b.ods_a168_bet02
  WHERE dt BETWEEN '2026-03-01' AND '2026-07-24'
    AND bet02 = '101'
    