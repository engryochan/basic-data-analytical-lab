set -euo pipefail

TASK_COMMAND='${TASK_COMMAND}'
export TASK_COMMAND
export AS_OF_TIME='${AS_OF_TIME}'

if [[ -f "$PWD/wm-live-risk/business-risk/scripts/business-risk-task.sh" ]]; then
  TASK_RESOURCE_ROOT="$PWD/wm-live-risk/business-risk"
  TASK_SCRIPT="$TASK_RESOURCE_ROOT/scripts/business-risk-task.sh"
elif [[ -f "$PWD/scripts/business-risk-task.sh" ]]; then
  TASK_RESOURCE_ROOT="$PWD"
  TASK_SCRIPT="$TASK_RESOURCE_ROOT/scripts/business-risk-task.sh"
elif [[ -f "$PWD/business-risk-task.sh" ]]; then
  TASK_RESOURCE_ROOT="$PWD"
  TASK_SCRIPT="$TASK_RESOURCE_ROOT/business-risk-task.sh"
else
  echo "business-risk-task.sh not found" >&2
  exit 1
fi

resolve_ca() {
  local name="$1"
  if [[ -f "$TASK_RESOURCE_ROOT/certs/$name" ]]; then
    printf '%s\n' "$TASK_RESOURCE_ROOT/certs/$name"
  elif [[ -f "$TASK_RESOURCE_ROOT/$name" ]]; then
    printf '%s\n' "$TASK_RESOURCE_ROOT/$name"
  else
    echo "$name not found" >&2
    exit 1
  fi
}

export SR_MYSQL_SSL_CA="$(resolve_ca starrocks-ca.pem)"
bash "$TASK_SCRIPT" "$TASK_COMMAND"
