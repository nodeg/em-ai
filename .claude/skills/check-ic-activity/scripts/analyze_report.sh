#!/usr/bin/env bash

# Lightweight report analyzer - bypasses skill wrapper for cost optimization
# Usage: analyze_report.sh <github_username> <from_date> <to_date> [team_file]

set -euo pipefail

GITHUB_USER=$1
FROM=$2
TO=$3
TEAM_FILE=${4:-}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Run the activity script to get JSON data
JSON_DATA=$(bash "$SCRIPT_DIR/run_ic_activity.sh" "$GITHUB_USER" "$FROM" "$TO")

# Extract just the relevant team member info if team file provided
if [[ -n "$TEAM_FILE" ]] && [[ -f "$TEAM_FILE" ]]; then
  # Find the section containing this GitHub username, then go backwards to get Full name
  LINE_NUM=$(grep -n "Github username.*$GITHUB_USER" "$TEAM_FILE" | cut -d: -f1)
  if [[ -n "$LINE_NUM" ]]; then
    # Get lines around this username (5 before, 5 after)
    SECTION=$(sed -n "$((LINE_NUM-5)),$((LINE_NUM+5))p" "$TEAM_FILE")
    FULL_NAME=$(echo "$SECTION" | grep -i "Full name:" | cut -d: -f2- | xargs || echo "Unknown")
    ROLE=$(echo "$SECTION" | grep -i "Role:" | cut -d: -f2- | xargs || echo "Unknown")
  else
    FULL_NAME="Unknown"
    ROLE="Unknown"
  fi
else
  FULL_NAME="Unknown"
  ROLE="Unknown"
fi

# Output compact JSON for Claude to format
cat <<EOF
{
  "github_username": "$GITHUB_USER",
  "full_name": "$FULL_NAME",
  "role": "$ROLE",
  "period": {"from": "$FROM", "to": "$TO"},
  "data": $JSON_DATA
}
EOF
