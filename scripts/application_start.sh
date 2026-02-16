#!/bin/bash
# CodeDeploy ApplicationStart: start the Flask app on port 8000
# Secret name is passed from infra stack via /etc/devops-demo/secret-name (written by cfn-init)
set -e
APP_DIR=/var/www/devops-demo
cd "$APP_DIR"

if [ -f /etc/devops-demo/secret-name ]; then
  export APP_SECRET_NAME=$(cat /etc/devops-demo/secret-name)
else
  export APP_SECRET_NAME="${APP_SECRET_NAME:-devops-demo/app-secret}"
fi

# Start app in background; use venv Python
nohup .venv/bin/python app.py > /var/log/devops-demo-app.log 2>&1 &
echo $! > "$APP_DIR/app.pid"
exit 0
