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

# JupyterLab must come up behind WORKSPACE_BASE_URL via supervisord, even when no Native SSH config is present.
export WORKSPACE_BASE_URL=/workspaces/test/
sudo mkdir -p /var/log/sagemaker/workspace /var/run/supervisord
sudo chown -R "$(id -u)" /var/log/sagemaker/workspace /var/run/supervisord
entrypoint-workspace-jupyterlab > /tmp/workspace.log 2>&1 &

for i in $(seq 1 60); do
  if curl -sf "http://localhost:8888${WORKSPACE_BASE_URL}api/status" >/dev/null; then
    echo "JupyterLab workspace is up"
    exit 0
  fi
  sleep 2
done
cat /tmp/workspace.log
exit 1
