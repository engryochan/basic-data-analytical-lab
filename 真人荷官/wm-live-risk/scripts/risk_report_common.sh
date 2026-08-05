#!/usr/bin/env bash

# Shared runtime for risk report scripts. Business queries belong in callers.

RISK_REPORT_TMP_OUTPUT=""
RISK_REPORT_OUTPUT=""
RISK_REPORT_MYSQL_SSL_MODE_SUPPORTED=""
RISK_REPORT_TEMP_FILES=()

risk_report_die() {
  echo "ERROR: $*" >&2
  exit 2
}

risk_report_load_env() {
  local project_root="$1"
  local env_file="${ENV_FILE:-}"

  if [[ -z "$env_file" && -f "$project_root/conf/env" ]]; then
    env_file="$project_root/conf/env"
  fi

  if [[ -n "$env_file" ]]; then
    [[ -f "$env_file" ]] || risk_report_die "Environment file not found: $env_file"
    # shellcheck source=/dev/null
    source "$env_file"
  fi
}

risk_report_parse_jdbc_url() {
  local profile="$1"
  local jdbc_url="$2"
  local default_port="$3"
  local username="$4"
  local password="$5"
  local ssl_mode="$6"
  local ssl_ca="$7"
  local host_port database host port

  host_port="$(printf '%s' "$jdbc_url" | sed -E 's#^jdbc:mysql://([^/?]+).*#\1#')"
  database="$(printf '%s' "$jdbc_url" | sed -E 's#^jdbc:mysql://[^/]+/([^?]+).*#\1#')"
  host="${host_port%%:*}"
  port="$default_port"
  if [[ "$host_port" == *:* ]]; then
    port="${host_port##*:}"
  fi

  if [[ -z "$host" || "$host" == "$jdbc_url" ]]; then
    echo "ERROR: Failed to parse JDBC host" >&2
    return 2
  fi
  if [[ -z "$database" || "$database" == "$jdbc_url" ]]; then
    echo "ERROR: Failed to parse JDBC database" >&2
    return 2
  fi

  printf -v "RISK_REPORT_${profile}_HOST" '%s' "$host"
  printf -v "RISK_REPORT_${profile}_PORT" '%s' "$port"
  printf -v "RISK_REPORT_${profile}_DATABASE" '%s' "$database"
  printf -v "RISK_REPORT_${profile}_USERNAME" '%s' "$username"
  printf -v "RISK_REPORT_${profile}_PASSWORD" '%s' "$password"
  printf -v "RISK_REPORT_${profile}_SSL_MODE" '%s' "$ssl_mode"
  printf -v "RISK_REPORT_${profile}_SSL_CA" '%s' "$ssl_ca"
}

risk_report_validate_ssl_ca() {
  local label="$1"
  local ssl_mode="${2^^}"
  local ssl_ca="$3"
  local ssl_ca_variable="$4"

  case "$ssl_mode" in
    VERIFY_CA|VERIFY_IDENTITY)
      if [[ -z "$ssl_ca" ]]; then
        echo "ERROR: $ssl_ca_variable is required for $ssl_mode when mysql CLI connects to $label; JDBC JKS truststore cannot be used by mysql CLI." >&2
        return 2
      fi
      ;;
  esac

  if [[ -n "$ssl_ca" && ( ! -f "$ssl_ca" || ! -r "$ssl_ca" ) ]]; then
    echo "ERROR: $label PEM CA file is not readable: $ssl_ca" >&2
    return 2
  fi
}

risk_report_init_starrocks() {
  : "${SR_JDBC_URL:?SR_JDBC_URL is required. Source conf/env or pass --env.}"
  : "${SR_USERNAME:?SR_USERNAME is required. Source conf/env or pass --env.}"
  : "${SR_PASSWORD:?SR_PASSWORD is required. Source conf/env or pass --env.}"

  local ssl_mode="${SR_MYSQL_SSL_MODE:-}"
  if [[ -z "$ssl_mode" && "$SR_JDBC_URL" == *"sslMode="* ]]; then
    ssl_mode="$(printf '%s' "$SR_JDBC_URL" | sed -nE 's#.*[?&]sslMode=([^&]+).*#\1#p')"
  fi
  risk_report_validate_ssl_ca "StarRocks" "$ssl_mode" "${SR_MYSQL_SSL_CA:-}" "SR_MYSQL_SSL_CA" || return

  risk_report_parse_jdbc_url \
    "STARROCKS" \
    "$SR_JDBC_URL" \
    "9030" \
    "$SR_USERNAME" \
    "$SR_PASSWORD" \
    "$ssl_mode" \
    "${SR_MYSQL_SSL_CA:-}"
}

risk_report_init_api_mysql() {
  if [[ -z "${API_MYSQL_URL:-}" || -z "${API_MYSQL_USERNAME:-}" || -z "${API_MYSQL_PASSWORD:-}" ]]; then
    echo "ERROR: API MySQL connection variables are required for projection checks" >&2
    return 2
  fi

  local ssl_mode="${MYSQL_SSL_MODE:-}"
  if [[ -z "$ssl_mode" && "$API_MYSQL_URL" == *"sslMode="* ]]; then
    ssl_mode="$(printf '%s' "$API_MYSQL_URL" | sed -nE 's#.*[?&]sslMode=([^&]+).*#\1#p')"
  fi
  risk_report_validate_ssl_ca "API MySQL" "$ssl_mode" "${MYSQL_SSL_CA:-}" "MYSQL_SSL_CA" || return

  risk_report_parse_jdbc_url \
    "API_MYSQL" \
    "$API_MYSQL_URL" \
    "3306" \
    "$API_MYSQL_USERNAME" \
    "$API_MYSQL_PASSWORD" \
    "$ssl_mode" \
    "${MYSQL_SSL_CA:-}"
}

risk_report_validate_time() {
  local name="$1"
  local value="$2"
  local normalized

  [[ "$value" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]][0-9]{2}:00:00$ ]] || \
    risk_report_die "$name must use yyyy-MM-dd HH:00:00"
  normalized="$(date -d "$value" '+%Y-%m-%d %H:%M:%S' 2>/dev/null)" || \
    risk_report_die "$name is not a valid date-time: $value"
  [[ "$normalized" == "$value" ]] || risk_report_die "$name is not a valid date-time: $value"
}

risk_report_validate_window() {
  local start_time="$1"
  local end_time="$2"
  local start_epoch end_epoch

  risk_report_validate_time "start" "$start_time"
  risk_report_validate_time "end" "$end_time"
  start_epoch="$(date -d "$start_time" '+%s')"
  end_epoch="$(date -d "$end_time" '+%s')"
  (( end_epoch > start_epoch )) || risk_report_die "end must be after start"
}

risk_report_validate_positive_int() {
  local name="$1"
  local value="$2"
  [[ "$value" =~ ^[1-9][0-9]*$ ]] || risk_report_die "$name must be a positive integer"
}

risk_report_validate_number() {
  local name="$1"
  local value="$2"
  [[ "$value" =~ ^-?[0-9]+([.][0-9]+)?$ ]] || risk_report_die "$name must be numeric"
}

risk_report_validate_format() {
  local value="$1"
  case "$value" in
    csv|json) ;;
    *) risk_report_die "format must be csv or json" ;;
  esac
}

risk_report_sql_literal() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/''/g")"
}

risk_report_hour_condition() {
  local alias="$1"
  local start_time="$2"
  local end_time="$3"
  local start_date start_hour end_date end_hour

  start_date="${start_time%% *}"
  start_hour="${start_time:11:2}"
  end_date="${end_time%% *}"
  end_hour="${end_time:11:2}"
  start_hour="$((10#$start_hour))"
  end_hour="$((10#$end_hour))"

  printf "((%s.stat_date > '%s' OR (%s.stat_date = '%s' AND %s.stat_hour >= %s)) AND (%s.stat_date < '%s' OR (%s.stat_date = '%s' AND %s.stat_hour < %s)))" \
    "$alias" "$start_date" "$alias" "$start_date" "$alias" "$start_hour" \
    "$alias" "$end_date" "$alias" "$end_date" "$alias" "$end_hour"
}

risk_report_query() {
  local profile="$1"
  local query="$2"
  local host_var="RISK_REPORT_${profile}_HOST"
  local port_var="RISK_REPORT_${profile}_PORT"
  local database_var="RISK_REPORT_${profile}_DATABASE"
  local username_var="RISK_REPORT_${profile}_USERNAME"
  local password_var="RISK_REPORT_${profile}_PASSWORD"
  local ssl_mode_var="RISK_REPORT_${profile}_SSL_MODE"
  local ssl_ca_var="RISK_REPORT_${profile}_SSL_CA"
  local host="${!host_var:-}"
  local port="${!port_var:-}"
  local database="${!database_var:-}"
  local username="${!username_var:-}"
  local password="${!password_var:-}"
  local ssl_mode="${!ssl_mode_var:-}"
  local ssl_ca="${!ssl_ca_var:-}"
  local mysql_args=(
    --host="$host"
    --port="$port"
    --user="$username"
    --database="$database"
    --default-character-set=utf8mb4
    --batch
    --raw
    --connect-timeout=30
  )

  if [[ -z "$host" || -z "$database" || -z "$username" ]]; then
    echo "ERROR: Database profile is not initialized: $profile" >&2
    return 2
  fi
  if ! command -v mysql >/dev/null 2>&1; then
    echo "ERROR: Missing required command: mysql" >&2
    return 2
  fi

  if [[ -n "$ssl_mode" ]]; then
    if [[ -z "$RISK_REPORT_MYSQL_SSL_MODE_SUPPORTED" ]]; then
      if mysql --help 2>&1 | grep -q -- '--ssl-mode'; then
        RISK_REPORT_MYSQL_SSL_MODE_SUPPORTED=true
      else
        RISK_REPORT_MYSQL_SSL_MODE_SUPPORTED=false
      fi
    fi
    if [[ "$RISK_REPORT_MYSQL_SSL_MODE_SUPPORTED" == "true" ]]; then
      mysql_args+=("--ssl-mode=$ssl_mode")
    else
      case "${ssl_mode^^}" in
        DISABLED)
          ;;
        PREFERRED|REQUIRED)
          mysql_args+=("--ssl")
          ;;
        VERIFY_CA|VERIFY_IDENTITY)
          echo "ERROR: mysql client lacks --ssl-mode; refusing to downgrade $ssl_mode certificate verification" >&2
          return 2
          ;;
        *)
          echo "ERROR: Unsupported MySQL SSL mode: $ssl_mode" >&2
          return 2
          ;;
      esac
    fi
  fi
  if [[ -n "$ssl_ca" ]]; then
    mysql_args+=("--ssl-ca=$ssl_ca")
  fi

  MYSQL_PWD="$password" mysql "${mysql_args[@]}" -e "$query"
}

risk_report_query_scalar() {
  local profile="$1"
  local query="$2"
  local result value

  result="$(risk_report_query "$profile" "$query")" || return 1
  value="$(printf '%s\n' "$result" | awk -F '\t' 'NR == 2 { print $1; exit }')"
  [[ -n "$value" ]] || {
    echo "ERROR: Scalar query returned no data row" >&2
    return 1
  }
  printf '%s' "$value"
}

risk_report_validate_health_grid() {
  local grid_file="$1"
  local start_epoch="$2"
  local end_epoch="$3"
  local observed_hour metric_name actual_row_count qualified_row_count extra
  local epoch expected_hour key value
  local -a required_metrics=(
    "fact_hour_completeness_rate"
    "metric_contract_v3_coverage_rate"
    "traceability_rate"
  )
  local -A observed=()

  [[ -f "$grid_file" ]] || {
    echo "ERROR: health grid result not found: $grid_file" >&2
    return 1
  }

  while IFS=$'\t' read -r observed_hour metric_name actual_row_count qualified_row_count extra; do
    [[ "$observed_hour" == "observed_hour" ]] && continue
    [[ -n "$observed_hour" && -n "$metric_name" ]] || continue
    [[ -z "${extra:-}" && "$actual_row_count" =~ ^[0-9]+$ && "$qualified_row_count" =~ ^[0-9]+$ ]] || {
      echo "ERROR: malformed critical health grid row for $observed_hour / $metric_name" >&2
      return 1
    }
    key="$observed_hour|$metric_name"
    if [[ -n "${observed[$key]+present}" ]]; then
      echo "ERROR: duplicate critical health grid key: $observed_hour / $metric_name" >&2
      return 1
    fi
    observed["$key"]="$actual_row_count|$qualified_row_count"
  done < "$grid_file"

  for ((epoch = start_epoch + 3600; epoch <= end_epoch; epoch += 3600)); do
    expected_hour="$(date -d "@$epoch" '+%Y-%m-%d %H:00:00')"
    for metric_name in "${required_metrics[@]}"; do
      key="$expected_hour|$metric_name"
      value="${observed[$key]:-0|0}"
      if [[ "$value" != "1|1" ]]; then
        echo "ERROR: critical health grid requires exactly one canonical available value=1 row for $expected_hour / $metric_name; observed $value" >&2
        return 1
      fi
    done
  done
}

risk_report_validate_daily_coverage_grid() {
  local grid_file="$1"
  local start_epoch="$2"
  local end_epoch="$3"
  local review_date eligible_contract_hour_count assessment_hour_count extra
  local normalized_date start_date expected_date value
  local line_number=0
  local observed_row_count=0
  local expected_days day_offset
  local -A observed=()

  [[ -f "$grid_file" ]] || {
    echo "ERROR: daily coverage grid result not found: $grid_file" >&2
    return 1
  }
  [[ "$(date -d "@$start_epoch" '+%H:%M:%S')" == "00:00:00" &&
     "$(date -d "@$end_epoch" '+%H:%M:%S')" == "00:00:00" &&
     $(((end_epoch - start_epoch) % 86400)) -eq 0 ]] || {
    echo "ERROR: daily coverage grid requires midnight-to-midnight natural-day boundaries" >&2
    return 1
  }
  expected_days="$(((end_epoch - start_epoch) / 86400))"
  start_date="$(date -d "@$start_epoch" '+%Y-%m-%d')"

  while IFS=$'\t' read -r review_date eligible_contract_hour_count assessment_hour_count extra; do
    line_number=$((line_number + 1))
    if ((line_number == 1)); then
      [[ "$review_date" == "review_date" &&
         "$eligible_contract_hour_count" == "eligible_contract_hour_count" &&
         "$assessment_hour_count" == "assessment_hour_count" &&
         -z "${extra:-}" ]] || {
        echo "ERROR: malformed daily coverage grid header" >&2
        return 1
      }
      continue
    fi
    [[ -n "$review_date" && -z "${extra:-}" &&
       "$eligible_contract_hour_count" =~ ^[0-9]+$ &&
       "$assessment_hour_count" =~ ^[0-9]+$ ]] || {
      echo "ERROR: malformed daily coverage grid row at line $line_number" >&2
      return 1
    }
    if ! normalized_date="$(date -d "$review_date" '+%Y-%m-%d' 2>/dev/null)" ||
       [[ "$normalized_date" != "$review_date" ]]; then
      echo "ERROR: invalid daily coverage date at line $line_number: $review_date" >&2
      return 1
    fi
    if [[ -n "${observed[$review_date]+present}" ]]; then
      echo "ERROR: duplicate daily coverage date: $review_date" >&2
      return 1
    fi
    observed["$review_date"]="$eligible_contract_hour_count|$assessment_hour_count"
    observed_row_count=$((observed_row_count + 1))
  done < "$grid_file"

  ((line_number > 0)) || {
    echo "ERROR: daily coverage grid returned no header" >&2
    return 1
  }
  for ((day_offset = 0; day_offset < expected_days; day_offset += 1)); do
    expected_date="$(date -d "$start_date +$day_offset days" '+%Y-%m-%d')"
    value="${observed[$expected_date]:-MISSING}"
    if [[ "$value" != "24|24" ]]; then
      echo "ERROR: daily coverage requires exactly 24 contract and 24 assessment hours for $expected_date; observed $value" >&2
      return 1
    fi
  done
  if ((observed_row_count != expected_days)); then
    echo "ERROR: daily coverage grid contains unexpected dates: expected $expected_days rows, observed $observed_row_count" >&2
    return 1
  fi
}

risk_report_cleanup_output() {
  if [[ -n "${RISK_REPORT_TMP_OUTPUT:-}" && -f "$RISK_REPORT_TMP_OUTPUT" ]]; then
    rm -f -- "$RISK_REPORT_TMP_OUTPUT"
  fi
  risk_report_cleanup_registered_temps
}

risk_report_register_temp() {
  RISK_REPORT_TEMP_FILES+=("$1")
}

risk_report_cleanup_registered_temps() {
  local temp_file
  for temp_file in "${RISK_REPORT_TEMP_FILES[@]}"; do
    if [[ -n "$temp_file" && -f "$temp_file" ]]; then
      rm -f -- "$temp_file"
    fi
  done
  RISK_REPORT_TEMP_FILES=()
}

risk_report_begin_output() {
  RISK_REPORT_OUTPUT="$1"
  local output_dir output_name
  output_dir="$(dirname "$RISK_REPORT_OUTPUT")"
  output_name="$(basename "$RISK_REPORT_OUTPUT")"
  mkdir -p "$output_dir"
  RISK_REPORT_TMP_OUTPUT="$(mktemp "$output_dir/.${output_name}.tmp.XXXXXX")"
  trap risk_report_cleanup_output EXIT INT TERM
}

risk_report_append_text() {
  printf '%s\n' "$1" >> "$RISK_REPORT_TMP_OUTPUT"
}

risk_report_append_warning() {
  {
    echo
    echo "> **警告：** $1"
    echo
  } >> "$RISK_REPORT_TMP_OUTPUT"
}

risk_report_render_table() {
  awk -F '\t' '
    function esc(s) {
      gsub(/\r/, "", s)
      gsub(/\|/, "\\|", s)
      return s
    }
    NR == 1 {
      printf "|"
      for (i = 1; i <= NF; i++) printf " %s |", esc($i)
      printf "\n|"
      for (i = 1; i <= NF; i++) printf " --- |"
      printf "\n"
      next
    }
    {
      printf "|"
      for (i = 1; i <= NF; i++) printf " %s |", esc($i)
      printf "\n"
    }
    END {
      if (NR == 1) print "_无数据行。_"
    }
  '
}

risk_report_append_table() {
  local title="$1"
  local query="$2"
  local profile="${3:-STARROCKS}"
  local result

  {
    echo
    echo "## $title"
    echo
  } >> "$RISK_REPORT_TMP_OUTPUT"

  result="$(risk_report_query "$profile" "$query")" || return 1
  if [[ -z "$result" ]]; then
    echo "_无返回内容。_" >> "$RISK_REPORT_TMP_OUTPUT"
    return 0
  fi
  printf '%s\n' "$result" | risk_report_render_table >> "$RISK_REPORT_TMP_OUTPUT"
}

risk_report_append_optional_table() {
  local title="$1"
  local query="$2"
  local profile="${3:-API_MYSQL}"

  if ! risk_report_append_table "$title" "$query" "$profile"; then
    risk_report_append_warning "可选章节“$title”查询失败，核心报告仍然有效。"
    return 0
  fi
}

risk_report_render_result() {
  local format="$1"
  local input_file="$2"
  local output_file="$3"

  risk_report_validate_format "$format"
  [[ -f "$input_file" ]] || risk_report_die "result input not found: $input_file"
  case "$format" in
    csv)
      awk -F '\t' '
        function csv(value) {
          gsub(/\r/, "", value)
          gsub(/"/, "\"\"", value)
          return "\"" value "\""
        }
        {
          for (column = 1; column <= NF; column++) {
            printf "%s%s", column == 1 ? "" : ",", csv($column)
          }
          printf "\n"
        }
      ' "$input_file" > "$output_file"
      ;;
    json)
      awk -F '\t' '
        function json(value) {
          gsub(/\\/, "\\\\", value)
          gsub(/"/, "\\\"", value)
          gsub(/\r/, "", value)
          gsub(/\n/, "\\n", value)
          return value
        }
        NR == 1 {
          for (column = 1; column <= NF; column++) header[column] = $column
          column_count = NF
          print "["
          next
        }
        {
          if (row_count > 0) print ","
          printf "  {"
          for (column = 1; column <= column_count; column++) {
            printf "%s\"%s\":\"%s\"", column == 1 ? "" : ",", json(header[column]), json($column)
          }
          printf "}"
          row_count++
        }
        END {
          if (row_count > 0) printf "\n"
          print "]"
        }
      ' "$input_file" > "$output_file"
      ;;
  esac
}

risk_report_finish_output() {
  risk_report_cleanup_registered_temps
  mv -f -- "$RISK_REPORT_TMP_OUTPUT" "$RISK_REPORT_OUTPUT"
  RISK_REPORT_TMP_OUTPUT=""
  trap - EXIT INT TERM
}
