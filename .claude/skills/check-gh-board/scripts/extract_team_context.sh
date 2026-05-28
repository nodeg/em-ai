#!/usr/bin/env bash
# extract_team_context.sh — Extract minimal team context for cost optimization
#
# Usage:
#   ./extract_team_context.sh <team_file>
#
# Outputs JSON with only the essential fields:
#   {
#     "org": "SUSE",
#     "project_number": "32",
#     "team_roster": ["Name 1", "Name 2", ...]
#   }
#
# Cost: ~150 tokens instead of ~800 tokens for full team file

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <team_file>" >&2
  exit 1
fi

TEAM_FILE=$1

if [[ ! -f "$TEAM_FILE" ]]; then
  echo "Error: Team file not found: $TEAM_FILE" >&2
  exit 1
fi

# Extract Default board: github:ORG/PROJECT
DEFAULT_BOARD=$(grep -i "Default board:" "$TEAM_FILE" | head -1 | sed 's/.*github://g' | xargs)

if [[ -z "$DEFAULT_BOARD" ]]; then
  echo "Error: No 'Default board: github:ORG/PROJECT' found in $TEAM_FILE" >&2
  echo "Please add this line to the '## Overview' section:" >&2
  echo "  - Default board: github:ORG_NAME/PROJECT_NUMBER" >&2
  exit 1
fi

ORG_NAME=$(echo "$DEFAULT_BOARD" | cut -d/ -f1)
PROJECT_NUMBER=$(echo "$DEFAULT_BOARD" | cut -d/ -f2)

if [[ -z "$ORG_NAME" ]] || [[ -z "$PROJECT_NUMBER" ]]; then
  echo "Error: Could not parse org/project from: $DEFAULT_BOARD" >&2
  exit 1
fi

# Extract all full names (team roster for idle filtering)
TEAM_ROSTER=$(grep -i "Full name:" "$TEAM_FILE" | sed 's/.*Full name://g' | sed 's/^ *//g' | sed 's/ *$//g')

if [[ -z "$TEAM_ROSTER" ]]; then
  TEAM_ROSTER_JSON="[]"
else
  # Convert to JSON array
  TEAM_ROSTER_JSON=$(echo "$TEAM_ROSTER" | jq -R -s -c 'split("\n") | map(select(length > 0))')
fi

# Output minimal JSON
jq -n \
  --arg org "$ORG_NAME" \
  --arg project "$PROJECT_NUMBER" \
  --argjson roster "$TEAM_ROSTER_JSON" \
  '{
    org: $org,
    project_number: $project,
    team_roster: $roster
  }'
