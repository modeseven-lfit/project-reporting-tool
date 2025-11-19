#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 The Linux Foundation

set -euo pipefail

# Script to download workflow run artifacts for meta-reporting
# This script downloads raw data artifacts from workflow runs to enable
# tracking of Jenkins-to-GitHub workflow migration progress over time.
#
# Usage:
#   ./download-artifacts.sh <workflow_name> <output_dir> [days_back]
#
# Arguments:
#   workflow_name: Name of the workflow (e.g., "reporting-production.yaml")
#   output_dir: Directory to store downloaded artifacts
#   days_back: Number of days to look back for runs (default: 30)
#
# Environment variables:
#   GITHUB_TOKEN: GitHub token with repo access (required)
#   GITHUB_REPOSITORY: Repository in format "owner/repo" (optional, auto-detected)

WORKFLOW_NAME="${1:-}"
OUTPUT_DIR="${2:-./artifacts}"
DAYS_BACK="${3:-30}"

# Validate inputs
if [ -z "$WORKFLOW_NAME" ]; then
  echo "Error: workflow_name is required"
  echo "Usage: $0 <workflow_name> <output_dir> [days_back]"
  exit 1
fi

if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "Error: GITHUB_TOKEN environment variable is required"
  echo "Set it with: export GITHUB_TOKEN=ghp_..."
  exit 1
fi

# Auto-detect repository if not set
if [ -z "${GITHUB_REPOSITORY:-}" ]; then
  if [ -d ".git" ]; then
    GITHUB_REPOSITORY=$(git remote get-url origin | \
      sed -E 's|.*/([^/]+/[^/]+)(\.git)?$|\1|')
    echo "Auto-detected repository: $GITHUB_REPOSITORY"
  else
    echo "Error: GITHUB_REPOSITORY environment variable required (not in git repo)"
    exit 1
  fi
fi

# Extract owner and repo
OWNER=$(echo "$GITHUB_REPOSITORY" | cut -d'/' -f1)
REPO=$(echo "$GITHUB_REPOSITORY" | cut -d'/' -f2)

echo "🔍 Downloading artifacts from workflow: $WORKFLOW_NAME"
echo "📁 Output directory: $OUTPUT_DIR"
echo "📅 Looking back: $DAYS_BACK days"
echo "🏢 Repository: $GITHUB_REPOSITORY"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Calculate date threshold
if command -v gdate &> /dev/null; then
  # macOS with GNU coreutils installed
  DATE_THRESHOLD=$(gdate -u -d "$DAYS_BACK days ago" +%Y-%m-%dT%H:%M:%SZ)
else
  # Linux
  DATE_THRESHOLD=$(date -u -d "$DAYS_BACK days ago" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || \
    date -u -v-"${DAYS_BACK}"d +%Y-%m-%dT%H:%M:%SZ)
fi

echo "📅 Fetching runs since: $DATE_THRESHOLD"
echo ""

# Fetch workflow runs
API_URL="https://api.github.com/repos/$OWNER/$REPO/actions/workflows/$WORKFLOW_NAME/runs"
RUNS_JSON=$(curl -sS -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "$API_URL?created=>=$DATE_THRESHOLD&status=completed&per_page=100")

# Check for errors
if echo "$RUNS_JSON" | jq -e '.message' > /dev/null 2>&1; then
  echo "Error from GitHub API:"
  echo "$RUNS_JSON" | jq -r '.message'
  exit 1
fi

# Count runs
RUN_COUNT=$(echo "$RUNS_JSON" | jq '.workflow_runs | length')
echo "✅ Found $RUN_COUNT completed workflow run(s)"

if [ "$RUN_COUNT" -eq 0 ]; then
  echo "No runs found to process"
  exit 0
fi

echo ""
echo "📦 Processing runs and downloading artifacts..."
echo ""

# Process each run
TOTAL_ARTIFACTS=0
DOWNLOADED_ARTIFACTS=0

echo "$RUNS_JSON" | jq -c '.workflow_runs[]' | while read -r run; do
  RUN_ID=$(echo "$run" | jq -r '.id')
  RUN_NUMBER=$(echo "$run" | jq -r '.run_number')
  RUN_DATE=$(echo "$run" | jq -r '.created_at')
  RUN_STATUS=$(echo "$run" | jq -r '.conclusion')

  echo "📋 Run #$RUN_NUMBER (ID: $RUN_ID)"
  echo "   Status: $RUN_STATUS | Date: $RUN_DATE"

  # Create run directory
  RUN_DIR="$OUTPUT_DIR/run-$RUN_ID"
  mkdir -p "$RUN_DIR"

  # Save run metadata
  echo "$run" | jq '.' > "$RUN_DIR/run-metadata.json"

  # Fetch artifacts for this run
  ARTIFACTS_URL="https://api.github.com/repos/$OWNER/$REPO/actions/runs/$RUN_ID/artifacts"
  ARTIFACTS_JSON=$(curl -sS -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "$ARTIFACTS_URL")

  ARTIFACT_COUNT=$(echo "$ARTIFACTS_JSON" | jq '.artifacts | length')
  TOTAL_ARTIFACTS=$((TOTAL_ARTIFACTS + ARTIFACT_COUNT))

  if [ "$ARTIFACT_COUNT" -eq 0 ]; then
    echo "   ℹ️  No artifacts found"
    echo ""
    continue
  fi

  echo "   📦 Found $ARTIFACT_COUNT artifact(s)"

  # Download each artifact (only raw-data artifacts for meta-reporting)
  echo "$ARTIFACTS_JSON" | jq -c '.artifacts[]' | while read -r artifact; do
    ARTIFACT_NAME=$(echo "$artifact" | jq -r '.name')
    ARTIFACT_SIZE=$(echo "$artifact" | jq -r '.size_in_bytes')
    DOWNLOAD_URL=$(echo "$artifact" | jq -r '.archive_download_url')

    # Only download raw-data artifacts to conserve space
    if [[ ! "$ARTIFACT_NAME" =~ ^(raw-data-|previews-raw-data-) ]]; then
      echo "   ⏭️  Skipping: $ARTIFACT_NAME (not raw data)"
      continue
    fi

    echo "   ⬇️  Downloading: $ARTIFACT_NAME ($((ARTIFACT_SIZE / 1024)) KB)"

    ARTIFACT_FILE="$RUN_DIR/${ARTIFACT_NAME}.zip"

    if [ -f "$ARTIFACT_FILE" ]; then
      echo "      ℹ️  Already exists, skipping"
      continue
    fi

    # Download artifact
    if curl -sS -L -H "Authorization: Bearer $GITHUB_TOKEN" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "$DOWNLOAD_URL" -o "$ARTIFACT_FILE"; then

      # Extract the zip file
      EXTRACT_DIR="$RUN_DIR/${ARTIFACT_NAME}"
      mkdir -p "$EXTRACT_DIR"
      unzip -q "$ARTIFACT_FILE" -d "$EXTRACT_DIR"
      rm "$ARTIFACT_FILE"

      echo "      ✅ Downloaded and extracted"
      DOWNLOADED_ARTIFACTS=$((DOWNLOADED_ARTIFACTS + 1))
    else
      echo "      ❌ Failed to download"
      rm -f "$ARTIFACT_FILE"
    fi
  done

  echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Download complete"
echo ""
echo "📊 Summary:"
echo "   Workflow runs processed: $RUN_COUNT"
echo "   Total artifacts found: $TOTAL_ARTIFACTS"
echo "   Raw data artifacts downloaded: $DOWNLOADED_ARTIFACTS"
echo "   Output directory: $OUTPUT_DIR"
echo ""

# Generate a summary index
SUMMARY_FILE="$OUTPUT_DIR/summary.json"
echo "📄 Generating summary index: $SUMMARY_FILE"

cat > "$SUMMARY_FILE" <<EOF
{
  "workflow": "$WORKFLOW_NAME",
  "repository": "$GITHUB_REPOSITORY",
  "downloaded_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "days_back": $DAYS_BACK,
  "date_threshold": "$DATE_THRESHOLD",
  "runs_processed": $RUN_COUNT,
  "artifacts_downloaded": $DOWNLOADED_ARTIFACTS,
  "output_directory": "$OUTPUT_DIR"
}
EOF

echo "✅ Summary index created"
echo ""
echo "🎯 Next steps:"
echo "   1. Review downloaded data in: $OUTPUT_DIR"
echo "   2. Use the raw JSON files for meta-reporting"
echo "   3. Generate trend analysis and migration progress reports"
echo ""
echo "💡 Tip: You can now analyze the report_raw.json files to track:"
echo "   - Jenkins job counts over time"
echo "   - GitHub Actions adoption rates"
echo "   - Repository activity trends"
echo "   - Migration progress metrics"
echo ""
