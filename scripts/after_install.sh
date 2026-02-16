#!/bin/bash
# CodeDeploy AfterInstall: set permissions and install Python dependencies in venv
set -e
APP_DIR=/var/www/devops-demo
cd "$APP_DIR"

# Ensure virtual environment exists (created by EC2 UserData or create here)
if [ ! -d "$APP_DIR/.venv" ]; then
  python3 -m venv .venv
fi

.venv/bin/pip install --upgrade pip --quiet
.venv/bin/pip install -r requirements.txt --quiet

# Owned by root so CodeDeploy can overwrite; app runs as root in this demo
chown -R root:root "$APP_DIR"
chmod +x scripts/*.sh 2>/dev/null || true
exit 0
