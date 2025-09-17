#!/usr/bin/env bash
set -euo pipefail

if [ "${1:-}" == "" ]; then
  echo "Usage: $0 <codebuild_project_name> --confirm"
  exit 1
fi

PROJECT_NAME="$1"
CONFIRM="${2:-}"

if [ "$CONFIRM" != "--confirm" ]; then
  echo "Aborting: You must pass --confirm to run the AWS demo (safety guard)."
  exit 1
fi

echo "Starting CodeBuild project: $PROJECT_NAME"
BUILD_ID=$(aws codebuild start-build --project-name "$PROJECT_NAME" --query 'build.id' --output text)
echo "Build started: $BUILD_ID"

echo "Polling build status..."
while true; do
  STATUS=$(aws codebuild batch-get-builds --ids "$BUILD_ID" --query 'builds[0].buildStatus' --output text)
  echo "Status: $STATUS"
  if [[ "$STATUS" == "SUCCEEDED" || "$STATUS" == "FAILED" ]]; then
    break
  fi
  sleep 6
done

echo "Build finished. Check CodeBuild console for logs. Build ID: $BUILD_ID"
