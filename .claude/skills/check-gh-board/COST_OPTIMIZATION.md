# Cost Optimization for check-gh-board Skill

## Token Usage Analysis

### Current Standard Skill

**Input tokens per report**:
- SKILL.md: ~8,832 bytes ≈ 2,208 tokens
- README.md: Not loaded (not needed for skill execution)
- Team file (partial): ~800 tokens
- JSON output (with items): ~1,786,463 bytes ≈ 446,616 tokens
- JSON output (without items, with meta): ~14,079 bytes ≈ 3,520 tokens

**Total with full items array**: ~449,624 tokens input
**Total with metrics only**: ~6,528 tokens input

**Output tokens**: ~650 tokens (formatted report)

**Cost per report**:
- With full items: $1.35 (input) + $0.01 (output) = **$1.36**
- With metrics only: $0.020 (input) + $0.010 (output) = **$0.030**

## Problem: The items Array

The script returns a full `items` array with all 590+ board items (issues/PRs), each containing:
- Full title, description, labels, assignees
- Custom field values
- URLs, dates, status

This causes the JSON to balloon to 1.7MB (~447K tokens), making each report cost $1.37.

## Solution: Use Pre-Computed Metrics

The skill instructions already say:
> "Use the pre-computed `metrics` for all rubric checks. Do not recompute from `items` unless you need a specific item's detail."

**The skill should NEVER need the full items array** because:
- All stuck items are in `metrics.stuck`
- All blocked items are in `metrics.blocked`
- All bugs at risk are in `metrics.bugs_at_risk`
- All epics are in `metrics.epics`
- WIP distribution is in `metrics.assignees`

## Optimization Strategy

### Option 1: Compact Skill (✅ IMPLEMENTED)
Create a minimal SKILL_COMPACT.md that:
- Removes all documentation and examples
- Keeps only the report template and scoring thresholds
- Uses --metrics-only flag

**Token reduction**: ~636 tokens (SKILL.md → SKILL_COMPACT.md)
**Cost**: ~$0.028 per report

### Option 2: Script Modification (✅ IMPLEMENTED)
Add a `--metrics-only` flag to the script that:
- Returns only `metrics`, `project`, and `meta` objects
- Excludes the entire `items` array

**Token reduction**: ~443,096 tokens (items array not sent)
**Cost**: ~$0.030 per report (~$1.33 savings, 98% reduction)

### Option 3: Combined (✅ IMPLEMENTED - Maximum Savings)
Both compact skill + metrics-only script output

**Token reduction**: ~443,732 tokens total
**Cost**: ~$0.028 per report (~$1.33 savings, 97.9% reduction)

## Recommended Approach (IMPLEMENTED)

**Option 3+** (Combined with Team Extraction) for maximum cost savings:

1. ✅ Create SKILL_COMPACT.md (minimal documentation)
2. ✅ Add `--metrics-only` flag to script
3. ✅ Make `--metrics-only` the default in skill instructions
4. ✅ Remove hardcoded org default - require explicit ORG_NAME parameter
5. ✅ Document read-only access (no mutations possible)
6. ✅ Extract minimal team context (org, project, roster only)

This brings cost from **$1.36 → $0.026** per report.

**Team Context Extraction**:
- Use `extract_team_context.sh` to parse only essential fields from team file
- Reduces team file tokens: **830 → 65 tokens** (92% reduction, -765 tokens)
- Extracts: org name, project number, team roster (for idle filtering)
- Format: `{org: "SUSE", project_number: "32", team_roster: ["Name 1", ...]}`

**IMPORTANT**: Always use `--metrics-only` flag and `extract_team_context.sh` for team files.

## Cost Comparison

### Single Report

| Version | Input Tokens | Output Tokens | Total | Cost |
|---------|--------------|---------------|-------|------|
| Standard (full items) | 449,624 | 650 | 450,274 | $1.36 |
| Standard (metrics-only) | 6,528 | 650 | 7,178 | $0.030 |
| Compact + Metrics (old) | 5,892 | 650 | 6,542 | $0.028 |
| **Compact + Metrics + Extract** | **5,233** | **650** | **5,883** | **$0.026** |
| **Savings vs Full** | **-98.8%** | **0%** | **-98.7%** | **-98.1%** |

### Weekly Team Standup (1 board check)

| Version | Per Report | Weekly | Monthly (4×) | Yearly (52×) |
|---------|------------|--------|--------------|--------------|
| Standard (full items) | $1.36 | $1.36 | $5.44 | $70.72 |
| Standard (metrics-only) | $0.030 | $0.030 | $0.120 | $1.56 |
| Compact + Metrics (old) | $0.028 | $0.028 | $0.112 | $1.46 |
| **Compact + Extract** | **$0.026** | **$0.026** | **$0.104** | **$1.35** |
| **Savings vs Full** | **-98.1%** | **-98.1%** | **-98.1%** | **-98.1%** |

**Annual Savings**: $69.37 per year per board (compact+extract vs full)

## Implementation

### Step 1: Add --metrics-only flag to script

```bash
# In fetch_gh_project.sh, add after argument parsing:
METRICS_ONLY=false
if [[ "$*" == *"--metrics-only"* ]]; then
  METRICS_ONLY=true
fi

# At the end, before final jq output:
if [[ "$METRICS_ONLY" == "true" ]]; then
  jq 'del(.items)' <<< "$FINAL_OUTPUT"
else
  echo "$FINAL_OUTPUT"
fi
```

### Step 2: Create SKILL_COMPACT.md

Strip down to ~2KB:
- Remove all examples and documentation
- Keep only input resolution, scoring rubrics, output format
- Add instruction to use `--metrics-only` flag

### Step 3: Update README.md

Document both versions:
- Standard: Learning, debugging, full visibility
- Compact: Production use, cost-conscious, daily standups

## Token Breakdown (Compact + Metrics-Only + Team Extraction)

| Component | Tokens | Cost |
|-----------|--------|------|
| SKILL_COMPACT.md | ~1,648 | $0.005 |
| Team context (extracted) | ~65 | $0.0002 |
| JSON (metrics + meta) | ~3,520 | $0.011 |
| **Input Total** | **~5,233** | **$0.016** |
| Output (report) | ~650 | $0.010 |
| **Grand Total** | **~5,883** | **$0.026** |

**Optimization**: Using `extract_team_context.sh` reduces team file tokens from 800 → 65 (92% reduction, -735 tokens)

## Final Cost Comparison

| Version | Cost | vs Standard (Full) |
|---------|------|--------------------|
| Standard (full items) | $1.36 | — |
| Standard (metrics-only) | $0.030 | 97.8% savings |
| Compact + Metrics (old) | $0.028 | 97.9% savings |
| **Compact + Extract** | **$0.026** | **98.1% savings** |

**Annual savings** (weekly board check): $70.72 - $1.35 = **$69.37 per year per board**

**Additional savings from team extraction**: $0.028 - $0.026 = **$0.002 per report** (7% improvement)

## Read-Only Access

The skill is designed to be **read-only**:
- Uses only GraphQL **queries** (no mutations)
- Cannot modify board items, status, assignees, or any field
- Cannot create, update, or delete items
- Cannot modify project settings or structure

This ensures safe, non-invasive board monitoring for daily standups.

## GitHub API Usage

The script makes the following GraphQL API calls:
- **1 call**: Fetch project metadata and field definitions
- **N calls**: Paginated fetch of all items (100 items per page)
  - For a board with 590 items: 6 pages = 6 calls
- **1 call**: Fetch rate limit info

**Total for typical board**: ~8 API calls

**GraphQL API Limit**: 5,000 requests per hour
- Resets every hour
- Tracked in output: `meta.rate_limit.graphql_remaining`

## Conclusion

The initial implementation was **extremely expensive** due to the full items array (1.7MB JSON).

By creating a compact skill and making `--metrics-only` the default, we reduced costs from **$1.36 to $0.028 per report** — a **97.9% reduction**.

For a single board checked weekly, this saves **$69.26 per year**.

**Current implementation**:
- ✅ `--metrics-only` required by default
- ✅ No hardcoded org (must specify ORG_NAME)
- ✅ Read-only GraphQL queries only
- ✅ API call tracking and rate limit monitoring
- ✅ Token usage and cost reporting
- ✅ Cost-optimized for daily use (~$0.028 per report)
