#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=risk_report_common.sh
source "$SCRIPT_DIR/risk_report_common.sh"

DRY_RUN=false

usage() {
  cat <<'USAGE'
Usage:
  business_risk_sql_task.sh [--dry-run] <command> <sql-file>

Commands:
  calculate-late-bet
  calculate-same-table
  calculate-player-dealer
  publish-ready
  cleanup-starrocks
  cleanup-mysql
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

[[ $# -eq 2 ]] || {
  usage >&2
  exit 2
}

COMMAND="$1"
SQL_FILE="$2"
[[ -f "$SQL_FILE" && -r "$SQL_FILE" ]] || die "SQL file is not readable: $SQL_FILE"

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

export BUSINESS_RISK_LOOKBACK_DAYS \
  BUSINESS_RISK_SNAPSHOT_RETENTION_DAYS \
  BUSINESS_RISK_SOURCE_DATABASE \
  BUSINESS_RISK_TARGET_DATABASE \
  BUSINESS_RISK_SOURCE_BET01 \
  BUSINESS_RISK_SOURCE_BET02 \
  BUSINESS_RISK_LATE_SUB_ROUND_MIN \
  BUSINESS_RISK_LATE_ORDER_RATE_MIN \
  BUSINESS_RISK_LATE_ORDER_COUNT_MIN_EXCLUSIVE \
  BUSINESS_RISK_SAME_ROUND_COUNT_MIN \
  BUSINESS_RISK_SAME_RATE_MIN \
  BUSINESS_RISK_OPPOSITE_RATE_MIN \
  BUSINESS_RISK_PLAYER_DEALER_WIN_RATE_MIN_EXCLUSIVE \
  BUSINESS_RISK_PLAYER_DEALER_ORDER_COUNT_MIN_EXCLUSIVE

validate_identifier() {
  local name="$1"
  local value="$2"
  [[ "$value" =~ ^[A-Za-z0-9_]+$ ]] || die "$name contains an unsafe identifier: $value"
}

validate_business_window() {
  local validator="$SCRIPT_DIR/business_risk_task.sh"
  [[ -f "$validator" && -r "$validator" ]] || \
    die "business_risk_task.sh must be downloaded beside this script"
  bash "$validator" --dry-run validate-parameters >/dev/null
}

validate_cleanup_parameters() {
  risk_report_validate_positive_int \
    "BUSINESS_RISK_SNAPSHOT_RETENTION_DAYS" \
    "$BUSINESS_RISK_SNAPSHOT_RETENTION_DAYS"
  (( BUSINESS_RISK_SNAPSHOT_RETENTION_DAYS <= 365 )) || \
    die "BUSINESS_RISK_SNAPSHOT_RETENTION_DAYS must be between 1 and 365"
  validate_identifier "BUSINESS_RISK_TARGET_DATABASE" "$BUSINESS_RISK_TARGET_DATABASE"
}

resolve_ready_as_of_time() {
  local ready_sql
  ready_sql="
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
) AS READY_AS_OF_TIME
FROM business_risk_publish_state;"

  risk_report_init_api_mysql
  READY_AS_OF_TIME="$(risk_report_query_scalar "API_MYSQL" "$ready_sql")" || \
    die "Failed to resolve current READY_AS_OF_TIME from API MySQL"
  [[ "$READY_AS_OF_TIME" != "NONE" ]] || \
    die "No READY BACCARAT_BUSINESS_RISK snapshot exists; cleanup is not allowed"
  export READY_AS_OF_TIME
}

EXPECTED_FILE=""
PROFILE=""
PLACEHOLDERS=()

case "$COMMAND" in
  calculate-late-bet)
    EXPECTED_FILE="calculate_late_bet.sql"
    PROFILE="STARROCKS"
    PLACEHOLDERS=(
      BUSINESS_RISK_TARGET_DATABASE
      AS_OF_TIME
      BUSINESS_RISK_SOURCE_DATABASE
      BUSINESS_RISK_SOURCE_BET01
      WINDOW_START
      WINDOW_END
      BUSINESS_RISK_LATE_SUB_ROUND_MIN
      BUSINESS_RISK_LATE_ORDER_COUNT_MIN_EXCLUSIVE
      BUSINESS_RISK_LATE_ORDER_RATE_MIN
    )
    validate_business_window
    ;;
  calculate-same-table)
    EXPECTED_FILE="calculate_same_table.sql"
    PROFILE="STARROCKS"
    PLACEHOLDERS=(
      BUSINESS_RISK_TARGET_DATABASE
      AS_OF_TIME
      BUSINESS_RISK_SOURCE_DATABASE
      BUSINESS_RISK_SOURCE_BET01
      WINDOW_START
      WINDOW_END
      BUSINESS_RISK_SAME_ROUND_COUNT_MIN
      BUSINESS_RISK_SAME_RATE_MIN
      BUSINESS_RISK_OPPOSITE_RATE_MIN
    )
    validate_business_window
    ;;
  calculate-player-dealer)
    EXPECTED_FILE="calculate_player_dealer.sql"
    PROFILE="STARROCKS"
    PLACEHOLDERS=(
      BUSINESS_RISK_TARGET_DATABASE
      AS_OF_TIME
      BUSINESS_RISK_SOURCE_DATABASE
      BUSINESS_RISK_SOURCE_BET02
      WINDOW_START
      WINDOW_END
      BUSINESS_RISK_PLAYER_DEALER_WIN_RATE_MIN_EXCLUSIVE
      BUSINESS_RISK_PLAYER_DEALER_ORDER_COUNT_MIN_EXCLUSIVE
    )
    validate_business_window
    ;;
  publish-ready)
    EXPECTED_FILE="publish_ready_mysql.sql"
    PROFILE="API_MYSQL"
    PLACEHOLDERS=(AS_OF_TIME WINDOW_START WINDOW_END)
    validate_business_window
    ;;
  cleanup-starrocks)
    EXPECTED_FILE="cleanup_starrocks.sql"
    PROFILE="STARROCKS"
    PLACEHOLDERS=(
      BUSINESS_RISK_TARGET_DATABASE
      BUSINESS_RISK_SNAPSHOT_RETENTION_DAYS
      READY_AS_OF_TIME
    )
    validate_cleanup_parameters
    if [[ "$DRY_RUN" == true ]]; then
      : "${READY_AS_OF_TIME:?READY_AS_OF_TIME is required for --dry-run}"
    else
      resolve_ready_as_of_time
    fi
    risk_report_validate_time "READY_AS_OF_TIME" "$READY_AS_OF_TIME"
    ;;
  cleanup-mysql)
    EXPECTED_FILE="cleanup_mysql.sql"
    PROFILE="API_MYSQL"
    PLACEHOLDERS=(BUSINESS_RISK_SNAPSHOT_RETENTION_DAYS)
    validate_cleanup_parameters
    ;;
  *)
    usage >&2
    die "Unknown command: $COMMAND"
    ;;
esac

[[ "$(basename "$SQL_FILE")" == "$EXPECTED_FILE" ]] || \
  die "$COMMAND requires $EXPECTED_FILE, got $(basename "$SQL_FILE")"

RENDERED_SQL="$(<"$SQL_FILE")"
for name in "${PLACEHOLDERS[@]}"; do
  value="${!name-}"
  [[ -n "$value" ]] || die "$name is required"
  RENDERED_SQL="${RENDERED_SQL//\$\{$name\}/$value}"
done

if grep -Eq '\$\{[A-Za-z_][A-Za-z0-9_]*\}' <<<"$RENDERED_SQL"; then
  unresolved="$(grep -Eo '\$\{[A-Za-z_][A-Za-z0-9_]*\}' <<<"$RENDERED_SQL" | sort -u)"
  die "SQL contains unresolved or unsupported placeholders: $unresolved"
fi

if [[ "$DRY_RUN" == true ]]; then
  printf 'command=%s\n' "$COMMAND"
  printf 'profile=%s\n' "$PROFILE"
  printf 'sql_file=%s\n' "$SQL_FILE"
  printf '%s\n' "$RENDERED_SQL"
  exit 0
fi

case "$PROFILE" in
  STARROCKS)
    risk_report_init_starrocks
    ;;
  API_MYSQL)
    risk_report_init_api_mysql
    ;;
  *)
    die "Unsupported database profile: $PROFILE"
    ;;
esac

risk_report_query "$PROFILE" "$RENDERED_SQL" >/dev/null
