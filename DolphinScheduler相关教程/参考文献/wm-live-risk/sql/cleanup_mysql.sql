DELETE FROM business_risk_late_bet_stat
WHERE as_of_time < DATE_SUB(
        CURRENT_TIMESTAMP,
        INTERVAL ${BUSINESS_RISK_SNAPSHOT_RETENTION_DAYS} DAY
      )
  AND as_of_time <> (
      SELECT ready_as_of_time
      FROM (
          SELECT as_of_time AS ready_as_of_time
          FROM business_risk_publish_state
          WHERE dataset_name = 'BACCARAT_BUSINESS_RISK'
            AND publish_status = 'READY'
      ) AS ready_version
  );

DELETE FROM business_risk_same_table_pair_stat
WHERE as_of_time < DATE_SUB(
        CURRENT_TIMESTAMP,
        INTERVAL ${BUSINESS_RISK_SNAPSHOT_RETENTION_DAYS} DAY
      )
  AND as_of_time <> (
      SELECT ready_as_of_time
      FROM (
          SELECT as_of_time AS ready_as_of_time
          FROM business_risk_publish_state
          WHERE dataset_name = 'BACCARAT_BUSINESS_RISK'
            AND publish_status = 'READY'
      ) AS ready_version
  );

DELETE FROM business_risk_player_dealer_stat
WHERE as_of_time < DATE_SUB(
        CURRENT_TIMESTAMP,
        INTERVAL ${BUSINESS_RISK_SNAPSHOT_RETENTION_DAYS} DAY
      )
  AND as_of_time <> (
      SELECT ready_as_of_time
      FROM (
          SELECT as_of_time AS ready_as_of_time
          FROM business_risk_publish_state
          WHERE dataset_name = 'BACCARAT_BUSINESS_RISK'
            AND publish_status = 'READY'
      ) AS ready_version
  );
