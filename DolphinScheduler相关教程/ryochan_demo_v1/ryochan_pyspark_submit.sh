#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  pyspark_submit.sh \
    --name NAME \
    --file s3://bucket/job.py \
    [--python-env-archive s3://bucket/environment.tar.gz] \
    [--py-file s3://bucket/module.py|module.zip|module.egg]... \
    [--jars URI[,URI...]]... \
    [--files URI_OR_PATH[,URI_OR_PATH...]]... \
    [--conf KEY=VALUE]... \
    [--driver-memory 4g] [--driver-cores 1] \
    [--executor-memory 6g] [--executor-cores 2] \
    [--num-executors 4] [--shuffle-partitions 64] \
    [--queue prod] [--no-wait] \
    -- [job arguments...]

Required environment:
  LIVY_HOST, LIVY_USER, LIVY_PASSWORD, SPARK_EVENT_LOG_S3

Optional environment:
  LIVY_PORT=8998
  LIVY_POLL_INTERVAL_SEC=30
  LIVY_MAX_WAIT_SEC=7200
  PYSPARK_DRIVER_MEMORY=4g
  PYSPARK_DRIVER_CORES=1
  PYSPARK_EXECUTOR_MEMORY=6g
  PYSPARK_EXECUTOR_CORES=2
  PYSPARK_NUM_EXECUTORS=4
  PYSPARK_SHUFFLE_PARTITIONS=64
  YARN_QUEUE=prod
  SPARK_SQL_SESSION_TIMEZONE=Asia/Shanghai

Administrator passthrough:
  --jars, --files, and --conf accept trusted-administrator input and are
  forwarded to Livy without resource existence checks. Do not pass secrets.
USAGE
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 2
}

require_value() {
  local option="$1"
  local value="${2:-}"
  [[ -n "$value" && "$value" != --* ]] || fail "$option requires a value"
}

require_inline_value() {
  local option="$1"
  local value="$2"
  [[ -n "$value" ]] || fail "$option requires a value"
}

require_nonempty_csv_entries() {
  local option="$1"
  local value="$2"
  [[ "$value" != ,* && "$value" != *, && "$value" != *,,* ]] ||
    fail "$option must not contain empty entries"
}

require_conf_entry() {
  local value="$1"
  local key

  [[ "$value" == *=* ]] || fail "--conf must use KEY=VALUE"
  key="${value%%=*}"
  [[ -n "$key" ]] || fail "--conf key must not be empty"
  [[ "$key" != *[[:space:]]* ]] || fail "--conf key must not contain whitespace"
}

count_csv_entries() {
  local total=0
  local value
  local separators

  for value in "$@"; do
    separators="${value//[^,]/}"
    total=$((total + ${#separators} + 1))
  done
  printf '%s' "$total"
}

is_safe_s3_uri() {
  local value="$1"
  local bucket

  [[ "$value" != *[[:space:]]* &&
     "$value" != *\\* &&
     "$value" != *..* &&
     "$value" != *'?'* &&
     "$value" != *'#'* ]] || return 1

  if [[ "$value" =~ ^s3://([^/]+)/([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9._/+@=-]*[A-Za-z0-9._+@=-])$ ]]; then
    bucket="${BASH_REMATCH[1]}"
  else
    return 1
  fi

  [[ "$bucket" =~ ^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$ &&
     "$bucket" != *..* &&
     "$bucket" != *.-* &&
     "$bucket" != *-.* &&
     ! "$bucket" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]
}

require_s3_uri() {
  local name="$1"
  local value="$2"
  is_safe_s3_uri "$value" || fail "$name must be a safe S3 URI using an approved ASCII bucket and key"
}

require_memory() {
  local name="$1"
  local value="$2"
  [[ "$value" =~ ^[1-9][0-9]*[mMgG]$ ]] || fail "$name must be a positive integer followed by m or g"
}

require_positive_integer() {
  local name="$1"
  local value="$2"
  [[ "$value" =~ ^[1-9][0-9]*$ ]] || fail "$name must be a positive integer"
}

name=""
application_file=""
python_environment_archive=""
no_wait=false
py_files=()
jar_specs=()
file_specs=()
conf_entries=()
job_arguments=()

driver_memory="${PYSPARK_DRIVER_MEMORY-4g}"
driver_cores="${PYSPARK_DRIVER_CORES-1}"
executor_memory="${PYSPARK_EXECUTOR_MEMORY-6g}"
executor_cores="${PYSPARK_EXECUTOR_CORES-2}"
num_executors="${PYSPARK_NUM_EXECUTORS-4}"
shuffle_partitions="${PYSPARK_SHUFFLE_PARTITIONS-64}"
queue="${YARN_QUEUE-prod}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)
      require_value "$1" "${2:-}"
      name="$2"
      shift 2
      ;;
    --file)
      require_value "$1" "${2:-}"
      application_file="$2"
      shift 2
      ;;
    --python-env-archive)
      require_value "$1" "${2:-}"
      python_environment_archive="$2"
      shift 2
      ;;
    --py-file)
      require_value "$1" "${2:-}"
      py_files+=("$2")
      shift 2
      ;;
    --jars)
      require_value "$1" "${2:-}"
      jar_specs+=("$2")
      shift 2
      ;;
    --jars=*)
      inline_value="${1#--jars=}"
      require_inline_value "--jars" "$inline_value"
      jar_specs+=("$inline_value")
      shift
      ;;
    --files)
      require_value "$1" "${2:-}"
      file_specs+=("$2")
      shift 2
      ;;
    --files=*)
      inline_value="${1#--files=}"
      require_inline_value "--files" "$inline_value"
      file_specs+=("$inline_value")
      shift
      ;;
    --conf)
      require_value "$1" "${2:-}"
      conf_entries+=("$2")
      shift 2
      ;;
    --conf=*)
      inline_value="${1#--conf=}"
      require_inline_value "--conf" "$inline_value"
      conf_entries+=("$inline_value")
      shift
      ;;
    --driver-memory)
      require_value "$1" "${2:-}"
      driver_memory="$2"
      shift 2
      ;;
    --driver-cores)
      require_value "$1" "${2:-}"
      driver_cores="$2"
      shift 2
      ;;
    --executor-memory)
      require_value "$1" "${2:-}"
      executor_memory="$2"
      shift 2
      ;;
    --executor-cores)
      require_value "$1" "${2:-}"
      executor_cores="$2"
      shift 2
      ;;
    --num-executors)
      require_value "$1" "${2:-}"
      num_executors="$2"
      shift 2
      ;;
    --shuffle-partitions)
      require_value "$1" "${2:-}"
      shuffle_partitions="$2"
      shift 2
      ;;
    --queue)
      require_value "$1" "${2:-}"
      queue="$2"
      shift 2
      ;;
    --no-wait)
      no_wait=true
      shift
      ;;
    --)
      shift
      job_arguments=("$@")
      break
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
done

[[ -n "$name" ]] || fail "--name is required"
[[ "$name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$ ]] ||
  fail "--name must start with an ASCII alphanumeric character and contain only ASCII alphanumerics, dot, underscore, or hyphen"

[[ -n "$application_file" ]] || fail "--file is required"
require_s3_uri "--file" "$application_file"
[[ "$application_file" == *.py ]] || fail "--file must reference a .py object"

for py_file in "${py_files[@]}"; do
  require_s3_uri "--py-file" "$py_file"
  case "$py_file" in
    *.py|*.zip|*.egg) ;;
    *) fail "--py-file must reference a .py, .zip, or .egg object" ;;
  esac
done

for jar_spec in "${jar_specs[@]}"; do
  require_nonempty_csv_entries "--jars" "$jar_spec"
done

for file_spec in "${file_specs[@]}"; do
  require_nonempty_csv_entries "--files" "$file_spec"
done

for conf_entry in "${conf_entries[@]}"; do
  require_conf_entry "$conf_entry"
done

if [[ -n "$python_environment_archive" ]]; then
  require_s3_uri "--python-env-archive" "$python_environment_archive"
  [[ "$python_environment_archive" == *.tar.gz ]] ||
    fail "--python-env-archive must reference a .tar.gz object"
fi

[[ "$queue" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$ ]] ||
  fail "--queue must start with an ASCII alphanumeric character and contain only ASCII alphanumerics, dot, underscore, or hyphen"
require_memory "--driver-memory" "$driver_memory"
require_positive_integer "--driver-cores" "$driver_cores"
require_memory "--executor-memory" "$executor_memory"
require_positive_integer "--executor-cores" "$executor_cores"
require_positive_integer "--num-executors" "$num_executors"
require_positive_integer "--shuffle-partitions" "$shuffle_partitions"

: "${LIVY_HOST:?LIVY_HOST is required}"
: "${LIVY_USER:?LIVY_USER is required}"
: "${LIVY_PASSWORD:?LIVY_PASSWORD is required}"
: "${SPARK_EVENT_LOG_S3:?SPARK_EVENT_LOG_S3 is required}"
require_s3_uri "SPARK_EVENT_LOG_S3" "$SPARK_EVENT_LOG_S3"

LIVY_PORT="${LIVY_PORT-8998}"
LIVY_POLL_INTERVAL_SEC="${LIVY_POLL_INTERVAL_SEC-30}"
LIVY_MAX_WAIT_SEC="${LIVY_MAX_WAIT_SEC-7200}"
SPARK_SQL_SESSION_TIMEZONE="${SPARK_SQL_SESSION_TIMEZONE-${TZ-Asia/Shanghai}}"
require_positive_integer "LIVY_PORT" "$LIVY_PORT"
require_positive_integer "LIVY_POLL_INTERVAL_SEC" "$LIVY_POLL_INTERVAL_SEC"
require_positive_integer "LIVY_MAX_WAIT_SEC" "$LIVY_MAX_WAIT_SEC"

jar_count="$(count_csv_entries "${jar_specs[@]}")"
file_count="$(count_csv_entries "${file_specs[@]}")"
conf_count="${#conf_entries[@]}"

command -v curl >/dev/null 2>&1 || fail "Missing required command: curl"
command -v python3 >/dev/null 2>&1 || fail "Missing required command: python3"

LIVY_URL="http://${LIVY_HOST}:${LIVY_PORT}"
umask 077
PAYLOAD_PATH="$(mktemp)"
trap 'rm -f "$PAYLOAD_PATH"' EXIT
chmod 600 "$PAYLOAD_PATH"

{
  printf '%s\0' \
    "$name" \
    "$application_file" \
    "$python_environment_archive" \
    "$driver_memory" \
    "$driver_cores" \
    "$executor_memory" \
    "$executor_cores" \
    "$num_executors" \
    "$shuffle_partitions" \
    "$queue" \
    "$SPARK_SQL_SESSION_TIMEZONE" \
    "$SPARK_EVENT_LOG_S3" \
    "${#jar_specs[@]}" \
    "${#file_specs[@]}" \
    "${#conf_entries[@]}" \
    "${#py_files[@]}" \
    "${#job_arguments[@]}"
  if (( ${#jar_specs[@]} > 0 )); then
    printf '%s\0' "${jar_specs[@]}"
  fi
  if (( ${#file_specs[@]} > 0 )); then
    printf '%s\0' "${file_specs[@]}"
  fi
  if (( ${#conf_entries[@]} > 0 )); then
    printf '%s\0' "${conf_entries[@]}"
  fi
  if (( ${#py_files[@]} > 0 )); then
    printf '%s\0' "${py_files[@]}"
  fi
  if (( ${#job_arguments[@]} > 0 )); then
    printf '%s\0' "${job_arguments[@]}"
  fi
} | python3 -c '
import json
import sys

raw_values = sys.stdin.buffer.read().split(b"\0")
if raw_values and raw_values[-1] == b"":
    raw_values.pop()
values = [value.decode("utf-8") for value in raw_values]

(
    name,
    application_file,
    archive,
    driver_memory,
    driver_cores,
    executor_memory,
    executor_cores,
    num_executors,
    shuffle_partitions,
    queue,
    timezone,
    event_log,
    jar_spec_count,
    file_spec_count,
    conf_entry_count,
    py_file_count,
    argument_count,
    *remaining,
) = values

jar_spec_count = int(jar_spec_count)
file_spec_count = int(file_spec_count)
conf_entry_count = int(conf_entry_count)
py_file_count = int(py_file_count)
argument_count = int(argument_count)
if len(remaining) != jar_spec_count + file_spec_count + conf_entry_count + py_file_count + argument_count:
    raise SystemExit("invalid PySpark payload argument counts")

offset = 0
jar_specs = remaining[offset:offset + jar_spec_count]
offset += jar_spec_count
file_specs = remaining[offset:offset + file_spec_count]
offset += file_spec_count
conf_entries = remaining[offset:offset + conf_entry_count]
offset += conf_entry_count
py_files = remaining[offset:offset + py_file_count]
offset += py_file_count
arguments = remaining[offset:]

def expand_csv(option, specs):
    values = []
    for spec in specs:
        entries = spec.split(",")
        if any(entry == "" for entry in entries):
            raise SystemExit(f"{option} must not contain empty entries")
        values.extend(entries)
    return values

jars = expand_csv("--jars", jar_specs)
files = expand_csv("--files", file_specs)
conf = {
    "spark.sql.session.timeZone": timezone,
    "spark.sql.shuffle.partitions": shuffle_partitions,
    "spark.eventLog.enabled": "true",
    "spark.eventLog.dir": event_log,
}

payload = {
    "file": application_file,
    "name": name,
    "args": arguments,
    "driverMemory": driver_memory,
    "driverCores": int(driver_cores),
    "executorMemory": executor_memory,
    "executorCores": int(executor_cores),
    "numExecutors": int(num_executors),
    "queue": queue,
    "conf": conf,
}

if py_files:
    payload["pyFiles"] = py_files
if jars:
    payload["jars"] = jars
if files:
    payload["files"] = files
if archive:
    payload["archives"] = [f"{archive}#mlenv"]
    conf.update(
        {
            "spark.pyspark.python": "./mlenv/bin/python",
            "spark.yarn.appMasterEnv.PYSPARK_PYTHON": "./mlenv/bin/python",
            "spark.executorEnv.PYSPARK_PYTHON": "./mlenv/bin/python",
        }
    )

for entry in conf_entries:
    if "=" not in entry:
        raise SystemExit("--conf must use KEY=VALUE")
    key, value = entry.split("=", 1)
    if not key:
        raise SystemExit("--conf key must not be empty")
    if any(character.isspace() for character in key):
        raise SystemExit("--conf key must not contain whitespace")
    conf[key] = value

sys.stdout.buffer.write(
    (json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n").encode("utf-8")
)
' > "$PAYLOAD_PATH"

python_environment="disabled"
[[ -n "$python_environment_archive" ]] && python_environment="enabled"
printf 'Submitting Livy PySpark batch: name=%s file=%s queue=%s pythonEnv=%s driverMemory=%s driverCores=%s executorMemory=%s executorCores=%s numExecutors=%s shufflePartitions=%s jars=%s files=%s conf=%s\n' \
  "$name" \
  "$application_file" \
  "$queue" \
  "$python_environment" \
  "$driver_memory" \
  "$driver_cores" \
  "$executor_memory" \
  "$executor_cores" \
  "$num_executors" \
  "$shuffle_partitions" \
  "$jar_count" \
  "$file_count" \
  "$conf_count"

if ! submit_response="$(
  curl -sS \
    -u "${LIVY_USER}:${LIVY_PASSWORD}" \
    -H "Content-Type: application/json" \
    -X POST \
    --data-binary "@${PAYLOAD_PATH}" \
    "${LIVY_URL}/batches" \
    -w $'\n%{http_code}'
)"; then
  printf 'Failed to submit Livy PySpark batch: url=%s/batches\n' "$LIVY_URL" >&2
  exit 1
fi

submit_status="${submit_response##*$'\n'}"
submit_body="${submit_response%$'\n'*}"

if [[ ! "$submit_status" =~ ^[0-9]{3}$ ]]; then
  printf 'Failed to parse Livy PySpark submit HTTP status\n' >&2
  exit 1
fi

if (( submit_status < 200 || submit_status >= 300 )); then
  printf 'Livy PySpark submit failed: status=%s url=%s/batches\n' "$submit_status" "$LIVY_URL" >&2
  [[ -z "$submit_body" ]] || printf '%s\n' "$submit_body" >&2
  exit 1
fi

if ! batch_id="$(
  printf '%s' "$submit_body" |
    python3 -c '
import json
import sys

try:
    value = json.load(sys.stdin).get("id")
except (AttributeError, json.JSONDecodeError):
    raise SystemExit(2)
if isinstance(value, bool) or not isinstance(value, int) or value < 0:
    raise SystemExit(2)
print(value)
'
)"; then
  printf 'Livy PySpark submit response did not contain a valid integer batch id\n' >&2
  exit 1
fi

printf 'Livy PySpark batch submitted: id=%s\n' "$batch_id"
[[ "$no_wait" == true ]] && exit 0

parse_state() {
  python3 -c '
import json
import sys

try:
    value = json.load(sys.stdin).get("state")
except (AttributeError, json.JSONDecodeError):
    raise SystemExit(2)
if not isinstance(value, str) or not value:
    raise SystemExit(2)
print(value)
'
}

fetch_logs() {
  local log_response
  local log_status
  local log_body

  if ! log_response="$(
    curl -sS \
      -u "${LIVY_USER}:${LIVY_PASSWORD}" \
      "${LIVY_URL}/batches/${batch_id}/log?from=0&size=200" \
      -w $'\n%{http_code}'
  )"; then
    printf 'Failed to query Livy PySpark batch logs: id=%s\n' "$batch_id" >&2
    return
  fi

  log_status="${log_response##*$'\n'}"
  log_body="${log_response%$'\n'*}"
  if [[ "$log_status" =~ ^[0-9]{3}$ ]] &&
     (( log_status >= 200 && log_status < 300 )); then
    [[ -z "$log_body" ]] || printf '%s\n' "$log_body" >&2
  else
    printf 'Livy PySpark log query failed: id=%s status=%s\n' "$batch_id" "$log_status" >&2
  fi
}

elapsed=0
while true; do
  if ! state_response="$(
    curl -sS \
      -u "${LIVY_USER}:${LIVY_PASSWORD}" \
      "${LIVY_URL}/batches/${batch_id}/state" \
      -w $'\n%{http_code}'
  )"; then
    printf 'Failed to query Livy PySpark batch state: id=%s\n' "$batch_id" >&2
    exit 1
  fi

  state_status="${state_response##*$'\n'}"
  state_body="${state_response%$'\n'*}"
  if [[ ! "$state_status" =~ ^[0-9]{3}$ ]] ||
     (( state_status < 200 || state_status >= 300 )); then
    printf 'Livy PySpark state query failed: id=%s status=%s\n' "$batch_id" "$state_status" >&2
    exit 1
  fi

  if ! state="$(printf '%s' "$state_body" | parse_state)"; then
    printf 'Livy PySpark state response did not contain a valid state: id=%s\n' "$batch_id" >&2
    exit 1
  fi

  printf 'Livy PySpark batch state: id=%s state=%s elapsed=%ss\n' "$batch_id" "$state" "$elapsed"
  case "$state" in
    success)
      printf 'Livy PySpark batch succeeded: id=%s\n' "$batch_id"
      exit 0
      ;;
    dead|error|killed)
      printf 'Livy PySpark batch failed: id=%s state=%s\n' "$batch_id" "$state" >&2
      fetch_logs
      exit 1
      ;;
    not_started|starting|running|recovering)
      if (( elapsed >= LIVY_MAX_WAIT_SEC )); then
        printf 'Livy PySpark batch wait timed out: id=%s maxWait=%ss\n' "$batch_id" "$LIVY_MAX_WAIT_SEC" >&2
        fetch_logs
        exit 1
      fi
      ;;
    *)
      printf 'Unexpected Livy batch state: %s\n' "$state" >&2
      exit 1
      ;;
  esac

  sleep "$LIVY_POLL_INTERVAL_SEC"
  elapsed=$((elapsed + LIVY_POLL_INTERVAL_SEC))
done
