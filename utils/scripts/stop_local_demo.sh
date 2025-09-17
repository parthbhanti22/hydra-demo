#!/usr/bin/env bash
cd "$(dirname "$0")/../../"
echo "[Hydra] Stopping services..."
docker compose down
