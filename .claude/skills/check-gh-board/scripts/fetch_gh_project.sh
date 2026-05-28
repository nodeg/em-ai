#!/usr/bin/env bash
# fetch_gh_project.sh — Fetch a GitHub Projects v2 board snapshot with daily-focused metrics
#
# Usage:
#   ./fetch_gh_project.sh PROJECT_NUMBER ORG_NAME [--json] [--metrics-only]
#
# Examples:
#   ./fetch_gh_project.sh 32 SUSE --metrics-only  # recommended (98% token reduction)
#   ./fetch_gh_project.sh 32 myorg --json  # full output with items array
#
# NOTE: This script is READ-ONLY. It only queries data via GraphQL, no mutations are performed.

set -euo pipefail

# ---------------------------------------------------------------------------
# Args
# ---------------------------------------------------------------------------
if [[ $# -lt 2 ]]; then
  echo "Usage: $0 PROJECT_NUMBER ORG_NAME [--json] [--metrics-only]" >&2
  echo "" >&2
  echo "Examples:" >&2
  echo "  $0 32 SUSE --metrics-only  # recommended (cost-optimized)" >&2
  echo "  $0 32 myorg --json  # full output" >&2
  exit 1
fi

PROJECT_NUMBER=$1
ORG_NAME=$2
JSON_MODE=false
METRICS_ONLY=false

# Check for flags
for arg in "$@"; do
  if [[ "$arg" == "--json" ]]; then
    JSON_MODE=true
  fi
  if [[ "$arg" == "--metrics-only" ]]; then
    METRICS_ONLY=true
    JSON_MODE=true  # metrics-only implies JSON output
  fi
done

# ---------------------------------------------------------------------------
# Check auth
# ---------------------------------------------------------------------------
if ! gh auth status >/dev/null 2>&1; then
  echo "Error: GitHub CLI not authenticated. Run: gh auth login" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# API call tracking
# ---------------------------------------------------------------------------
API_CALLS=0

# ---------------------------------------------------------------------------
# Fetch project metadata and fields (READ-ONLY GraphQL queries)
# ---------------------------------------------------------------------------
echo "Fetching project ${ORG_NAME}/${PROJECT_NUMBER} (read-only)..." >&2

# NOTE: All GraphQL operations below are queries only - no mutations are performed.
# This script has read-only access and cannot modify the board or its items.

PROJECT_META=$(gh api graphql -f query="
query {
  organization(login: \"${ORG_NAME}\") {
    projectV2(number: ${PROJECT_NUMBER}) {
      id
      title
      number
      shortDescription
      fields(first: 50) {
        nodes {
          ... on ProjectV2Field {
            id
            name
            dataType
          }
          ... on ProjectV2SingleSelectField {
            id
            name
            dataType
            options {
              id
              name
            }
          }
        }
      }
    }
  }
}")
API_CALLS=$((API_CALLS + 1))

PROJECT_ID=$(echo "$PROJECT_META" | jq -r '.data.organization.projectV2.id')
PROJECT_TITLE=$(echo "$PROJECT_META" | jq -r '.data.organization.projectV2.title')
PROJECT_DESC=$(echo "$PROJECT_META" | jq -r '.data.organization.projectV2.shortDescription // ""')
FIELDS=$(echo "$PROJECT_META" | jq '.data.organization.projectV2.fields.nodes')

# Find Status field and its options
STATUS_FIELD=$(echo "$FIELDS" | jq -r '.[] | select(.name == "Status")')
STATUS_FIELD_ID=$(echo "$STATUS_FIELD" | jq -r '.id')
STATUS_OPTIONS=$(echo "$STATUS_FIELD" | jq '.options')

# Find Priority field and its options
PRIORITY_FIELD=$(echo "$FIELDS" | jq -r '.[] | select(.name == "Priority")')
PRIORITY_FIELD_ID=$(echo "$PRIORITY_FIELD" | jq -r '.id // ""')

if [[ -z "$STATUS_FIELD_ID" ]]; then
  echo "Error: Status field not found in project" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Fetch all project items (paginated)
# ---------------------------------------------------------------------------
echo "Fetching project items..." >&2

TMPDIR=$(mktemp -d -t check-gh-board.XXXXXX)
trap "rm -rf $TMPDIR" EXIT

CURSOR=""
PAGE_NUM=0

while true; do
  AFTER_CLAUSE=""
  if [[ -n "$CURSOR" ]]; then
    AFTER_CLAUSE=", after: \"$CURSOR\""
  fi

  PAGE=$(gh api graphql -f query="
query {
  node(id: \"${PROJECT_ID}\") {
    ... on ProjectV2 {
      items(first: 100${AFTER_CLAUSE}) {
        pageInfo {
          hasNextPage
          endCursor
        }
        nodes {
          id
          fieldValues(first: 50) {
            nodes {
              ... on ProjectV2ItemFieldTextValue {
                text
                field {
                  ... on ProjectV2Field {
                    name
                  }
                }
              }
              ... on ProjectV2ItemFieldSingleSelectValue {
                name
                field {
                  ... on ProjectV2SingleSelectField {
                    name
                  }
                }
              }
              ... on ProjectV2ItemFieldDateValue {
                date
                field {
                  ... on ProjectV2Field {
                    name
                  }
                }
              }
            }
          }
          content {
            ... on Issue {
              number
              title
              state
              createdAt
              updatedAt
              closedAt
              url
              repository {
                name
                owner {
                  login
                }
              }
              assignees(first: 10) {
                nodes {
                  login
                  name
                }
              }
              labels(first: 20) {
                nodes {
                  name
                }
              }
              timelineItems(last: 100, itemTypes: [LABELED_EVENT, UNLABELED_EVENT, ASSIGNED_EVENT, UNASSIGNED_EVENT, CLOSED_EVENT, REOPENED_EVENT]) {
                nodes {
                  __typename
                  ... on LabeledEvent {
                    createdAt
                    label {
                      name
                    }
                  }
                  ... on UnlabeledEvent {
                    createdAt
                    label {
                      name
                    }
                  }
                  ... on AssignedEvent {
                    createdAt
                    assignee {
                      ... on User {
                        login
                        name
                      }
                    }
                  }
                  ... on UnassignedEvent {
                    createdAt
                    assignee {
                      ... on User {
                        login
                        name
                      }
                    }
                  }
                  ... on ClosedEvent {
                    createdAt
                  }
                  ... on ReopenedEvent {
                    createdAt
                  }
                }
              }
            }
            ... on PullRequest {
              number
              title
              state
              createdAt
              updatedAt
              closedAt
              mergedAt
              url
              repository {
                name
                owner {
                  login
                }
              }
              assignees(first: 10) {
                nodes {
                  login
                  name
                }
              }
              labels(first: 20) {
                nodes {
                  name
                }
              }
            }
          }
        }
      }
    }
  }
}")
  API_CALLS=$((API_CALLS + 1))

  echo "$PAGE" | jq '.data.node.items.nodes' > "${TMPDIR}/page-${PAGE_NUM}.json"

  HAS_NEXT=$(echo "$PAGE" | jq -r '.data.node.items.pageInfo.hasNextPage')
  CURSOR=$(echo "$PAGE" | jq -r '.data.node.items.pageInfo.endCursor')

  COUNT=$(jq 'length' "${TMPDIR}/page-${PAGE_NUM}.json")
  echo "  Fetched ${COUNT} items (page ${PAGE_NUM})..." >&2

  PAGE_NUM=$((PAGE_NUM + 1))

  if [[ "$HAS_NEXT" != "true" ]]; then
    break
  fi
done

# Merge all pages
ALL_ITEMS_FILE="${TMPDIR}/all_items.json"
jq -s 'add // []' "${TMPDIR}"/page-*.json > "$ALL_ITEMS_FILE"

NOW=$(date -u +%s)

# ---------------------------------------------------------------------------
# Process items and compute metrics
# ---------------------------------------------------------------------------
echo "Computing metrics..." >&2

METRICS=$(jq -n \
  --slurpfile items "$ALL_ITEMS_FILE" \
  --argjson status_options "$STATUS_OPTIONS" \
  --argjson now "$NOW" \
  '
def parse_iso8601:
  if . == null then null
  else (. | fromdateiso8601) end;

def format_duration:
  (if . < 0 then 0 else . end) as $s |
  ($s / 86400 | floor) as $d |
  (($s % 86400) / 3600 | floor) as $h |
  (($s % 3600) / 60 | floor) as $m |
  if $d > 0 then "\($d)d \($h)h"
  elif $h > 0 then "\($h)h \($m)m"
  else "\($m)m"
  end;

def get_field_value($field_name):
  .fieldValues.nodes[]? | select(.field.name == $field_name) | (.name // .text // .date // "");

def get_status: get_field_value("Status");
def get_priority: get_field_value("Priority");

def is_bug:
  (.content.labels.nodes // []) | map(.name | ascii_downcase) | any(test("bug"));

def is_epic:
  (.content.labels.nodes // []) | map(.name | ascii_downcase) | any(test("epic"));

def time_in_current_status:
  .content.updatedAt as $updated |
  ($now - ($updated | parse_iso8601)) as $secs |
  {
    formatted: ($secs | format_duration),
    seconds: ($secs | floor)
  };

# Status categories mapping
def status_category($status):
  if ($status == "Done") then "Done"
  elif ($status == "Doing" or $status == "In Progress") then "In Progress"
  elif ($status == "Blocked") then "Blocked"
  else "To Do"
  end;

# Process all items
($items[0] // []) as $all_items |

# Filter out Done items older than 36h
($now - 129600) as $done_cutoff |
[$all_items[] |
  . as $item |
  ($item | get_status) as $status |
  ($status | status_category($status)) as $category |
  select(
    $category != "Done" or
    ($item.content.closedAt != null and (($item.content.closedAt | parse_iso8601) >= $done_cutoff))
  )
] as $items |

# Basic counts
($items | length) as $total |
($items | map(select((get_status | status_category(.)) == "In Progress")) | length) as $in_progress |
($items | map(select((get_status | status_category(.)) == "To Do")) | length) as $todo |
($items | map(select((get_status | status_category(.)) == "Done")) | length) as $done_last_36h |
($items | map(select(get_status == "Blocked")) | length) as $blocked_count |

# Blocked items
[$items[] | select(get_status == "Blocked") |
  {
    key: (.content.url | split("/") | .[-1]),
    url: .content.url,
    number: .content.number,
    title: .content.title,
    status: get_status,
    assignees: [.content.assignees.nodes[]? | .name // .login],
    time_in_status: (. | time_in_current_status).formatted,
    is_bug: (. | is_bug),
    priority: get_priority
  }
] as $blocked |

# Stuck items (in In Progress category for ≥5 days)
[$items[] |
  select((get_status | status_category(.)) == "In Progress") |
  (. | time_in_current_status) as $time |
  select($time.seconds >= 432000) |
  {
    key: (.content.url | split("/") | .[-1]),
    url: .content.url,
    number: .content.number,
    title: .content.title,
    status: get_status,
    assignees: [.content.assignees.nodes[]? | .name // .login],
    time_in_status: $time.formatted,
    seconds: $time.seconds,
    severity: (if $time.seconds >= 864000 then "critical" else "warning" end),
    is_bug: (. | is_bug),
    is_blocked: (get_status == "Blocked"),
    priority: get_priority
  }
] | sort_by(-.seconds) as $stuck |

# Unassigned in In Progress
[$items[] |
  select((get_status | status_category(.)) == "In Progress") |
  select((.content.assignees.nodes // []) | length == 0) |
  {
    key: (.content.url | split("/") | .[-1]),
    url: .content.url,
    number: .content.number,
    title: .content.title,
    status: get_status,
    time_in_status: (. | time_in_current_status).formatted
  }
] as $unassigned_in_progress |

# WIP per assignee
([$items[] | select((get_status | status_category(.)) == "In Progress")] |
  map({
    assignee: (.content.assignees.nodes[0]? | .name // .login // "(unassigned)"),
    item: .
  }) |
  group_by(.assignee) |
  map({
    assignee: (if .[0].assignee == "(unassigned)" then null else .[0].assignee end),
    count: length,
    keys: [.[].item.content.number],
    stuck_count: ([.[] | select(.item | time_in_current_status | .seconds >= 432000)] | length),
    blocked_count: ([.[] | select(.item | get_status == "Blocked")] | length)
  }) |
  sort_by(-.count)
) as $assignees |

# Idle assignees (have items but 0 in In Progress)
([$items[] | .content.assignees.nodes[]? | .name // .login] | unique) as $all_assignees |
([$assignees[] | select(.assignee != null) | .assignee]) as $busy_assignees |
($all_assignees - $busy_assignees) as $idle_assignees |

# Status distribution
([$status_options[] | . as $opt | {
  name: $opt.name,
  count: ([$items[] | select(get_status == $opt.name)] | length)
}]) as $status_dist |

# Bugs at risk (high priority bugs not Done)
([$items[] |
  select((. | is_bug) and (get_status | status_category(.)) != "Done") |
  get_priority as $prio |
  select($prio == "High" or $prio == "Medium") |
  {
    key: (.content.url | split("/") | .[-1]),
    url: .content.url,
    number: .content.number,
    title: .content.title,
    status: get_status,
    assignees: [.content.assignees.nodes[]? | .name // .login],
    priority: $prio,
    risk: (if $prio == "High" then "red" else "yellow" end),
    time_in_status: (. | time_in_current_status).formatted
  }
] | sort_by(if .risk == "red" then 0 else 1 end)) as $bugs_at_risk |

# All bugs count
([$items[] | select(. | is_bug)] | length) as $bugs_total |
([$items[] | select((. | is_bug) and (get_status | status_category(.)) != "Done") | select((get_priority | . != "High" and . != "Medium"))] | length) as $bugs_other |

# Epics
([$items[] |
  select(. | is_epic) |
  .content.number as $epic_num |
  {
    key: (.content.url | split("/") | .[-1]),
    url: .content.url,
    number: $epic_num,
    title: .content.title,
    status: get_status,
    assignees: [.content.assignees.nodes[]? | .name // .login]
  }
]) as $epics |

{
  total: $total,
  in_progress: $in_progress,
  todo: $todo,
  done_last_36h: $done_last_36h,
  blocked_count: $blocked_count,
  blocked: $blocked,
  stuck: $stuck,
  unassigned_in_progress: $unassigned_in_progress,
  assignees: $assignees,
  idle_assignees: $idle_assignees,
  status_distribution: $status_dist,
  bugs_at_risk: $bugs_at_risk,
  bugs_total: $bugs_total,
  bugs_other_count: $bugs_other,
  epics: $epics
}
')

# ---------------------------------------------------------------------------
# Get rate limit info
# ---------------------------------------------------------------------------
RATE_LIMIT_RESPONSE=$(gh api rate_limit 2>/dev/null || echo '{}')
API_CALLS=$((API_CALLS + 1))

GRAPHQL_REMAINING=$(echo "$RATE_LIMIT_RESPONSE" | jq -r '.resources.graphql.remaining // "unknown"')
GRAPHQL_LIMIT=$(echo "$RATE_LIMIT_RESPONSE" | jq -r '.resources.graphql.limit // "unknown"')
GRAPHQL_RESET=$(echo "$RATE_LIMIT_RESPONSE" | jq -r '.resources.graphql.reset // 0')

if [[ "$GRAPHQL_RESET" != "0" ]] && [[ "$GRAPHQL_RESET" != "unknown" ]]; then
  GRAPHQL_RESET_TIME=$(date -r "$GRAPHQL_RESET" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "unknown")
else
  GRAPHQL_RESET_TIME="unknown"
fi

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------
if [[ "$JSON_MODE" == true ]]; then
  if [[ "$METRICS_ONLY" == true ]]; then
    # Metrics-only mode: exclude items array to save ~98% tokens
    jq -n \
      --arg fetched_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      --arg project_id "$PROJECT_ID" \
      --argjson project_number "$PROJECT_NUMBER" \
      --arg project_title "$PROJECT_TITLE" \
      --arg project_desc "$PROJECT_DESC" \
      --arg org "$ORG_NAME" \
      --argjson metrics "$METRICS" \
      --argjson api_calls "$API_CALLS" \
      --arg graphql_remaining "$GRAPHQL_REMAINING" \
      --arg graphql_limit "$GRAPHQL_LIMIT" \
      --arg graphql_reset_time "$GRAPHQL_RESET_TIME" \
      '{
        fetched_at: $fetched_at,
        project: {
          id: $project_id,
          number: $project_number,
          title: $project_title,
          description: $project_desc,
          org: $org
        },
        metrics: $metrics,
        meta: {
          api_calls: $api_calls,
          rate_limit: {
            graphql_remaining: $graphql_remaining,
            graphql_limit: $graphql_limit,
            graphql_reset_time: $graphql_reset_time
          }
        }
      }'
  else
    # Full mode: include items array
    jq -n \
      --arg fetched_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      --arg project_id "$PROJECT_ID" \
      --argjson project_number "$PROJECT_NUMBER" \
      --arg project_title "$PROJECT_TITLE" \
      --arg project_desc "$PROJECT_DESC" \
      --arg org "$ORG_NAME" \
      --argjson metrics "$METRICS" \
      --slurpfile items "$ALL_ITEMS_FILE" \
      --argjson api_calls "$API_CALLS" \
      --arg graphql_remaining "$GRAPHQL_REMAINING" \
      --arg graphql_limit "$GRAPHQL_LIMIT" \
      --arg graphql_reset_time "$GRAPHQL_RESET_TIME" \
      '{
        fetched_at: $fetched_at,
        project: {
          id: $project_id,
          number: $project_number,
          title: $project_title,
          description: $project_desc,
          org: $org
        },
        metrics: $metrics,
        items: $items[0],
        meta: {
          api_calls: $api_calls,
          rate_limit: {
            graphql_remaining: $graphql_remaining,
            graphql_limit: $graphql_limit,
            graphql_reset_time: $graphql_reset_time
          }
        }
      }'
  fi
else
  # Human-readable output
  echo ""
  echo "========================================================================"
  echo "GitHub Project ${ORG_NAME}/${PROJECT_NUMBER} — ${PROJECT_TITLE}"
  echo "========================================================================"
  echo ""
  echo "$METRICS" | jq -r '
    "  Total (snapshot): \(.total)",
    "  In Progress: \(.in_progress)  ·  To Do: \(.todo)  ·  Done (last 36h): \(.done_last_36h)",
    "  Blocked: \(.blocked_count)",
    "",
    "  Status distribution:",
    (.status_distribution[] | "    \(.name): \(.count)"),
    "",
    "  Stuck (≥5d in In Progress): \(.stuck | length)",
    (.stuck[:5][] | "    [\(.severity | ascii_upcase)] #\(.number) — \(.time_in_status) · \(.assignees[0] // "Unassigned")\(if .is_blocked then " · BLOCKED" else "" end)\n      \(.title[:80])"),
    (if (.stuck | length) > 5 then "    ... and \((.stuck | length) - 5) more" else "" end),
    "",
    "  Blocked items: \(.blocked_count)",
    (.blocked[:5][] | "    #\(.number) — \(.status) · \(.assignees[0] // "Unassigned") · \(.time_in_status)\n      \(.title[:80])"),
    "",
    "  Unassigned in In Progress: \(.unassigned_in_progress | length)",
    (.unassigned_in_progress[] | "    #\(.number) — \(.time_in_status)\n      \(.title[:80])"),
    "",
    "  WIP per assignee:",
    (.assignees[] | "    \(.assignee // "(unassigned)"): \(.count) WIP · \(.stuck_count) stuck · \(.blocked_count) blocked"),
    "",
    "  Bugs at risk: \(.bugs_at_risk | length)",
    (.bugs_at_risk[:5][] | "    [\(.risk | ascii_upcase)] #\(.number) — \(.priority) · \(.assignees[0] // "Unassigned")\n      \(.title[:80])"),
    (if (.bugs_other_count) > 0 then "    Other bugs (low priority): \(.bugs_other_count)" else "" end),
    "",
    "  Epics: \(.epics | length)",
    (.epics[:5][] | "    #\(.number) — \(.title[:60])")
  '

  IDLE_COUNT=$(echo "$METRICS" | jq '.idle_assignees | length')
  if [[ "$IDLE_COUNT" -gt 0 ]]; then
    echo ""
    echo "  Can pull (idle):"
    echo "$METRICS" | jq -r '.idle_assignees[] | "    \(.)"'
  fi

  echo ""
  echo "========================================================================"
fi
