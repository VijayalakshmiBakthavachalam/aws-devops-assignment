#!/bin/bash
# CodeDeploy BeforeInstall: optional backup / prep
set -e
APP_DIR=/var/www/devops-demo
if [ -d "$APP_DIR" ] && [ -f "$APP_DIR/app.py" ]; then
  # Optional: backup current app (e.g. for rollback)
  if [ ! -d "$APP_DIR/backup" ]; then
    mkdir -p "$APP_DIR/backup"
  fi
  cp -a "$APP_DIR/app.py" "$APP_DIR/backup/app.py.bak" 2>/dev/null || true
fi
exit 0
