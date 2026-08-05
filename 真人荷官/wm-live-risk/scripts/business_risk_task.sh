#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=risk_report_common.sh
source "$SCRIPT_DIR/risk_report_common.sh"

DRY_RUN=false
BUSINESS_RISK_TEMP_FILES=()

cleanup_business_risk_temp_files() {
  local file
  for file in "${BUSINESS_RISK_TEMP_FILES[@]:-}"; do
    [[ -n "$file" ]] && rm -f -- "$file"
  done
  return 0
}
trap cleanup_business_risk_temp_files EXIT

usage() {
  cat <<'USAGE'
Usage:
  business_risk_task.sh [--dry-run] <command>

Commands:
  validate-parameters
  validate-starrocks
  publish-late-bet
  publish-same-table
  publish-player-dealer
  validate-mysql
USAGE
}

die() {
  echo "ERROR: $*" >&2
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    -*)
      die "Unknown option: $1"
      ;;
    *)
      break
      ;;
  esac
done

[[ $# -eq 1 ]] || {
  usage >&2
  exit 2
}
COMMAND="$1"

risk_report_load_env "$PROJECT_ROOT"

BUSINESS_RISK_LOOKBACK_DAYS="${BUSINESS_RISK_LOOKBACK_DAYS-30}"
BUSINESS_RISK_SNAPSHOT_RETENTION_DAYS="${BUSINESS_RISK_SNAPSHOT_RETENTION_DAYS-7}"
BUSINESS_RISK_SOURCE_DATABASE="${BUSINESS_RISK_SOURCE_DATABASE-ods_mariadb_2b}"
BUSINESS_RISK_TARGET_DATABASE="${BUSINESS_RISK_TARGET_DATABASE-wm_live_risk}"
BUSINESS_RISK_SOURCE_BET01="${BUSINESS_RISK_SOURCE_BET01-ods_a168_bet01}"
BUSINESS_RISK_SOURCE_BET02="${BUSINESS_RISK_SOURCE_BET02-ods_a168_bet02}"
BUSINESS_RISK_LATE_SUB_ROUND_MIN="${BUSINESS_RISK_LATE_SUB_ROUND_MIN-40}"
BUSINESS_RISK_LATE_ORDER_RATE_MIN="${BUSINESS_RISK_LATE_ORDER_RATE_MIN-0.60}"
BUSINESS_RISK_LATE_ORDER_COUNT_MIN_EXCLUSIVE="${BUSINESS_RISK_LATE_ORDER_COUNT_MIN_EXCLUSIVE-50}"
BUSINESS_RISK_SAME_ROUND_COUNT_MIN="${BUSINESS_RISK_SAME_ROUND_COUNT_MIN-100}"
BUSINESS_RISK_SAME_RATE_MIN="${BUSINESS_RISK_SAME_RATE_MIN-0.20}"
BUSINESS_RISK_OPPOSITE_RATE_MIN="${BUSINESS_RISK_OPPOSITE_RATE_MIN-0.70}"
BUSINESS_RISK_PLAYER_DEALER_WIN_RATE_MIN_EXCLUSIVE="${BUSINESS_RISK_PLAYER_DEALER_WIN_RATE_MIN_EXCLUSIVE-0.65}"
BUSINESS_RISK_PLAYER_DEALER_ORDER_COUNT_MIN_EXCLUSIVE="${BUSINESS_RISK_PLAYER_DEALER_ORDER_COUNT_MIN_EXCLUSIVE-30}"

validate_identifier() {
  local name="$1"
  local value="$2"
  [[ "$value" =~ ^[A-Za-z0-9_]+$ ]] || die "$name contains an unsafe identifier: $value"
}

validate_rate_threshold() {
  local name="$1"
  local value="$2"
  risk_report_validate_number "$name" "$value"
  awk -v value="$value" 'BEGIN { exit !(value >= 0 && value <= 1) }' || \
    die "$name must be between 0 and 1"
}

prepare_parameters() {
  : "${AS_OF_TIME:?AS_OF_TIME is required}"
  risk_report_validate_time "AS_OF_TIME" "$AS_OF_TIME"
  risk_report_validate_positive_int "BUSINESS_RISK_LOOKBACK_DAYS" "$BUSINESS_RISK_LOOKBACK_DAYS"
  risk_report_validate_positive_int \
    "BUSINESS_RISK_SNAPSHOT_RETENTION_DAYS" \
    "$BUSINESS_RISK_SNAPSHOT_RETENTION_DAYS"
  (( BUSINESS_RISK_LOOKBACK_DAYS <= 3650 )) || \
    die "BUSINESS_RISK_LOOKBACK_DAYS must be between 1 and 3650"
  (( BUSINESS_RISK_SNAPSHOT_RETENTION_DAYS <= 365 )) || \
    die "BUSINESS_RISK_SNAPSHOT_RETENTION_DAYS must be between 1 and 365"

  risk_report_validate_positive_int \
    "BUSINESS_RISK_LATE_SUB_ROUND_MIN" \
    "$BUSINESS_RISK_LATE_SUB_ROUND_MIN"
  risk_report_validate_positive_int \
    "BUSINESS_RISK_LATE_ORDER_COUNT_MIN_EXCLUSIVE" \
    "$BUSINESS_RISK_LATE_ORDER_COUNT_MIN_EXCLUSIVE"
  risk_report_validate_positive_int \
    "BUSINESS_RISK_SAME_ROUND_COUNT_MIN" \
    "$BUSINESS_RISK_SAME_ROUND_COUNT_MIN"
  risk_report_validate_positive_int \
    "BUSINESS_RISK_PLAYER_DEALER_ORDER_COUNT_MIN_EXCLUSIVE" \
    "$BUSINESS_RISK_PLAYER_DEALER_ORDER_COUNT_MIN_EXCLUSIVE"
  validate_rate_threshold \
    "BUSINESS_RISK_LATE_ORDER_RATE_MIN" \
    "$BUSINESS_RISK_LATE_ORDER_RATE_MIN"
  validate_rate_threshold \
    "BUSINESS_RISK_SAME_RATE_MIN" \
    "$BUSINESS_RISK_SAME_RATE_MIN"
  validate_rate_threshold \
    "BUSINESS_RISK_OPPOSITE_RATE_MIN" \
    "$BUSINESS_RISK_OPPOSITE_RATE_MIN"
  validate_rate_threshold \
    "BUSINESS_RISK_PLAYER_DEALER_WIN_RATE_MIN_EXCLUSIVE" \
    "$BUSINESS_RISK_PLAYER_DEALER_WIN_RATE_MIN_EXCLUSIVE"

  validate_identifier "BUSINESS_RISK_SOURCE_DATABASE" "$BUSINESS_RISK_SOURCE_DATABASE"
  validate_identifier "BUSINESS_RISK_TARGET_DATABASE" "$BUSINESS_RISK_TARGET_DATABASE"
  validate_identifier "BUSINESS_RISK_SOURCE_BET01" "$BUSINESS_RISK_SOURCE_BET01"
  validate_identifier "BUSINESS_RISK_SOURCE_BET02" "$BUSINESS_RISK_SOURCE_BET02"

  local calculated_window_start
  calculated_window_start="$(
    TZ=Asia/Shanghai date -d \
      "$AS_OF_TIME $BUSINESS_RISK_LOOKBACK_DAYS days ago" \
      '+%Y-%m-%d %H:%M:%S'
  )" || die "Failed to calculate WINDOW_START"

  WINDOW_START="${WINDOW_START:-$calculated_window_start}"
  WINDOW_END="${WINDOW_END:-$AS_OF_TIME}"
  [[ "$WINDOW_START" == "$calculated_window_start" ]] || \
    die "WINDOW_START must equal AS_OF_TIME minus BUSINESS_RISK_LOOKBACK_DAYS"
  [[ "$WINDOW_END" == "$AS_OF_TIME" ]] || die "WINDOW_END must equal AS_OF_TIME"
  risk_report_validate_window "$WINDOW_START" "$WINDOW_END"

  export WINDOW_START WINDOW_END \
    BUSINESS_RISK_LATE_SUB_ROUND_MIN \
    BUSINESS_RISK_LATE_ORDER_RATE_MIN \
    BUSINESS_RISK_LATE_ORDER_COUNT_MIN_EXCLUSIVE \
    BUSINESS_RISK_SAME_ROUND_COUNT_MIN \
    BUSINESS_RISK_SAME_RATE_MIN \
    BUSINESS_RISK_OPPOSITE_RATE_MIN \
    BUSINESS_RISK_PLAYER_DEALER_WIN_RATE_MIN_EXCLUSIVE \
    BUSINESS_RISK_PLAYER_DEALER_ORDER_COUNT_MIN_EXCLUSIVE
}

print_context() {
  printf 'as_of_time=%s\n' "$AS_OF_TIME"
  printf 'window_start=%s\n' "$WINDOW_START"
  printf 'window_end=%s\n' "$WINDOW_END"
  printf 'lookback_days=%s\n' "$BUSINESS_RISK_LOOKBACK_DAYS"
  printf 'late_sub_round_min=%s\n' "$BUSINESS_RISK_LATE_SUB_ROUND_MIN"
  printf 'late_order_rate_min=%s\n' "$BUSINESS_RISK_LATE_ORDER_RATE_MIN"
  printf 'late_order_count_min_exclusive=%s\n' \
    "$BUSINESS_RISK_LATE_ORDER_COUNT_MIN_EXCLUSIVE"
  printf 'same_round_count_min=%s\n' "$BUSINESS_RISK_SAME_ROUND_COUNT_MIN"
  printf 'same_rate_min=%s\n' "$BUSINESS_RISK_SAME_RATE_MIN"
  printf 'opposite_rate_min=%s\n' "$BUSINESS_RISK_OPPOSITE_RATE_MIN"
  printf 'player_dealer_win_rate_min_exclusive=%s\n' \
    "$BUSINESS_RISK_PLAYER_DEALER_WIN_RATE_MIN_EXCLUSIVE"
  printf 'player_dealer_order_count_min_exclusive=%s\n' \
    "$BUSINESS_RISK_PLAYER_DEALER_ORDER_COUNT_MIN_EXCLUSIVE"
}

init_connections() {
  risk_report_init_starrocks
  risk_report_init_api_mysql
}

run_scalar_equals() {
  local profile="$1"
  local label="$2"
  local query="$3"
  local expected="$4"
  local actual
  actual="$(risk_report_query_scalar "$profile" "$query")" || return
  [[ "$actual" == "$expected" ]] || \
    die "$label: expected $expected, got $actual"
}

validate_parameters() {
  local starrocks_tables api_tables ready_cutoff max_players multi_dealer
  starrocks_tables="
SELECT COUNT(*)
FROM information_schema.tables
WHERE (table_schema = '$BUSINESS_RISK_SOURCE_DATABASE'
       AND table_name IN ('$BUSINESS_RISK_SOURCE_BET01', '$BUSINESS_RISK_SOURCE_BET02'))
   OR (table_schema = '$BUSINESS_RISK_TARGET_DATABASE'
       AND table_name IN (
         'business_risk_late_bet_snapshot',
         'business_risk_same_table_pair_snapshot',
         'business_risk_player_dealer_snapshot'
       ));"
  api_tables="
SELECT COUNT(*)
FROM information_schema.tables
WHERE table_schema = DATABASE()
  AND table_name IN (
    'business_risk_late_bet_stat',
    'business_risk_same_table_pair_stat',
    'business_risk_player_dealer_stat',
    'business_risk_publish_state'
  );"
  ready_cutoff="
SELECT COALESCE(
  DATE_FORMAT(
    MAX(CASE
      WHEN dataset_name = 'BACCARAT_BUSINESS_RISK'
       AND publish_status = 'READY'
      THEN as_of_time
    END),
    '%Y-%m-%d %H:%i:%s'
  ),
  'NONE'
)
FROM business_risk_publish_state;"

  max_players="
WITH ranked AS (
  SELECT
    CAST(bet01 AS BIGINT) AS bet_id,
    CAST(bet03 AS BIGINT) AS round_id,
    CAST(bet04 AS INT) AS sub_round_id,
    CAST(bet31 AS BIGINT) AS table_id,
    CAST(bet05 AS BIGINT) AS player_id,
    ROW_NUMBER() OVER (
      PARTITION BY CAST(bet01 AS BIGINT)
      ORDER BY CAST(updatetime AS DATETIME) DESC,
               CAST(sync_time AS DATETIME) DESC,
               CAST(dt AS DATE) DESC
    ) AS row_num
  FROM $BUSINESS_RISK_SOURCE_DATABASE.$BUSINESS_RISK_SOURCE_BET01
  WHERE CAST(dt AS DATE) >= DATE_SUB(DATE('$WINDOW_START'), INTERVAL 1 DAY)
    AND CAST(dt AS DATE) < DATE_ADD(DATE('$WINDOW_END'), INTERVAL 1 DAY)
    AND CAST(bet08 AS DATETIME) >= TIMESTAMP('$WINDOW_START')
    AND CAST(bet08 AS DATETIME) < TIMESTAMP('$WINDOW_END')
    AND CAST(bet02 AS INT) = 101
    AND CAST(category AS INT) = 1
    AND UPPER(TRIM(CAST(bet30 AS STRING))) = 'N'
    AND CAST(bet03 AS BIGINT) > 0
    AND CAST(bet31 AS BIGINT) > 0
    AND CAST(bet05 AS BIGINT) > 0
    AND CAST(bet13 AS DECIMAL(38,8)) > 0
),
round_populations AS (
  SELECT round_id, sub_round_id, table_id, COUNT(DISTINCT player_id) AS player_count
  FROM ranked
  WHERE row_num = 1
  GROUP BY round_id, sub_round_id, table_id
)
SELECT COALESCE(MAX(player_count), 0)
FROM round_populations;"

  multi_dealer="
WITH ranked AS (
  SELECT
    CAST(bet01 AS BIGINT) AS bet_id,
    CAST(bet03 AS BIGINT) AS round_id,
    CAST(bet04 AS INT) AS sub_round_id,
    CAST(bet39 AS BIGINT) AS table_id,
    CAST(bet05 AS BIGINT) AS player_id,
    CAST(eid AS BIGINT) AS dealer_id,
    CAST(bet02 AS INT) AS game_type,
    CAST(category AS INT) AS category,
    UPPER(TRIM(CAST(bet38 AS STRING))) AS regrade_flag,
    CAST(bet11 AS DECIMAL(38,8)) AS exchange_rate,
    ROW_NUMBER() OVER (
      PARTITION BY CAST(bet01 AS BIGINT)
      ORDER BY CAST(updatetime AS DATETIME) DESC,
               CAST(sync_time AS DATETIME) DESC,
               CAST(dt AS DATE) DESC
    ) AS row_num
  FROM $BUSINESS_RISK_SOURCE_DATABASE.$BUSINESS_RISK_SOURCE_BET02
  WHERE CAST(dt AS DATE) >= DATE_SUB(DATE('$WINDOW_START'), INTERVAL 1 DAY)
    AND CAST(dt AS DATE) < DATE_ADD(DATE('$WINDOW_END'), INTERVAL 1 DAY)
    AND CAST(bet08 AS DATETIME) >= TIMESTAMP('$WINDOW_START')
    AND CAST(bet08 AS DATETIME) < TIMESTAMP('$WINDOW_END')
),
valid_orders AS (
  SELECT round_id, sub_round_id, table_id, player_id, dealer_id
  FROM ranked
  WHERE row_num = 1
    AND game_type = 101
    AND category = 1
    AND regrade_flag = 'N'
    AND round_id > 0
    AND table_id > 0
    AND player_id > 0
    AND dealer_id > 0
    AND exchange_rate > CAST(0 AS DECIMAL(38,8))
),
invalid_rounds AS (
  SELECT round_id, sub_round_id, table_id, player_id
  FROM valid_orders
  GROUP BY round_id, sub_round_id, table_id, player_id
  HAVING COUNT(DISTINCT dealer_id) <> 1
)
SELECT COUNT(*)
FROM invalid_rounds;"

  if [[ "$DRY_RUN" == true ]]; then
    print_context
    printf '\n-- STARROCKS REQUIRED TABLES\n%s\n' "$starrocks_tables"
    printf '\n-- API MYSQL REQUIRED TABLES\n%s\n' "$api_tables"
    printf '\n-- CURRENT READY CUTOFF\n%s\n' "$ready_cutoff"
    printf '\n-- MAX PLAYERS PER ROUND\n%s\n' "$max_players"
    printf '\n-- MULTI-DEALER PLAYER ROUNDS\n%s\n' "$multi_dealer"
    return
  fi

  init_connections
  run_scalar_equals "STARROCKS" "required StarRocks table count" "$starrocks_tables" "5"
  run_scalar_equals "API_MYSQL" "required API MySQL table count" "$api_tables" "4"

  local current_ready
  current_ready="$(risk_report_query_scalar "API_MYSQL" "$ready_cutoff")"
  [[ "$current_ready" == "NONE" || "$AS_OF_TIME" > "$current_ready" ]] || \
    die "AS_OF_TIME must be later than current READY cutoff $current_ready"

  max_players="$(risk_report_query_scalar "STARROCKS" "$max_players")"
  [[ "$max_players" =~ ^[0-9]+$ ]] || die "Invalid maximum player count: $max_players"
  (( max_players <= 500 )) || die "A physical round has more than 500 players: $max_players"

  multi_dealer="$(risk_report_query_scalar "STARROCKS" "$multi_dealer")"
  [[ "$multi_dealer" =~ ^[0-9]+$ ]] || \
    die "Invalid ambiguous player-round count: $multi_dealer"
  printf 'excluded_ambiguous_player_rounds=%s\n' "$multi_dealer"
}

starrocks_validation_sql() {
  cat <<SQL
SELECT SUM(invalid_count)
FROM (
  SELECT COUNT(*) AS invalid_count
  FROM $BUSINESS_RISK_TARGET_DATABASE.business_risk_late_bet_snapshot
  WHERE as_of_time = TIMESTAMP('$AS_OF_TIME')
    AND (
      late_order_count <= $BUSINESS_RISK_LATE_ORDER_COUNT_MIN_EXCLUSIVE
      OR total_order_count < late_order_count
      OR late_order_rate < CAST($BUSINESS_RISK_LATE_ORDER_RATE_MIN AS DECIMAL(9,6))
      OR late_order_rate > CAST(1 AS DECIMAL(9,6))
    )
  UNION ALL
  SELECT COUNT(*) AS invalid_count
  FROM $BUSINESS_RISK_TARGET_DATABASE.business_risk_same_table_pair_snapshot
  WHERE as_of_time = TIMESTAMP('$AS_OF_TIME')
    AND (
      player_a >= player_b
      OR same_round_count < $BUSINESS_RISK_SAME_ROUND_COUNT_MIN
      OR same_rate < 0
      OR same_rate > 1
      OR opposite_rate < 0
      OR opposite_rate > 1
      OR opposite_round_count < 0
      OR opposite_round_count > same_round_count
      OR same_rate < CAST($BUSINESS_RISK_SAME_RATE_MIN AS DECIMAL(9,6))
      OR opposite_rate < CAST($BUSINESS_RISK_OPPOSITE_RATE_MIN AS DECIMAL(9,6))
    )
  UNION ALL
  SELECT COUNT(*) AS invalid_count
  FROM $BUSINESS_RISK_TARGET_DATABASE.business_risk_player_dealer_snapshot
  WHERE as_of_time = TIMESTAMP('$AS_OF_TIME')
    AND (
      player_overall_net_profit <= 0
      OR win_rate <= CAST($BUSINESS_RISK_PLAYER_DEALER_WIN_RATE_MIN_EXCLUSIVE AS DECIMAL(9,6))
      OR win_rate > 1
      OR order_count <= $BUSINESS_RISK_PLAYER_DEALER_ORDER_COUNT_MIN_EXCLUSIVE
      OR round_count <> win_count + lose_count + push_count
    )
) violations;
SQL
}

snapshot_count_sql() {
  local store="$1"
  local table="$2"
  if [[ "$store" == "STARROCKS" ]]; then
    printf "SELECT COUNT(*) FROM %s.%s WHERE as_of_time = TIMESTAMP('%s');" \
      "$BUSINESS_RISK_TARGET_DATABASE" "$table" "$AS_OF_TIME"
  else
    printf "SELECT COUNT(*) FROM %s WHERE as_of_time = '%s';" "$table" "$AS_OF_TIME"
  fi
}

validate_starrocks() {
  local validation counts
  validation="$(starrocks_validation_sql)"
  if [[ "$DRY_RUN" == true ]]; then
    print_context
    printf '\n-- STARROCKS SNAPSHOT VALIDATION\n%s\n' "$validation"
    return
  fi

  risk_report_init_starrocks
  run_scalar_equals "STARROCKS" "StarRocks invariant violations" "$validation" "0"
  counts="$(
    printf '%s:%s:%s' \
      "$(risk_report_query_scalar STARROCKS "$(
        snapshot_count_sql STARROCKS business_risk_late_bet_snapshot
      )")" \
      "$(risk_report_query_scalar STARROCKS "$(
        snapshot_count_sql STARROCKS business_risk_same_table_pair_snapshot
      )")" \
      "$(risk_report_query_scalar STARROCKS "$(
        snapshot_count_sql STARROCKS business_risk_player_dealer_snapshot
      )")"
  )"
  printf 'starrocks_row_counts=%s\n' "$counts"
}

dataset_contract() {
  local command="$1"
  case "$command" in
    publish-late-bet)
      SOURCE_TABLE="business_risk_late_bet_snapshot"
      TARGET_TABLE="business_risk_late_bet_stat"
      ;;
    publish-same-table)
      SOURCE_TABLE="business_risk_same_table_pair_snapshot"
      TARGET_TABLE="business_risk_same_table_pair_stat"
      ;;
    publish-player-dealer)
      SOURCE_TABLE="business_risk_player_dealer_snapshot"
      TARGET_TABLE="business_risk_player_dealer_stat"
      ;;
    *)
      die "Unsupported publication command: $command"
      ;;
  esac
}

nullable_datetime_sql() {
  local column="$1"
  printf "IF(%s IS NULL, 'NULL', CONCAT('''', DATE_FORMAT(%s, '%%Y-%%m-%%d %%H:%%i:%%s'), ''''))" \
    "$column" "$column"
}

export_query_for() {
  local table="$1"
  case "$table" in
    business_risk_late_bet_stat)
      cat <<SQL
SELECT CONCAT(
  'INSERT INTO business_risk_late_bet_stat (as_of_time,player_id,window_start,window_end,late_order_count,total_order_count,late_order_rate,first_bet_time,last_bet_time,created_time) VALUES (',
  '''', DATE_FORMAT(as_of_time, '%Y-%m-%d %H:%i:%s'), ''',',
  CAST(player_id AS STRING), ',',
  '''', DATE_FORMAT(window_start, '%Y-%m-%d %H:%i:%s'), ''',',
  '''', DATE_FORMAT(window_end, '%Y-%m-%d %H:%i:%s'), ''',',
  CAST(late_order_count AS STRING), ',',
  CAST(total_order_count AS STRING), ',',
  CAST(late_order_rate AS STRING), ',',
  $(nullable_datetime_sql first_bet_time), ',',
  $(nullable_datetime_sql last_bet_time), ',',
  '''', DATE_FORMAT(created_time, '%Y-%m-%d %H:%i:%s'), ''');'
) AS statement
FROM $BUSINESS_RISK_TARGET_DATABASE.business_risk_late_bet_snapshot
WHERE as_of_time = TIMESTAMP('$AS_OF_TIME')
ORDER BY player_id;
SQL
      ;;
    business_risk_same_table_pair_stat)
      cat <<SQL
SELECT CONCAT(
  'INSERT INTO business_risk_same_table_pair_stat (as_of_time,player_a,player_b,window_start,window_end,same_round_count,player_a_round_count,player_b_round_count,same_rate,opposite_round_count,opposite_rate,first_game_time,last_game_time,created_time) VALUES (',
  '''', DATE_FORMAT(as_of_time, '%Y-%m-%d %H:%i:%s'), ''',',
  CAST(player_a AS STRING), ',', CAST(player_b AS STRING), ',',
  '''', DATE_FORMAT(window_start, '%Y-%m-%d %H:%i:%s'), ''',',
  '''', DATE_FORMAT(window_end, '%Y-%m-%d %H:%i:%s'), ''',',
  CAST(same_round_count AS STRING), ',',
  CAST(player_a_round_count AS STRING), ',',
  CAST(player_b_round_count AS STRING), ',',
  CAST(same_rate AS STRING), ',',
  CAST(opposite_round_count AS STRING), ',',
  CAST(opposite_rate AS STRING), ',',
  $(nullable_datetime_sql first_game_time), ',',
  $(nullable_datetime_sql last_game_time), ',',
  '''', DATE_FORMAT(created_time, '%Y-%m-%d %H:%i:%s'), ''');'
) AS statement
FROM $BUSINESS_RISK_TARGET_DATABASE.business_risk_same_table_pair_snapshot
WHERE as_of_time = TIMESTAMP('$AS_OF_TIME')
ORDER BY player_a, player_b;
SQL
      ;;
    business_risk_player_dealer_stat)
      cat <<SQL
SELECT CONCAT(
  'INSERT INTO business_risk_player_dealer_stat (as_of_time,player_id,dealer_id,window_start,window_end,bet_amount,game_pnl,rebate_amount,net_profit_amount,player_overall_net_profit,win_count,lose_count,push_count,win_rate,order_count,round_count,first_bet_time,last_bet_time,created_time) VALUES (',
  '''', DATE_FORMAT(as_of_time, '%Y-%m-%d %H:%i:%s'), ''',',
  CAST(player_id AS STRING), ',', CAST(dealer_id AS STRING), ',',
  '''', DATE_FORMAT(window_start, '%Y-%m-%d %H:%i:%s'), ''',',
  '''', DATE_FORMAT(window_end, '%Y-%m-%d %H:%i:%s'), ''',',
  CAST(bet_amount AS STRING), ',',
  CAST(game_pnl AS STRING), ',',
  CAST(rebate_amount AS STRING), ',',
  CAST(net_profit_amount AS STRING), ',',
  CAST(player_overall_net_profit AS STRING), ',',
  CAST(win_count AS STRING), ',',
  CAST(lose_count AS STRING), ',',
  CAST(push_count AS STRING), ',',
  CAST(win_rate AS STRING), ',',
  CAST(order_count AS STRING), ',',
  CAST(round_count AS STRING), ',',
  $(nullable_datetime_sql first_bet_time), ',',
  $(nullable_datetime_sql last_bet_time), ',',
  '''', DATE_FORMAT(created_time, '%Y-%m-%d %H:%i:%s'), ''');'
) AS statement
FROM $BUSINESS_RISK_TARGET_DATABASE.business_risk_player_dealer_snapshot
WHERE as_of_time = TIMESTAMP('$AS_OF_TIME')
ORDER BY player_id, dealer_id;
SQL
      ;;
  esac
}

business_risk_mysql_args() {
  local profile="$1"
  local output_name="$2"
  local host_var="RISK_REPORT_${profile}_HOST"
  local port_var="RISK_REPORT_${profile}_PORT"
  local database_var="RISK_REPORT_${profile}_DATABASE"
  local username_var="RISK_REPORT_${profile}_USERNAME"
  local ssl_mode_var="RISK_REPORT_${profile}_SSL_MODE"
  local ssl_ca_var="RISK_REPORT_${profile}_SSL_CA"
  local -n output="$output_name"
  output=(
    "--host=${!host_var}"
    "--port=${!port_var}"
    "--user=${!username_var}"
    "--database=${!database_var}"
    "--default-character-set=utf8mb4"
    "--batch"
    "--raw"
    "--connect-timeout=30"
  )
  local ssl_mode="${!ssl_mode_var:-}"
  local ssl_ca="${!ssl_ca_var:-}"
  if [[ -n "$ssl_mode" ]]; then
    if mysql --help 2>&1 | grep -q -- '--ssl-mode'; then
      output+=("--ssl-mode=$ssl_mode")
    else
      case "${ssl_mode^^}" in
        DISABLED) ;;
        PREFERRED|REQUIRED) output+=("--ssl") ;;
        *) die "mysql client cannot enforce SSL mode $ssl_mode" ;;
      esac
    fi
  fi
  [[ -z "$ssl_ca" ]] || output+=("--ssl-ca=$ssl_ca")
}

execute_api_mysql_file() {
  local file="$1"
  local password="${RISK_REPORT_API_MYSQL_PASSWORD:-}"
  local args=()
  business_risk_mysql_args "API_MYSQL" args
  MYSQL_PWD="$password" mysql "${args[@]}" < "$file"
}

publish_dataset() {
  dataset_contract "$1"
  local delete_sql export_sql
  delete_sql="DELETE FROM $TARGET_TABLE WHERE as_of_time = '$AS_OF_TIME';"
  export_sql="$(export_query_for "$TARGET_TABLE")"

  if [[ "$DRY_RUN" == true ]]; then
    print_context
    printf '\n-- API MYSQL DELETE\n%s\n' "$delete_sql"
    printf '\n-- STARROCKS EXPORT FROM %s TO %s\n%s\n' \
      "$SOURCE_TABLE" "$TARGET_TABLE" "$export_sql"
    return
  fi

  init_connections
  risk_report_query "API_MYSQL" "$delete_sql" >/dev/null

  local sql_file
  sql_file="$(mktemp)"
  BUSINESS_RISK_TEMP_FILES+=("$sql_file")
  risk_report_query "STARROCKS" "$export_sql" | tail -n +2 > "$sql_file"
  execute_api_mysql_file "$sql_file"
}

validate_mysql() {
  local source_table target_table source_count target_count
  local contracts=(
    "business_risk_late_bet_snapshot:business_risk_late_bet_stat"
    "business_risk_same_table_pair_snapshot:business_risk_same_table_pair_stat"
    "business_risk_player_dealer_snapshot:business_risk_player_dealer_stat"
  )

  if [[ "$DRY_RUN" == true ]]; then
    print_context
    for contract in "${contracts[@]}"; do
      source_table="${contract%%:*}"
      target_table="${contract##*:}"
      printf '\n-- STARROCKS COUNT\n%s\n' \
        "$(snapshot_count_sql STARROCKS "$source_table")"
      printf '\n-- API MYSQL COUNT\n%s\n' \
        "$(snapshot_count_sql API_MYSQL "$target_table")"
    done
    return
  fi

  init_connections
  for contract in "${contracts[@]}"; do
    source_table="${contract%%:*}"
    target_table="${contract##*:}"
    source_count="$(risk_report_query_scalar \
      STARROCKS "$(snapshot_count_sql STARROCKS "$source_table")")"
    target_count="$(risk_report_query_scalar \
      API_MYSQL "$(snapshot_count_sql API_MYSQL "$target_table")")"
    [[ "$source_count" == "$target_count" ]] || \
      die "$source_table/$target_table row-count mismatch: $source_count/$target_count"
    printf '%s=%s\n' "$target_table" "$target_count"
  done
}

prepare_parameters

case "$COMMAND" in
  validate-parameters)
    validate_parameters
    ;;
  validate-starrocks)
    validate_starrocks
    ;;
  publish-late-bet|publish-same-table|publish-player-dealer)
    publish_dataset "$COMMAND"
    ;;
  validate-mysql)
    validate_mysql
    ;;
  *)
    usage >&2
    die "Unknown command: $COMMAND"
    ;;
esac
