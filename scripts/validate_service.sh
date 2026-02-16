#!/bin/bash
# CodeDeploy ValidateService: health check on port 8000
set -e
for i in 1 2 3 4 5 6 7 8 9 10; do
  if curl -sf http://localhost:8000/health > /dev/null; then
    echo "Health check passed."
    exit 0
  fi
  sleep 3
done
echo "Health check failed after 30 seconds."
exit 1
