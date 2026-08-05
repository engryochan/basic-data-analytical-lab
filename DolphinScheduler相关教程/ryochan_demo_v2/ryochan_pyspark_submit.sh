#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  ryochan_pyspark_submit.sh \
    --name NAME \
    --file s3://bucket/job.py \
    [--jars URI[,URI...]]... \
    [--files URI[,URI...]]... \
    [--conf KEY=VALUE]... \
    [--method shell|livy]        (default: shell) \
    [--master yarn]              (shell method only, default: yarn) \
    [--deploy-mode cluster]      (shell method only, default: cluster) \
    [--driver-memory 4g] [--driver-cores 1] \
    [--executor-memory 6g] [--executor-cores 2] [--num-executors 4] \
    [--queue prod] [--no-wait] \
    -- [job arguments...]

v2 / NEW FILE: this was missing from the original bundle -- the
pyspark-demo DolphinScheduler node's wrapper script looked for a file
named exactly pyspark_submit.sh and it did not exist.

--method shell (default) runs spark-submit directly against the
application file's S3 path (Spark/Hadoop's own S3 filesystem support
resolves s3:// application files directly on EMR-style clusters, unlike
a bare Rscript interpreter, so no local download step is needed here).
This is the recommended path now that this worker connects to the
cluster/database directly.

--method livy POSTs a batch job to Livy's /batches API, matching the
same JSON payload shape as ryochan_sparklyr_submit.sh's predecessor did.
Required environment for --method livy: LIVY_HOST, LIVY_USER,
LIVY_PASSWORD, SPARK_EVENT_LOG_S3 (all read from environment, never from
command-line arguments).

Passthrough warning:
  --jars, --files, and --conf accept trusted-administrator input and are
  forwarded without resource-existence checks. Do not pass secrets
  through them.
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

require_memory() {
  local name="$1" value="$2"
  [[ "$value" =~ ^[1-9][0-9]*[mMgG]$ ]] || fail "$name must be a positive integer followed by m or g"
}

require_positive_integer() {
  local name="$1" value="$2"
  [[ "$value" =~ ^[1-9][0-9]*$ ]] || fail "$name must be a positive integer"
}

name=""
application_file=""
method="shell"
master="yarn"
deploy_mode="cluster"
no_wait=false
jar_specs=()
file_specs=()
conf_entries=()
job_arguments=()

driver_memory="${SPARK_DRIVER_MEMORY-4g}"
driver_cores="${SPARK_DRIVER_CORES-1}"
executor_memory="${SPARK_EXECUTOR_MEMORY-6g}"
executor_cores="${SPARK_EXECUTOR_CORES-2}"
num_executors="${SPARK_NUM_EXECUTORS-4}"
queue="${YARN_QUEUE-prod}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) require_value "$1" "${2:-}"; name="$2"; shift 2 ;;
    --file) require_value "$1" "${2:-}"; application_file="$2"; shift 2 ;;
    --method) require_value "$1" "${2:-}"; method="$2"; shift 2 ;;
    --master) require_value "$1" "${2:-}"; master="$2"; shift 2 ;;
    --deploy-mode) require_value "$1" "${2:-}"; deploy_mode="$2"; shift 2 ;;
    --jars) require_value "$1" "${2:-}"; jar_specs+=("$2"); shift 2 ;;
    --files) require_value "$1" "${2:-}"; file_specs+=("$2"); shift 2 ;;
    --conf) require_value "$1" "${2:-}"; conf_entries+=("$2"); shift 2 ;;
    --driver-memory) require_value "$1" "${2:-}"; driver_memory="$2"; shift 2 ;;
    --driver-cores) require_value "$1" "${2:-}"; driver_cores="$2"; shift 2 ;;
    --executor-memory) require_value "$1" "${2:-}"; executor_memory="$2"; shift 2 ;;
    --executor-cores) require_value "$1" "${2:-}"; executor_cores="$2"; shift 2 ;;
    --num-executors) require_value "$1" "${2:-}"; num_executors="$2"; shift 2 ;;
    --queue) require_value "$1" "${2:-}"; queue="$2"; shift 2 ;;
    --no-wait) no_wait=true; shift ;;
    --) shift; job_arguments=("$@"); break ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown argument: $1" ;;
  esac
done

[[ -n "$name" ]] || fail "--name is required"
[[ "$name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$ ]] ||
  fail "--name must start with an ASCII alphanumeric character and contain only ASCII alphanumerics, dot, underscore, or hyphen"

[[ -n "$application_file" ]] || fail "--file is required"
require_s3_uri "$application_file"
case "$application_file" in
  *.py) ;;
  *) fail "--file must reference a .py object" ;;
esac

case "$method" in
  shell|livy) ;;
  *) fail "--method must be shell or livy" ;;
esac

for jar_spec in "${jar_specs[@]}"; do
  require_nonempty_csv_entries "--jars" "$jar_spec"
  IFS=',' read -ra entries <<< "$jar_spec"
  for entry in "${entries[@]}"; do require_s3_uri "$entry"; done
done
for file_spec in "${file_specs[@]}"; do
  require_nonempty_csv_entries "--files" "$file_spec"
  IFS=',' read -ra entries <<< "$file_spec"
  for entry in "${entries[@]}"; do require_s3_uri "$entry"; done
done
for conf_entry in "${conf_entries[@]}"; do
  require_conf_entry "$conf_entry"
done

require_memory "--driver-memory" "$driver_memory"
require_positive_integer "--driver-cores" "$driver_cores"
require_memory "--executor-memory" "$executor_memory"
require_positive_integer "--executor-cores" "$executor_cores"
require_positive_integer "--num-executors" "$num_executors"
[[ "$queue" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$ ]] ||
  fail "--queue must start with an ASCII alphanumeric character and contain only ASCII alphanumerics, dot, underscore, or hyphen"

# ------------------------------------------------------------------
# method=shell: spark-submit runs directly on this host.
# ------------------------------------------------------------------
if [[ "$method" == "shell" ]]; then
  command -v spark-submit >/dev/null 2>&1 || fail "Missing required command: spark-submit"

  submit_args=(
    --name "$name"
    --master "$master"
    --deploy-mode "$deploy_mode"
    --driver-memory "$driver_memory" --driver-cores "$driver_cores"
    --executor-memory "$executor_memory" --executor-cores "$executor_cores"
    --num-executors "$num_executors"
    --queue "$queue"
    --conf spark.sql.adaptive.enabled=true
    --conf spark.sql.adaptive.coalescePartitions.enabled=true
  )
  for jar_spec in "${jar_specs[@]}"; do submit_args+=(--jars "$jar_spec"); done
  for file_spec in "${file_specs[@]}"; do submit_args+=(--files "$file_spec"); done
  for conf_entry in "${conf_entries[@]}"; do submit_args+=(--conf "$conf_entry"); done

  printf 'Running spark-submit (shell): name=%s file=%s master=%s deployMode=%s\n' \
    "$name" "$application_file" "$master" "$deploy_mode"
  exec spark-submit "${submit_args[@]}" "$application_file" -- "${job_arguments[@]}"
fi

# ------------------------------------------------------------------
# method=livy: POST a batch job to Livy's /batches API.
# ------------------------------------------------------------------
: "${LIVY_HOST:?LIVY_HOST is required for --method livy}"
: "${LIVY_USER:?LIVY_USER is required for --method livy}"
: "${LIVY_PASSWORD:?LIVY_PASSWORD is required for --method livy}"
: "${SPARK_EVENT_LOG_S3:?SPARK_EVENT_LOG_S3 is required for --method livy}"
require_s3_uri "SPARK_EVENT_LOG_S3" "$SPARK_EVENT_LOG_S3"

LIVY_PORT="${LIVY_PORT-8998}"
LIVY_POLL_INTERVAL_SEC="${LIVY_POLL_INTERVAL_SEC-30}"
LIVY_MAX_WAIT_SEC="${LIVY_MAX_WAIT_SEC-7200}"
require_positive_integer "LIVY_PORT" "$LIVY_PORT"
require_positive_integer "LIVY_POLL_INTERVAL_SEC" "$LIVY_POLL_INTERVAL_SEC"
require_positive_integer "LIVY_MAX_WAIT_SEC" "$LIVY_MAX_WAIT_SEC"

command -v curl >/dev/null 2>&1 || fail "Missing required command: curl"
command -v python3 >/dev/null 2>&1 || fail "Missing required command: python3"

LIVY_URL="http://${LIVY_HOST}:${LIVY_PORT}"
umask 077
PAYLOAD_PATH="$(mktemp)"
trap 'rm -f "$PAYLOAD_PATH"' EXIT
chmod 600 "$PAYLOAD_PATH"

{
  printf '%s\0' \
    "$name" "$application_file" "$driver_memory" "$driver_cores" \
    "$executor_memory" "$executor_cores" "$num_executors" "$queue" \
    "$SPARK_EVENT_LOG_S3" \
    "${#jar_specs[@]}" "${#file_specs[@]}" "${#conf_entries[@]}" "${#job_arguments[@]}"
  (( ${#jar_specs[@]} > 0 )) && printf '%s\0' "${jar_specs[@]}"
  (( ${#file_specs[@]} > 0 )) && printf '%s\0' "${file_specs[@]}"
  (( ${#conf_entries[@]} > 0 )) && printf '%s\0' "${conf_entries[@]}"
  (( ${#job_arguments[@]} > 0 )) && printf '%s\0' "${job_arguments[@]}"
  true
} | python3 -c '
import json, sys

raw_values = sys.stdin.buffer.read().split(b"\0")
if raw_values and raw_values[-1] == b"":
    raw_values.pop()
values = [v.decode("utf-8") for v in raw_values]

(name, application_file, driver_memory, driver_cores, executor_memory,
 executor_cores, num_executors, queue, event_log,
 jar_count, file_count, conf_count, arg_count, *rest) = values

jar_count, file_count, conf_count, arg_count = (
    int(jar_count), int(file_count), int(conf_count), int(arg_count)
)
if len(rest) != jar_count + file_count + conf_count + arg_count:
    raise SystemExit("invalid PySpark payload argument count")

offset = 0
jar_specs = rest[offset:offset + jar_count]; offset += jar_count
file_specs = rest[offset:offset + file_count]; offset += file_count
conf_entries = rest[offset:offset + conf_count]; offset += conf_count
job_args = rest[offset:]

def expand_csv(option, specs):
    out = []
    for spec in specs:
        parts = spec.split(",")
        if any(p == "" for p in parts):
            raise SystemExit(f"{option} must not contain empty entries")
        out.extend(parts)
    return out

jars = expand_csv("--jars", jar_specs)
files = expand_csv("--files", file_specs)
conf = {
    "spark.eventLog.enabled": "true",
    "spark.eventLog.dir": event_log,
    "spark.sql.adaptive.enabled": "true",
    "spark.sql.adaptive.coalescePartitions.enabled": "true",
}
for entry in conf_entries:
    if "=" not in entry:
        raise SystemExit("--conf must use KEY=VALUE")
    k, v = entry.split("=", 1)
    if not k or any(c.isspace() for c in k):
        raise SystemExit("--conf key must not be empty or contain whitespace")
    conf[k] = v

payload = {
    "file": application_file,
    "name": name,
    "args": job_args,
    "driverMemory": driver_memory,
    "driverCores": int(driver_cores),
    "executorMemory": executor_memory,
    "executorCores": int(executor_cores),
    "numExecutors": int(num_executors),
    "queue": queue,
    "conf": conf,
}
if jars:
    payload["jars"] = jars
if files:
    payload["files"] = files

sys.stdout.buffer.write(
    (json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n").encode("utf-8")
)
' > "$PAYLOAD_PATH"

printf 'Submitting Livy batch: name=%s file=%s queue=%s driverMemory=%s executorMemory=%s numExecutors=%s\n' \
  "$name" "$application_file" "$queue" "$driver_memory" "$executor_memory" "$num_executors"

if ! submit_response="$(
  curl -sS -u "${LIVY_USER}:${LIVY_PASSWORD}" -H "Content-Type: application/json" \
    -X POST --data-binary "@${PAYLOAD_PATH}" "${LIVY_URL}/batches" -w $'\n%{http_code}'
)"; then
  printf 'Failed to submit Livy batch: url=%s/batches\n' "$LIVY_URL" >&2
  exit 1
fi

submit_status="${submit_response##*$'\n'}"
submit_body="${submit_response%$'\n'*}"
[[ "$submit_status" =~ ^[0-9]{3}$ ]] || { printf 'Failed to parse Livy submit HTTP status\n' >&2; exit 1; }
if (( submit_status < 200 || submit_status >= 300 )); then
  printf 'Livy submit failed: status=%s url=%s/batches\n' "$submit_status" "$LIVY_URL" >&2
  [[ -z "$submit_body" ]] || printf '%s\n' "$submit_body" >&2
  exit 1
fi

if ! batch_id="$(
  printf '%s' "$submit_body" | python3 -c '
import json, sys
try:
    v = json.load(sys.stdin).get("id")
except (AttributeError, json.JSONDecodeError):
    raise SystemExit(2)
if isinstance(v, bool) or not isinstance(v, int) or v < 0:
    raise SystemExit(2)
print(v)
'
)"; then
  printf 'Livy submit response did not contain a valid integer batch id\n' >&2
  exit 1
fi

printf 'Livy batch submitted: id=%s\n' "$batch_id"
[[ "$no_wait" == true ]] && exit 0

fetch_logs() {
  local resp status body
  resp="$(curl -sS -u "${LIVY_USER}:${LIVY_PASSWORD}" \
    "${LIVY_URL}/batches/${batch_id}/log?from=0&size=200" -w $'\n%{http_code}')" || {
    printf 'Failed to query Livy batch logs: id=%s\n' "$batch_id" >&2
    return
  }
  status="${resp##*$'\n'}"; body="${resp%$'\n'*}"
  if [[ "$status" =~ ^[0-9]{3}$ ]] && (( status >= 200 && status < 300 )); then
    [[ -z "$body" ]] || printf '%s\n' "$body" >&2
  else
    printf 'Livy log query failed: id=%s status=%s\n' "$batch_id" "$status" >&2
  fi
}

elapsed=0
while true; do
  state_response="$(curl -sS -u "${LIVY_USER}:${LIVY_PASSWORD}" \
    "${LIVY_URL}/batches/${batch_id}/state" -w $'\n%{http_code}')" || {
    printf 'Failed to query Livy batch state: id=%s\n' "$batch_id" >&2
    exit 1
  }
  state_status="${state_response##*$'\n'}"
  state_body="${state_response%$'\n'*}"
  if [[ ! "$state_status" =~ ^[0-9]{3}$ ]] || (( state_status < 200 || state_status >= 300 )); then
    printf 'Livy state query failed: id=%s status=%s\n' "$batch_id" "$state_status" >&2
    exit 1
  fi

  if ! state="$(printf '%s' "$state_body" | python3 -c '
import json, sys
try:
    v = json.load(sys.stdin).get("state")
except (AttributeError, json.JSONDecodeError):
    raise SystemExit(2)
if not isinstance(v, str) or not v:
    raise SystemExit(2)
print(v)
')"; then
    printf 'Livy state response did not contain a valid state: id=%s\n' "$batch_id" >&2
    exit 1
  fi

  printf 'Livy batch state: id=%s state=%s elapsed=%ss\n' "$batch_id" "$state" "$elapsed"
  case "$state" in
    success) printf 'Livy batch succeeded: id=%s\n' "$batch_id"; exit 0 ;;
    dead|error|killed)
      printf 'Livy batch failed: id=%s state=%s\n' "$batch_id" "$state" >&2
      fetch_logs; exit 1 ;;
    not_started|starting|running|recovering)
      if (( elapsed >= LIVY_MAX_WAIT_SEC )); then
        printf 'Livy batch wait timed out: id=%s maxWait=%ss\n' "$batch_id" "$LIVY_MAX_WAIT_SEC" >&2
        fetch_logs; exit 1
      fi ;;
    *) printf 'Unexpected Livy batch state: %s\n' "$state" >&2; exit 1 ;;
  esac

  sleep "$LIVY_POLL_INTERVAL_SEC"
  elapsed=$((elapsed + LIVY_POLL_INTERVAL_SEC))
done
