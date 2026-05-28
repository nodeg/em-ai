# Check GitHub Board Skill

Analyze GitHub Projects (v2) boards for daily standup readiness: flow health, people load, stuck issues, blocked items, and bugs at risk, workload in general.

## Overview

This skill provides a daily snapshot of a GitHub Project board, optimized for Engineering Manager standups:
- **Flow Health**: Stuck items, blocked items, unassigned work
- **People Health**: WIP balance, overloaded team members, who can pull work
- **Bugs at Risk**: High/medium priority bugs not in Done
- **Epic Health**: Active epics and their status

**Read-Only Access**: This skill only queries board data via GraphQL. It cannot modify the board, items, or any project settings.

## Two Versions: Standard vs Compact

### Standard Skill (Full Visibility)

**Best for**: Debugging, understanding board state, one-off analysis  
**Cost**: ~$1.37 per report (~451K tokens)  
**Includes**: Full board snapshot with all 500+ items

### Compact Skill (Production Use)

**Best for**: Daily standups, regular team analysis, cost-conscious usage  
**Cost**: ~$0.025 per report (~6.3K tokens) — **98.2% cheaper**  
**Includes**: Pre-computed metrics only (stuck, blocked, WIP, bugs, epics)

---

## Quick Start

### Via Skill (Recommended)

```bash
Check the team board
```

or

```bash
/check-gh-board team_name
```

Claude will:
1. Look up `team_name` → find project info in `data/team_{name}.md`
2. Run the fetch script
3. Generate formatted daily health report

### Direct Script Usage

```bash
# Compact mode (metrics only, 98% token reduction) - RECOMMENDED
bash .claude/skills/check-gh-board/scripts/fetch_gh_project.sh 32 myorg --metrics-only

# Standard mode (full items array) - expensive, only for debugging
bash .claude/skills/check-gh-board/scripts/fetch_gh_project.sh 32 myorg --json

# Human-readable output
bash .claude/skills/check-gh-board/scripts/fetch_gh_project.sh 32 myorg
```

**Note**: All operations are read-only. The script cannot modify the board or its items.

---

## Detailed Examples

### Example 1: Standard Skill - Full Board Analysis

**User Request**:
```bash
Check the team board
```

**What Happens**:
1. Claude loads full SKILL.md (~2,013 tokens)
2. Claude looks up team → finds project number in team file (~800 tokens)
3. Script runs with full items array
4. Returns 1.7MB JSON data (~446,616 tokens)
5. Claude formats report (~650 tokens output)

**Example output**:
```bash
📋 Board Snapshot — Org/32: Team Name
GitHub API Calls: 8
Rate Limit:
  GraphQL API: 4545/5000 remaining (resets at 2026-05-28 17:43:46)
Token Usage: ~5233 input + ~650 output = ~5883 total (~$0.026)

- Total (snapshot): 289 · In Progress: 13 · To Do: 259 · Done last 36h: 6
- Blocked: 11
- Status distribution: Doing (13), Blocked (11), Inbox (239), Backlog (20), Done (6)

🌊 Flow Health — 🔴 Stalled

- Stuck: 🔴 — 0 warnings, 3 critical
  - #12345 — Project planning (57d in Doing, User A)
  - #12346 — Maintenance task (15d in Doing, User B)
  - #12347 — Testing week (15d in Doing, User B)
- Blocked: 🔴 — 11 items
  - #12348 — Environment upgrade (Blocked, User A, 2d)
  - #12349 — Bug fix (Blocked, User B, 1d)
  - #12350 — Automation work (Blocked, User C, 106d)
  and 8 more
- Unassigned in In Progress: None

👥 People Health — 🟡 At Risk

- Overloaded: None
- Heavy stuck: User B (2 stuck), User A (1 stuck)
- Can pull (idle): User D, User E, User F, User G

🛤️ Epic Health

- #12351 — Release 5.0.8 (Doing, User C, User B)
- #12352 — Release 5.2 RC (Doing, User C, User B)
- #12353 — Release 5.1.4 (Blocked, User C)
and 26 more

🐞 Bugs at Risk — 🟢

- Bugs without high priority on the board: 0

🧭 Summary

- 3 critical stuck items (≥10d): #12345 (57d), #12346, #12347 need immediate attention
- 11 blocked items — #12350 (106d blocked) and #12354 (189d blocked) are severely stalled
- User B has 2 stuck items, needs support or reprioritization
- 4 team members idle and can pull work

🎯 Recommendations

1. Unblock #12345 — 57d in Doing (User A) or move to backlog
2. Investigate #12350 (106d blocked) and #12354 (189d blocked) — resolve or close
3. Reprioritize User B's stuck items (#12346, #12347) or get help
4. Assign work from Inbox to idle members: User D, User E, User F, User G
5. Review 11 blocked items — unblock top 3 or move to backlog
```

**Token Usage**: ~450,375 input + ~650 output = ~451,025 total (~$1.37)

---

### Example 2: Compact Skill - Daily Standup

**Scenario**: Daily morning standup for X-person team

**Step 1**: Run the script with compact mode
```bash
bash .claude/skills/check-gh-board/scripts/fetch_gh_project.sh 32 myorg --metrics-only > /tmp/board_snapshot.json 2>/dev/null
```

**Step 2**: Ask Claude to format using compact skill
```bash
Format this board snapshot using the compact template:

[paste /tmp/board_snapshot.json]
```

**What Happens**:
1. Claude loads SKILL_COMPACT.md (~586 tokens)
2. Team file lookup (~800 tokens)
3. JSON metrics only (~3,520 tokens)
4. Claude formats report (~650 tokens output)

**Output**: Same format as above, but only the metrics are used (no full items array loaded)

**Token Usage**: ~4,906 input + ~650 output = ~5,556 total (~$0.025)

**Cost Savings**: $1.37 - $0.025 = **$1.35 per report (98.2% reduction)**

---

### Example 3: Weekly Team Analysis

**Scenario**: Check board every Monday morning

**Standard Version**:
- 4 checks/month × $1.37 = **$5.48/month** = **$65.76/year**

**Compact Version**:
- 4 checks/month × $0.025 = **$0.10/month** = **$1.20/year**

**Annual Savings**: **$64.56 per year per board**

---

## Team File Configuration

Add to `data/team_{name}.md`:

```markdown
# Team Context

## Overview
- Team name: Your Team Name
- Default board: github:ORG_NAME/PROJECT_NUMBER

## Team Members

### User A
- Full name: Alice Example
- Email: alice@example.com
- Github username: alice
- Role: Software Quality Engineer

### User B
- Full name: Bob Example
- Email: bob@example.com
- Github username: bobdev
- Role: Senior Software Engineer
```

**Format for Default board**: `github:ORG_NAME/PROJECT_NUMBER`

The skill will automatically parse both the ORG_NAME and PROJECT_NUMBER from this field. No hardcoded defaults.

---

## API Usage and Cost Tracking

Each report includes:

### GitHub API Calls
The script tracks all GraphQL API calls made:
- **1 call**: Fetch project metadata and field definitions
- **N calls**: Paginated fetch of items (100 items per page)
  - Example: 590 items = 6 pages = 6 calls
- **1 call**: Fetch rate limit info

**Total**: Typically 7-10 calls per board check

### Rate Limits
**GraphQL API**: 5,000 requests per hour
- Resets every hour at the time shown
- Monitor the `remaining` count to avoid hitting limits
- With 8 calls per check, you can check **625 boards per hour**

### Token Usage and Cost
Reports show Claude API token usage:
- **Input tokens**: SKILL file + team context + JSON data
  - Compact mode (optimized): ~5,233 tokens
  - Compact mode (old): ~5,892 tokens
  - Standard mode: ~6,528 tokens
- **Output tokens**: ~650 tokens (formatted report)
- **Cost**: ~$0.026 per report (compact mode with team extraction)

**Team Context Optimization**:
The skill uses `extract_team_context.sh` to parse only essential fields from team files:
- Full team file: ~830 tokens
- Extracted context: ~65 tokens (92% reduction)
- Extracts: org, project number, team roster only

**Pricing** (Claude Sonnet 4.5):
- Input: $3.00 per million tokens
- Output: $15.00 per million tokens

---

## Understanding the Metrics

### Flow Health Scoring

**Stuck Items**:
- Warning: ≥5 days in In Progress
- Critical: ≥10 days in In Progress
- 🟢 None | 🟡 1-2 warnings, no critical | 🔴 Any critical or ≥3 warnings

**Blocked Items**:
- Items with status "Blocked"
- 🟢 0 | 🟡 1-2 | 🔴 ≥3 or any blocked+stuck ≥10d

**Overall**: 🟢 Moving (all green) | 🟡 At Risk (any yellow) | 🔴 Stalled (any red)

### People Health Scoring

**Overloaded**:
- ≥4 items in In Progress, OR
- ≥3 items AND ≥2 stuck

**Heavy Stuck**:
- ≥2 stuck items (regardless of total count)

**Overall**: 🟢 Healthy | 🟡 At Risk (1 overloaded) | 🔴 Stretched (multiple overloaded or unassigned work)

### Bugs at Risk

- 🔴 Red: High priority, not Done
- 🟡 Yellow: Medium priority, not Done
- 🟢 None

---

## Script Details

### Data Fetched

The script uses GitHub GraphQL API to fetch:
- Project metadata (title, description, fields)
- All project items (issues, PRs) with:
  - Title, number, state, dates
  - Assignees, labels
  - Custom fields (Status, Priority, etc.)

### Computed Metrics

- Total items (excluding Done >36h old)
- WIP per assignee
- Stuck items (≥5d in In Progress)
- Blocked items (status = "Blocked")
- Unassigned items in In Progress
- Bugs at risk (high/medium priority not Done)
- Idle assignees (can pull work)

### Authentication

Requires GitHub CLI (`gh`) authenticated with `project` scope:

```bash
gh auth refresh -h github.com -s project
```

---

## Cost Comparison

### Single Report

| Version | Input Tokens | Output Tokens | Total | Cost |
|---------|--------------|---------------|-------|------|
| Standard (full items) | 449,624 | 650 | 450,274 | $1.36 |
| Standard (metrics-only) | 6,528 | 650 | 7,178 | $0.030 |
| Compact (metrics-only, old) | 5,892 | 650 | 6,542 | $0.028 |
| **Compact + Team Extract** | **5,233** | **650** | **5,883** | **$0.026** |
| **Savings (vs Full)** | **-98.8%** | **0%** | **-98.7%** | **-98.1%** |

### Daily Standup Usage

| Frequency | Standard (Full) | Standard (Metrics) | Compact (Old) | **Compact + Extract** | **Savings** |
|-----------|-----------------|--------------------|--------------------|---------------------------|---------------------------|
| Daily (260/year) | $353.60 | $7.80 | $7.28 | **$6.76** | **$346.84** |
| Weekly (52/year) | $70.72 | $1.56 | $1.46 | **$1.35** | **$69.37** |
| Bi-weekly (26/year) | $35.36 | $0.78 | $0.73 | **$0.68** | **$34.68** |

---

## When to Use Which Version

### Use Standard Skill When:
- ✅ Debugging unexpected board behavior
- ✅ Need to see full item details (descriptions, all labels)
- ✅ Investigating specific issues in depth
- ✅ One-off deep analysis
- ✅ Cost is not a concern

### Use Compact Skill When:
- ✅ Daily/weekly standup readiness checks
- ✅ Regular board health monitoring
- ✅ Cost-conscious usage
- ✅ You're familiar with the report format
- ✅ Production/automated workflows

---

## Troubleshooting

### Error: "your authentication token is missing required scopes [read:project]"

**Solution**: Refresh GitHub auth with project scope
```bash
gh auth refresh -h github.com -s project
```

### Error: "could not parse board id"

**Solution**: Verify project number
```bash
# List projects for an org
gh project list --owner YOUR_ORG

# Use the number column
```

### Team file not found

**Solution**: Create `data/team_{name}.md` with:
```markdown
## Overview
- Default board: github:ORG/PROJECT_NUMBER
```

### Idle filter unavailable

This appears when you call the skill with just a project number (no team file).

**Solution**: Create a team file or accept that idle filtering won't work.

---

## Differences from Jira check-board

| Feature | Jira check-board | GitHub check-gh-board |
|---------|------------------|----------------------|
| Board type | Kanban only | Projects v2 |
| Flagged field | ✅ Detected automatically | ❌ Uses "Blocked" status |
| Regressions | ✅ Tracks status changes 7d | ❌ Not tracked (timeline limited) |
| Epics | ✅ Full hierarchy | ℹ️ Label-based detection |
| Cycle time | ✅ Full timeline | ❌ Limited (API constraints) |
| Custom fields | ✅ Via field discovery | ✅ Via GraphQL schema |
| Cost optimization | ❌ No compact mode | ✅ 98% savings with --metrics-only |

---

## Advanced Usage

### Custom Status Detection

The script detects these status categories:
- **Done**: status = "Done"
- **In Progress**: status = "Doing" or "In Progress"
- **Blocked**: status = "Blocked"
- **To Do**: everything else

### Filter Done Items

Done items are automatically filtered to last 36 hours to keep snapshot focused on active work.

### JSON Output Schema

Full mode includes `items` array (~1.7MB):
```json
{
  "fetched_at": "2026-05-28T12:00:00Z",
  "project": { ... },
  "metrics": { ... },
  "items": [590 items with full details]
}
```

Compact mode (--metrics-only) excludes items (~14KB):
```json
{
  "fetched_at": "2026-05-28T12:00:00Z",
  "project": { ... },
  "metrics": {
    "stuck": [...],
    "blocked": [...],
    "assignees": [...],
    "bugs_at_risk": [...],
    "epics": [...]
  }
}
```

---

## Files

```
.claude/skills/check-gh-board/
├── README.md                           # This file
├── SKILL.md                            # Standard skill (full visibility)
├── SKILL_COMPACT.md                   # Compact skill (production use)
├── COST_OPTIMIZATION.md               # Detailed cost analysis
└── scripts/
    └── fetch_gh_project.sh            # Data fetching script
```

---

## Support

For issues:
1. Check authentication: `gh auth status`
2. Verify project exists: `gh project list --owner YOUR_ORG`
3. Check team file format in `data/team_*.md`
4. Review SKILL.md or SKILL_COMPACT.md for expected JSON structure
5. Check COST_OPTIMIZATION.md for token usage details

---

## Pricing Reference (Claude Sonnet 4.5)

- **Input**: $3.00 per million tokens
- **Output**: $15.00 per million tokens

**Standard Skill**: ~451K tokens = $1.37  
**Compact Skill**: ~5.6K tokens = $0.025
