#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../"

echo "[Hydra] Building and starting static site..."
docker compose build static-site load-tester

echo "[Hydra] Starting static-site..."
docker compose up -d static-site
sleep 3
echo "[Hydra] Static site -> http://localhost:8080"

echo "To start the load test, run the command below with explicit confirmation:"
echo "  ./utils/scripts/run_local_demo.sh --start-load --vus=100 --duration=60s --confirm"
if [ "${1:-}" == "--start-load" ]; then
  # require explicit confirm
  if [ "${4:-}" != "--confirm" ]; then
    echo "Load test aborted: you must pass --confirm as the last argument"
    exit 1
  fi
  VUS=${2#--vus=} || VUS=50
  DURATION=${3#--duration=} || DURATION=30s
  echo "[Hydra] Starting load test with VUS=$VUS, DURATION=$DURATION"
  docker compose run --rm -e TARGET_URL="http://host.docker.internal:8080" -e K6_VUS="$VUS" -e K6_DURATION="$DURATION" load-tester
fi
