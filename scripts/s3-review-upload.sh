#!/usr/bin/env bash
# Upload a local file to the peakweb-team review S3 bucket and print the public URL.
#
# Usage:
#   ./scripts/s3-review-upload.sh <local-file> <repo-name> <issue-or-pr-number>
#
# Example:
#   ./scripts/s3-review-upload.sh /tmp/screenshot.png superagents 123
#
# Required env vars (set on host Mac, forwarded into devcontainer via containerEnv):
#   SUPERAGENTS_S3_ACCESS_KEY_ID
#   SUPERAGENTS_S3_SECRET_ACCESS_KEY
#   SUPERAGENTS_S3_REGION
#   SUPERAGENTS_S3_BUCKET
#
# Object key convention: <repo-name>/<issue-or-pr-number>/<filename>
# Bucket must have public-read ACL or a bucket policy granting s3:GetObject to *.

set -euo pipefail

LOCAL_FILE="${1:-}"
REPO_NAME="${2:-}"
REF="${3:-}"

if [[ -z "$LOCAL_FILE" || -z "$REPO_NAME" || -z "$REF" ]]; then
  echo "Usage: $0 <local-file> <repo-name> <issue-or-pr-number>" >&2
  exit 1
fi

if [[ ! -f "$LOCAL_FILE" ]]; then
  echo "Error: file not found: $LOCAL_FILE" >&2
  exit 1
fi

: "${SUPERAGENTS_S3_ACCESS_KEY_ID:?SUPERAGENTS_S3_ACCESS_KEY_ID is not set}"
: "${SUPERAGENTS_S3_SECRET_ACCESS_KEY:?SUPERAGENTS_S3_SECRET_ACCESS_KEY is not set}"
: "${SUPERAGENTS_S3_REGION:?SUPERAGENTS_S3_REGION is not set}"
: "${SUPERAGENTS_S3_BUCKET:?SUPERAGENTS_S3_BUCKET is not set}"

FILENAME="$(basename "$LOCAL_FILE")"
S3_KEY="${REPO_NAME}/${REF}/${FILENAME}"

AWS_ACCESS_KEY_ID="$SUPERAGENTS_S3_ACCESS_KEY_ID" \
AWS_SECRET_ACCESS_KEY="$SUPERAGENTS_S3_SECRET_ACCESS_KEY" \
AWS_DEFAULT_REGION="$SUPERAGENTS_S3_REGION" \
  aws s3 cp "$LOCAL_FILE" "s3://${SUPERAGENTS_S3_BUCKET}/${S3_KEY}" --acl public-read

echo "https://${SUPERAGENTS_S3_BUCKET}.s3.${SUPERAGENTS_S3_REGION}.amazonaws.com/${S3_KEY}"
