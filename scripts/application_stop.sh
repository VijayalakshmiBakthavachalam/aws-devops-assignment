#!/bin/bash
# CodeDeploy ApplicationStop: stop the Flask app
set -e
APP_DIR=/var/www/devops-demo
PID_FILE=$APP_DIR/app.pid

if [ -f "$PID_FILE" ]; then
  PID=$(cat "$PID_FILE")
  if kill -0 "$PID" 2>/dev/null; then
    kill "$PID" || true
    sleep 2
    kill -9 "$PID" 2>/dev/null || true
  fi
  rm -f "$PID_FILE"
fi

# Also stop any existing process bound to port 8000
pkill -f "python.*app.py" 2>/dev/null || true
exit 0
