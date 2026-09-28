#!/bin/bash
set -euo pipefail

# Contract tests for the Parker (HyperPod workspace) startup scripts.

for app in jupyterlab code-editor; do
  for cmd in entrypoint-workspace-$app start-workspace-$app restart-workspace-$app; do
    command -v "$cmd" >/dev/null || { echo "missing $cmd"; exit 1; }
    bash -n "$(command -v "$cmd")"
  done
  test -f /etc/supervisor/conf.d/supervisord-workspace-$app.conf
done

# Each app must come up via supervisord behind WORKSPACE_BASE_URL, even when no Native SSH config is present.
export WORKSPACE_BASE_URL=/workspaces/test/
sudo mkdir -p /var/log/sagemaker/workspace /var/run/supervisord
sudo chown -R "$(id -u)" /var/log/sagemaker/workspace /var/run/supervisord

wait_for_app() {
  local app=$1 path=$2 pid
  entrypoint-workspace-$app > /tmp/workspace-$app.log 2>&1 &
  pid=$!
  for i in $(seq 1 60); do
    if curl -sf "http://localhost:8888${WORKSPACE_BASE_URL}${path}" >/dev/null; then
      echo "$app workspace is up"
      kill "$pid"
      wait "$pid" || true
      return 0
    fi
    sleep 2
  done
  cat /tmp/workspace-$app.log
  return 1
}

wait_for_app jupyterlab api/status
wait_for_app code-editor ""
