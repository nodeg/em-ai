#!/usr/bin/env bash

set -euo pipefail

GITHUB_USER=$1
FROM=$2
TO=$3

# Load credentials
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../../../../.env.local"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi
export GH_TOKEN=${GITHUB_TOKEN:-${GH_TOKEN:-}}

# Cache configuration
CACHE_DIR="$SCRIPT_DIR/../../../../data/github/cache"
CACHE_TTL_HOURS=${CACHE_TTL_HOURS:-24}  # Default 24 hours
FORCE_REFRESH=${FORCE_REFRESH:-false}   # Set to true to bypass cache
mkdir -p "$CACHE_DIR"

# Generate cache key based on user and date range
CACHE_KEY="${GITHUB_USER}_${FROM}_${TO}"
CACHE_FILE="$CACHE_DIR/${CACHE_KEY}.json"
CACHE_META="$CACHE_DIR/${CACHE_KEY}.meta"

# Check if cache exists and is fresh
USE_CACHE=false
if [[ "$FORCE_REFRESH" != "true" ]] && [[ -f "$CACHE_FILE" ]] && [[ -f "$CACHE_META" ]]; then
  CACHE_TIME=$(cat "$CACHE_META")
  CURRENT_TIME=$(date +%s)
  CACHE_AGE_HOURS=$(( (CURRENT_TIME - CACHE_TIME) / 3600 ))

  if [[ $CACHE_AGE_HOURS -lt $CACHE_TTL_HOURS ]]; then
    USE_CACHE=true
    >&2 echo "Using cached data (age: ${CACHE_AGE_HOURS}h, TTL: ${CACHE_TTL_HOURS}h)"
  else
    >&2 echo "Cache expired (age: ${CACHE_AGE_HOURS}h, TTL: ${CACHE_TTL_HOURS}h), fetching fresh data"
  fi
fi

# Get initial rate limit info for both APIs
RATE_LIMITS=$(gh api rate_limit)
SEARCH_LIMIT=$(echo "$RATE_LIMITS" | jq '.resources.search')
CORE_LIMIT=$(echo "$RATE_LIMITS" | jq '.resources.core')

SEARCH_REMAINING=$(echo "$SEARCH_LIMIT" | jq -r '.remaining')
SEARCH_LIMIT_MAX=$(echo "$SEARCH_LIMIT" | jq -r '.limit')
SEARCH_RESET=$(echo "$SEARCH_LIMIT" | jq -r '.reset')

CORE_REMAINING=$(echo "$CORE_LIMIT" | jq -r '.remaining')
CORE_LIMIT_MAX=$(echo "$CORE_LIMIT" | jq -r '.limit')
CORE_RESET=$(echo "$CORE_LIMIT" | jq -r '.reset')

# If cache is valid, return it and exit
if [[ "$USE_CACHE" == "true" ]]; then
  >&2 echo "GitHub API calls: 0 (using cache)"
  >&2 echo "GitHub API rate limits:"
  >&2 echo "  Search API: ${SEARCH_REMAINING}/${SEARCH_LIMIT_MAX} remaining"
  >&2 echo "  Core API: ${CORE_REMAINING}/${CORE_LIMIT_MAX} remaining"
  cat "$CACHE_FILE"
  exit 0
fi

# Cache miss or expired - fetch from GitHub
>&2 echo "Fetching fresh data from GitHub API for ${GITHUB_USER} (${FROM} to ${TO})"

# Initialize API call counter
API_CALLS=0

# Compute period_days from FROM and TO
if date -v-1d +"%Y-%m-%d" &>/dev/null 2>&1; then
  # macOS
  FROM_TS=$(date -j -f "%Y-%m-%d" "$FROM" +%s)
  TO_TS=$(date -j -f "%Y-%m-%d" "$TO" +%s)
else
  # Linux
  FROM_TS=$(date -d "$FROM" +%s)
  TO_TS=$(date -d "$TO" +%s)
fi
DAYS=$(( (TO_TS - FROM_TS) / 86400 + 1 ))

TS=$(date +%s)
OUT_DIR="/tmp/ic_activity_${GITHUB_USER}_${TS}"
mkdir -p "$OUT_DIR"

# --- GitHub PRs merged ---
gh search prs \
  --author "$GITHUB_USER" \
  --merged \
  --created "$FROM..$TO" \
  --json number,createdAt,closedAt,title,repository \
  > "$OUT_DIR/prs.json"
API_CALLS=$((API_CALLS + 1))

# --- GitHub PRs closed (not merged) ---
gh search prs \
  --author "$GITHUB_USER" \
  --state closed \
  --created "$FROM..$TO" \
  --json number,repository,state \
  > "$OUT_DIR/prs_closed.json"
API_CALLS=$((API_CALLS + 1))

# --- GitHub PRs open ---
gh search prs \
  --author "$GITHUB_USER" \
  --state open \
  --json number,repository,title,updatedAt \
  > "$OUT_DIR/prs_open.json"
API_CALLS=$((API_CALLS + 1))

# --- GitHub Reviews given ---
gh search prs \
  --reviewed-by "$GITHUB_USER" \
  --created "$FROM..$TO" \
  --json number,repository \
  > "$OUT_DIR/reviews.json"
API_CALLS=$((API_CALLS + 1))

# --- GitHub Commits ---
gh search commits \
  --author "$GITHUB_USER" \
  --committer-date "$FROM..$TO" \
  --json commit,repository \
  > "$OUT_DIR/commits.json"
API_CALLS=$((API_CALLS + 1))

# --- GitHub Issues closed/completed ---
gh search issues \
  --assignee "$GITHUB_USER" \
  --state closed \
  --closed "$FROM..$TO" \
  --json number,title,closedAt,labels,repository \
  > "$OUT_DIR/issues.json"
API_CALLS=$((API_CALLS + 1))

# --- GitHub Issues currently open/in progress ---
gh search issues \
  --assignee "$GITHUB_USER" \
  --state open \
  --json number,title,labels,repository,url,updatedAt \
  > "$OUT_DIR/issues_wip.json"
API_CALLS=$((API_CALLS + 1))

# Fetch detailed state for each open issue (to get project status/state info)
mkdir -p "$OUT_DIR/issue_states"
ISSUE_STATE_COUNT=0
jq -r '.[] | .repository.nameWithOwner + " " + (.number | tostring)' "$OUT_DIR/issues_wip.json" | \
while read -r repo number; do
  gh api "repos/$repo/issues/$number" \
    --jq '{number, title, labels: [.labels[].name], state, repository: .repository_url | split("/")[-2:] | join("/")}' \
    > "$OUT_DIR/issue_states/${repo//\//_}_${number}.json" 2>/dev/null || true
  ISSUE_STATE_COUNT=$((ISSUE_STATE_COUNT + 1))
  echo "$ISSUE_STATE_COUNT" > "$OUT_DIR/issue_state_count.tmp"
done
ISSUE_STATE_COUNT=$(cat "$OUT_DIR/issue_state_count.tmp" 2>/dev/null || echo "0")
API_CALLS=$((API_CALLS + ISSUE_STATE_COUNT))

# --- Metrics ---
PRS=$(jq length "$OUT_DIR/prs.json")
COMMITS=$(jq length "$OUT_DIR/commits.json")
COMMITS_WORK=$(jq --arg user "$GITHUB_USER" '[.[] | select(.repository.fullName | startswith($user + "/") | not)] | length' "$OUT_DIR/commits.json")
REVIEWS=$(jq length "$OUT_DIR/reviews.json")
ISSUES=$(jq 'if type == "array" then length else 0 end' "$OUT_DIR/issues.json")

# issues by label (categorize as bug, enhancement, task, etc.)
ISSUES_BY_TYPE=$(jq '
  if type == "array" then
    map(
      if (.labels | map(.name | ascii_downcase) | any(test("bug"))) then "Bug"
      elif (.labels | map(.name | ascii_downcase) | any(test("enhancement|feature"))) then "Enhancement"
      else "Task"
      end
    )
    | group_by(.)
    | map({ (.[0]): length })
    | add // {}
  else {} end
' "$OUT_DIR/issues.json")

# wip_count and open_prs will be calculated after filtering, so we use temp values here
WIP_TEMP=$(jq 'if type == "array" then length else 0 end' "$OUT_DIR/issues_wip.json")
OPEN_PRS_TEMP=$(jq length "$OUT_DIR/prs_open.json")

# prs_cancelled: closed PRs minus merged PRs
PRS_CLOSED_TOTAL=$(jq 'length' "$OUT_DIR/prs_closed.json")
PRS_CANCELLED=$((PRS_CLOSED_TOTAL - PRS))

# --- Issue cycle time: created → closed via GitHub API ---
mkdir -p "$OUT_DIR/issue_details"
ISSUE_DETAIL_COUNT=0
jq -r '.[] | .repository.nameWithOwner + " " + (.number | tostring)' "$OUT_DIR/issues.json" | \
while read -r repo number; do
  gh api "repos/$repo/issues/$number" \
    --jq '{created_at, closed_at}' \
    > "$OUT_DIR/issue_details/${number}.json" 2>/dev/null || true
  ISSUE_DETAIL_COUNT=$((ISSUE_DETAIL_COUNT + 1))
  echo "$ISSUE_DETAIL_COUNT" > "$OUT_DIR/issue_detail_count.tmp"
done
ISSUE_DETAIL_COUNT=$(cat "$OUT_DIR/issue_detail_count.tmp" 2>/dev/null || echo "0")
API_CALLS=$((API_CALLS + ISSUE_DETAIL_COUNT))

ISSUE_CYCLE_TIME_DAYS=$(
  find "$OUT_DIR/issue_details" -name '*.json' -exec cat {} \; 2>/dev/null \
  | jq -s '
    [ .[] | select(.created_at != null and .closed_at != null) |
      ((.closed_at | fromdateiso8601) - (.created_at | fromdateiso8601)) / 86400
    ] |
    if length > 0 then add / length | . * 10 | round / 10 else null end
  '
)

# --- Per-PR details via API (size, comments, cycle time) ---
mkdir -p "$OUT_DIR/pr_details"
PR_DETAIL_COUNT=0
jq -r '.[] | .repository.nameWithOwner + " " + (.number | tostring)' "$OUT_DIR/prs.json" | \
while read -r repo number; do
  gh api "repos/$repo/pulls/$number" \
    --jq '{additions, deletions, comments, review_comments, created_at, merged_at,
           pr_author: .user.login, repository: "'"$repo"'"}' \
    > "$OUT_DIR/pr_details/${number}.json" 2>/dev/null || true
  PR_DETAIL_COUNT=$((PR_DETAIL_COUNT + 1))
  echo "$PR_DETAIL_COUNT" > "$OUT_DIR/pr_detail_count.tmp"
done
PR_DETAIL_COUNT=$(cat "$OUT_DIR/pr_detail_count.tmp" 2>/dev/null || echo "0")
API_CALLS=$((API_CALLS + PR_DETAIL_COUNT))

# aggregate PR details (work repos only)
PR_DETAILS_AGG=$(
  find "$OUT_DIR/pr_details" -name '*.json' -exec cat {} \; 2>/dev/null \
  | jq -s --arg user "$GITHUB_USER" '
    map(select(.repository | startswith($user + "/") | not)) |
    if length == 0 then
      { avg_pr_size: null, total_loc: null, comments_per_pr: null, pr_cycle_time_days: null }
    else
      {
        avg_pr_size: (map(.additions + .deletions) | add / length | . * 10 | round / 10),
        total_loc: (map(.additions + .deletions) | add),
        comments_per_pr: (map(.comments + .review_comments) | add / length | . * 10 | round / 10),
        pr_cycle_time_days: (
          map(
            select(.merged_at != null) |
            ((.merged_at | fromdateiso8601) - (.created_at | fromdateiso8601)) / 86400
          ) | if length > 0 then add / length | . * 10 | round / 10 else null end
        )
      }
    end
  '
)

AVG_PR_SIZE=$(echo "$PR_DETAILS_AGG" | jq '.avg_pr_size')
TOTAL_LOC=$(echo "$PR_DETAILS_AGG" | jq '.total_loc')
COMMENTS_PER_PR=$(echo "$PR_DETAILS_AGG" | jq '.comments_per_pr')
PR_CYCLE_TIME_DAYS=$(echo "$PR_DETAILS_AGG" | jq '.pr_cycle_time_days')

# Calculate work vs personal PR counts early (needed for commits_per_pr)
PRS_WORK=$(jq --arg user "$GITHUB_USER" '[.[] | select(.repository.nameWithOwner | startswith($user + "/") | not)] | length' "$OUT_DIR/prs.json")
PRS_PERSONAL=$(jq --arg user "$GITHUB_USER" '[.[] | select(.repository.nameWithOwner | startswith($user + "/"))] | length' "$OUT_DIR/prs.json")

# avg time for the IC to submit their first review on PRs assigned to them
# For each PR the user reviewed, fetch PR details (created_at) and their first review (submitted_at)
mkdir -p "$OUT_DIR/reviewed_pr_details"
mkdir -p "$OUT_DIR/reviewed_pr_reviews"
REVIEW_API_COUNT=0
jq -r '.[] | .repository.nameWithOwner + " " + (.number | tostring)' "$OUT_DIR/reviews.json" | \
while read -r repo number; do
  gh api "repos/$repo/pulls/$number" \
    --jq '{created_at, pr_author: .user.login}' \
    > "$OUT_DIR/reviewed_pr_details/${number}.json" 2>/dev/null || true
  gh api "repos/$repo/pulls/$number/reviews" \
    --jq "[.[] | select(.user.login == \"$GITHUB_USER\" and .state != \"PENDING\")]" \
    > "$OUT_DIR/reviewed_pr_reviews/${number}.json" 2>/dev/null || true
  REVIEW_API_COUNT=$((REVIEW_API_COUNT + 2))
  echo "$REVIEW_API_COUNT" > "$OUT_DIR/review_api_count.tmp"
done
REVIEW_API_COUNT=$(cat "$OUT_DIR/review_api_count.tmp" 2>/dev/null || echo "0")
API_CALLS=$((API_CALLS + REVIEW_API_COUNT))

AVG_TIME_TO_FIRST_REVIEW=$(
  for f in "$OUT_DIR/reviewed_pr_details"/*.json; do
    number=$(basename "$f" .json)
    reviews_file="$OUT_DIR/reviewed_pr_reviews/${number}.json"
    [ -f "$reviews_file" ] || continue
    jq -n \
      --slurpfile detail "$f" \
      --slurpfile reviews "$reviews_file" \
      '{
        created_at: $detail[0].created_at,
        first_review: ($reviews[0] | sort_by(.submitted_at) | first)
      }'
  done | jq -s '
    [ .[] | select(.first_review != null) |
      ((.first_review.submitted_at | fromdateiso8601) - (.created_at | fromdateiso8601)) / 3600
    ] |
    if length > 0 then add / length * 10 | round / 10 else null end
  '
)

# commits_per_pr (work repos only)
if [[ "$PRS_WORK" -gt 0 ]]; then
  COMMITS_PER_PR=$(echo "scale=1; $COMMITS_WORK / $PRS_WORK" | bc)
else
  COMMITS_PER_PR="null"
fi

# per-week metrics
ISSUES_PER_WEEK=$(echo "scale=2; $ISSUES / $DAYS * 7" | bc)
PRS_PER_WEEK=$(echo "scale=2; $PRS / $DAYS * 7" | bc)
REVIEWS_PER_WEEK=$(echo "scale=2; $REVIEWS / $DAYS * 7" | bc)

# --- Additional detailed metrics ---

# Calculate cutoff dates for filtering old issues and PRs
if date -v-1d +"%Y-%m-%d" &>/dev/null 2>&1; then
  # macOS
  ISSUE_CUTOFF=$(date -v-2y -u +"%Y-%m-%dT%H:%M:%SZ")
  PR_CUTOFF=$(date -v-1y -u +"%Y-%m-%dT%H:%M:%SZ")
else
  # Linux
  ISSUE_CUTOFF=$(date -d "2 years ago" -u +"%Y-%m-%dT%H:%M:%SZ")
  PR_CUTOFF=$(date -d "1 year ago" -u +"%Y-%m-%dT%H:%M:%SZ")
fi

# Open issues with labels (filter out issues not updated in 2+ years)
OPEN_ISSUES_DETAIL=$(jq -c --arg cutoff "$ISSUE_CUTOFF" '[.[] | select(.updatedAt >= $cutoff) | {
  number,
  title,
  repository: .repository.nameWithOwner,
  labels: [.labels[].name],
  url
}]' "$OUT_DIR/issues_wip.json")

# Open PRs with repository info (filter out PRs not updated in 1+ year)
OPEN_PRS_DETAIL=$(jq -c --arg cutoff "$PR_CUTOFF" '[.[] | select(.updatedAt >= $cutoff) | {
  number,
  title,
  repository: .repository.nameWithOwner,
  url: ("https://github.com/" + .repository.nameWithOwner + "/pull/" + (.number | tostring))
}]' "$OUT_DIR/prs_open.json" 2>/dev/null || echo "[]")

# Calculate final WIP and OPEN_PRS counts after filtering
WIP=$(echo "$OPEN_ISSUES_DETAIL" | jq 'length')
OPEN_PRS=$(echo "$OPEN_PRS_DETAIL" | jq 'length')

# Separate personal repos (owned by the user) from work repos
PERSONAL_REPOS=$(jq -r --arg user "$GITHUB_USER" '
  [.[] | select(.repository.nameWithOwner | startswith($user + "/"))] |
  [.[].repository.nameWithOwner] | unique | sort
' "$OUT_DIR/prs.json")

WORK_REPOS=$(jq -r --arg user "$GITHUB_USER" '
  [.[] | select(.repository.nameWithOwner | startswith($user + "/") | not)] |
  [.[].repository.nameWithOwner] | unique | sort
' "$OUT_DIR/prs.json")

# Count PRs by repository (personal)
PERSONAL_REPOS_COUNT=$(jq --arg user "$GITHUB_USER" '
  [.[] | select(.repository.nameWithOwner | startswith($user + "/"))] |
  [.[].repository.nameWithOwner] | group_by(.) | map({(.[0]): length}) | add // {}
' "$OUT_DIR/prs.json")

# Count PRs by repository (work)
WORK_REPOS_COUNT=$(jq --arg user "$GITHUB_USER" '
  [.[] | select(.repository.nameWithOwner | startswith($user + "/") | not)] |
  [.[].repository.nameWithOwner] | group_by(.) | map({(.[0]): length}) | add // {}
' "$OUT_DIR/prs.json")

# Calculate work PR velocity
PRS_PER_WEEK_WORK=$(echo "scale=2; $PRS_WORK / $DAYS * 7" | bc)

# Build JSON output
RESULT=$(cat <<EOF
{
  "col_avg_time_to_first_review_as_reviewer_hours": $AVG_TIME_TO_FIRST_REVIEW,
  "col_reviews": $REVIEWS,
  "col_reviews_per_week": $REVIEWS_PER_WEEK,
  "del_pr_cycle_time_days": $PR_CYCLE_TIME_DAYS,
  "del_commits": $COMMITS_WORK,
  "del_commits_per_pr": $COMMITS_PER_PR,
  "del_issues_by_type": $ISSUES_BY_TYPE,
  "del_issue_cycle_time_days": $ISSUE_CYCLE_TIME_DAYS,
  "del_issues_completed": $ISSUES,
  "del_issues_per_week": $ISSUES_PER_WEEK,
  "del_prs_merged": $PRS_WORK,
  "del_prs_per_week": $PRS_PER_WEEK_WORK,
  "del_total_loc": $TOTAL_LOC,
  "foc_open_prs": $OPEN_PRS,
  "foc_wip_count": $WIP,
  "period_days": $DAYS,
  "qua_avg_pr_size": $AVG_PR_SIZE,
  "qua_comments_per_pr": $COMMENTS_PER_PR,
  "qua_prs_cancelled": $PRS_CANCELLED,
  "detail_open_issues": $OPEN_ISSUES_DETAIL,
  "detail_open_prs": $OPEN_PRS_DETAIL,
  "detail_work_repositories": $WORK_REPOS,
  "detail_work_repos_count": $WORK_REPOS_COUNT,
  "detail_personal_repositories": $PERSONAL_REPOS,
  "detail_personal_repos_count": $PERSONAL_REPOS_COUNT,
  "meta_github_username": "$GITHUB_USER",
  "meta_prs_personal": $PRS_PERSONAL,
  "meta_commits_personal": $(echo "$COMMITS - $COMMITS_WORK" | bc),
  "meta_api_calls": 0
}
EOF
)

# Get final rate limit info after all API calls
RATE_LIMITS_AFTER=$(gh api rate_limit)
SEARCH_LIMIT_AFTER=$(echo "$RATE_LIMITS_AFTER" | jq '.resources.search')
CORE_LIMIT_AFTER=$(echo "$RATE_LIMITS_AFTER" | jq '.resources.core')

SEARCH_REMAINING_AFTER=$(echo "$SEARCH_LIMIT_AFTER" | jq -r '.remaining')
SEARCH_LIMIT_MAX_AFTER=$(echo "$SEARCH_LIMIT_AFTER" | jq -r '.limit')
SEARCH_RESET_AFTER=$(echo "$SEARCH_LIMIT_AFTER" | jq -r '.reset')

CORE_REMAINING_AFTER=$(echo "$CORE_LIMIT_AFTER" | jq -r '.remaining')
CORE_LIMIT_MAX_AFTER=$(echo "$CORE_LIMIT_AFTER" | jq -r '.limit')
CORE_RESET_AFTER=$(echo "$CORE_LIMIT_AFTER" | jq -r '.reset')

# Format reset times
if date -r "$SEARCH_RESET_AFTER" +"%Y-%m-%d %H:%M:%S" &>/dev/null 2>&1; then
  # macOS
  SEARCH_RESET_TIME=$(date -r "$SEARCH_RESET_AFTER" +"%Y-%m-%d %H:%M:%S")
  CORE_RESET_TIME=$(date -r "$CORE_RESET_AFTER" +"%Y-%m-%d %H:%M:%S")
else
  # Linux
  SEARCH_RESET_TIME=$(date -d "@$SEARCH_RESET_AFTER" +"%Y-%m-%d %H:%M:%S")
  CORE_RESET_TIME=$(date -d "@$CORE_RESET_AFTER" +"%Y-%m-%d %H:%M:%S")
fi

# Update the JSON with actual values
RESULT=$(echo "$RESULT" | jq \
  --arg api_calls "$API_CALLS" \
  --arg search_remaining "$SEARCH_REMAINING_AFTER" \
  --arg search_limit "$SEARCH_LIMIT_MAX_AFTER" \
  --arg search_reset "$SEARCH_RESET_AFTER" \
  --arg search_reset_time "$SEARCH_RESET_TIME" \
  --arg core_remaining "$CORE_REMAINING_AFTER" \
  --arg core_limit "$CORE_LIMIT_MAX_AFTER" \
  --arg core_reset "$CORE_RESET_AFTER" \
  --arg core_reset_time "$CORE_RESET_TIME" \
  '.meta_api_calls = ($api_calls | tonumber) |
   .meta_rate_limit_search_remaining = ($search_remaining | tonumber) |
   .meta_rate_limit_search_limit = ($search_limit | tonumber) |
   .meta_rate_limit_search_reset = ($search_reset | tonumber) |
   .meta_rate_limit_search_reset_time = $search_reset_time |
   .meta_rate_limit_core_remaining = ($core_remaining | tonumber) |
   .meta_rate_limit_core_limit = ($core_limit | tonumber) |
   .meta_rate_limit_core_reset = ($core_reset | tonumber) |
   .meta_rate_limit_core_reset_time = $core_reset_time'
)

# Save to cache
echo "$RESULT" > "$CACHE_FILE"
date +%s > "$CACHE_META"
>&2 echo "Results cached to $CACHE_FILE"
>&2 echo "GitHub API calls: $API_CALLS"
>&2 echo "GitHub API rate limits:"
>&2 echo "  Search API: ${SEARCH_REMAINING_AFTER}/${SEARCH_LIMIT_MAX_AFTER} remaining"
>&2 echo "  Core API: ${CORE_REMAINING_AFTER}/${CORE_LIMIT_MAX_AFTER} remaining"

# Warn if rate limits are low
if [[ $SEARCH_REMAINING_AFTER -lt 5 ]]; then
  >&2 echo "WARNING: Search API rate limit is low! Resets at ${SEARCH_RESET_TIME}"
fi
if [[ $CORE_REMAINING_AFTER -lt 100 ]]; then
  >&2 echo "WARNING: Core API rate limit is low! Resets at ${CORE_RESET_TIME}"
fi

# Output result
echo "$RESULT"
