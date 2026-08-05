#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  ryochan_sparklyr_submit.sh \
    --name NAME \
    --file s3://bucket/job.R \
    [--jars URI[,URI...]] \
    [--files URI[,URI...]] \
    [--env KEY=VALUE]... \
    -- [job arguments...]

v2: this script localises --file/--jars/--files from S3 and then runs
Rscript directly. It deliberately does NOT build a Livy batch JSON
payload the way the old sparkr_submit.sh did: sparklyr already
implements the Livy session protocol internally (spark_connect(method =
"livy", ...)), so re-implementing that protocol in bash was redundant,
and sparklyr's own documentation recommends a direct edge-node
connection over Livy whenever one is available -- which is now the case
for this DolphinScheduler worker.

The R script itself decides shell vs. livy via environment variables it
reads (set them with --env below, or via the worker's own
DolphinScheduler "环境管理" environment):
  SPARKLYR_CONNECT_METHOD   shell (default) or livy
  SPARKLYR_MASTER           yarn (default for shell) or the Livy URL
  LIVY_USER / LIVY_PASSWORD only read when SPARKLYR_CONNECT_METHOD=livy
  SPARKLYR_SHUFFLE_PARTITIONS

Passthrough warning:
  --jars, --files, and --env accept trusted-administrator input and are
  not further sandboxed beyond the S3-URI checks below. Do not pass
  secrets through --env on this command line -- command-line arguments
  are visible to other local users via `ps`. Use the worker's
  DolphinScheduler environment for LIVY_PASSWORD and similar.
USAGE
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 2
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

name=""
application_file=""
jar_specs=()
file_specs=()
env_entries=()
job_arguments=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)
      [[ -n "${2:-}" ]] || fail "--name requires a value"
      name="$2"; shift 2 ;;
    --file)
      [[ -n "${2:-}" ]] || fail "--file requires a value"
      application_file="$2"; shift 2 ;;
    --jars)
      [[ -n "${2:-}" ]] || fail "--jars requires a value"
      jar_specs+=("$2"); shift 2 ;;
    --files)
      [[ -n "${2:-}" ]] || fail "--files requires a value"
      file_specs+=("$2"); shift 2 ;;
    --env)
      [[ -n "${2:-}" ]] || fail "--env requires a value"
      [[ "$2" == *=* ]] || fail "--env must use KEY=VALUE"
      env_entries+=("$2"); shift 2 ;;
    --)
      shift
      job_arguments=("$@")
      break ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      fail "Unknown argument: $1" ;;
  esac
done

[[ -n "$name" ]] || fail "--name is required"
[[ "$name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$ ]] ||
  fail "--name must start with an ASCII alphanumeric character and contain only ASCII alphanumerics, dot, underscore, or hyphen"

[[ -n "$application_file" ]] || fail "--file is required"
require_s3_uri "$application_file"
case "$application_file" in
  *.R|*.r) ;;
  *) fail "--file must reference a .R or .r object" ;;
esac

for jar_spec in "${jar_specs[@]}"; do
  require_nonempty_csv_entries "--jars" "$jar_spec"
  IFS=',' read -ra entries <<< "$jar_spec"
  for entry in "${entries[@]}"; do
    require_s3_uri "$entry"
    case "$entry" in
      *.jar) ;;
      *) fail "--jars entries must reference .jar objects: $entry" ;;
    esac
  done
done

for file_spec in "${file_specs[@]}"; do
  require_nonempty_csv_entries "--files" "$file_spec"
  IFS=',' read -ra entries <<< "$file_spec"
  for entry in "${entries[@]}"; do
    require_s3_uri "$entry"
  done
done

command -v Rscript >/dev/null 2>&1 || fail "Missing required command: Rscript"
command -v aws >/dev/null 2>&1 || fail "Missing required command: aws (aws-cli, used to localise --file/--jars/--files from S3)"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

local_file="$WORKDIR/$(basename "$application_file")"
aws s3 cp "$application_file" "$local_file" --only-show-errors ||
  fail "Failed to download --file from S3: $application_file"

local_jars=()
for jar_spec in "${jar_specs[@]}"; do
  IFS=',' read -ra entries <<< "$jar_spec"
  for entry in "${entries[@]}"; do
    dest="$WORKDIR/$(basename "$entry")"
    aws s3 cp "$entry" "$dest" --only-show-errors || fail "Failed to download --jars entry: $entry"
    local_jars+=("$dest")
  done
done

for file_spec in "${file_specs[@]}"; do
  IFS=',' read -ra entries <<< "$file_spec"
  for entry in "${entries[@]}"; do
    dest="$WORKDIR/$(basename "$entry")"
    aws s3 cp "$entry" "$dest" --only-show-errors || fail "Failed to download --files entry: $entry"
  done
done

if (( ${#local_jars[@]} > 0 )); then
  joined_jars="$(IFS=,; echo "${local_jars[*]}")"
  export SPARKLYR_EXTRA_JARS="$joined_jars"
fi

for entry in "${env_entries[@]}"; do
  key="${entry%%=*}"
  value="${entry#*=}"
  [[ -n "$key" && "$key" != *[[:space:]]* ]] || fail "--env key must be non-empty and contain no whitespace: $entry"
  export "$key=$value"
done

printf 'Running sparklyr job: name=%s file=%s connect_method=%s master=%s jars=%d files=%d\n' \
  "$name" \
  "$application_file" \
  "${SPARKLYR_CONNECT_METHOD-shell}" \
  "${SPARKLYR_MASTER-yarn}" \
  "${#local_jars[@]}" \
  "${#file_specs[@]}"

cd "$WORKDIR"
exec Rscript "$local_file" -- "${job_arguments[@]}"
