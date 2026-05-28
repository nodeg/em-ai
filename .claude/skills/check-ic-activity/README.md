# Check IC Activity Skill

Analyze GitHub activity for Software Quality Engineers (QE/SQE/QA) with automated metrics, scoring, and caching to prevent API rate limiting.

## Overview

This skill provides comprehensive activity reports for individual contributors, optimized for QE work patterns:
- **Delivery**: Issues closed, PRs merged, cycle times, LOC
- **Focus**: Work-in-progress tracking (open issues + PRs)
- **Quality**: PR size, review comments, cancelled PRs
- **Collaboration**: Code reviews given, time to first review

## Features

✅ **Intelligent Caching** - 24h TTL to prevent GitHub API rate limiting  
✅ **Rate Limit Tracking** - Monitor both Search API (30/min) and Core API (5000/hour)  
✅ **Personal vs Work Repos** - Separate tracking, only work repos count toward scores  
✅ **Stale Issue Filtering** - Auto-exclude issues >2yr old, PRs >1yr old  
✅ **Cost Optimization** - Compact mode saves 40% on Claude API costs  
✅ **API Call Counting** - Track GitHub API usage per report

---

## Two Versions: Standard vs Compact

### Standard Skill (Full Documentation)

**Best for**: Learning, onboarding, understanding scoring logic  
**Cost**: ~$0.028 per report (~6,600 tokens)  
**Includes**: Extensive documentation, examples, QE work pattern guidance

### Compact Skill (Production Use)

**Best for**: Regular team analysis, cost-conscious usage  
**Cost**: ~$0.017 per report (~2,900 tokens) — **40% cheaper**  
**Includes**: Just the report template and scoring thresholds

---

## Quick Start

### Standard Skill Usage

**Step 1**: Invoke the skill through Claude
```
Analyze my last 30 days
```

or more explicitly:
```
/check-ic-activity --days 30 nodeg
```

**Step 2**: Claude will:
1. Look up `nodeg` in `data/team_*.md`
2. Run the activity script (or use cache)
3. Generate a formatted report with scoring

**Cost**: ~$0.028 per report

---

### Compact Skill Usage (Recommended for Regular Use)

**Step 1**: Run the analyzer script directly
```bash
bash .claude/skills/check-ic-activity/scripts/analyze_report.sh nodeg 2026-04-28 2026-05-28 data/team_mlm_qe.md
```

**Step 2**: Copy the JSON output and ask Claude:
```
Format this activity report using the compact template
```

or paste the JSON and say:
```
Generate a QE activity report from this data following SKILL_COMPACT.md format
```

**Cost**: ~$0.017 per report (40% savings)

---

## Detailed Examples

### Example 1: Standard Skill - Single Person Analysis

**User Request**:
```
Analyze my last 30 days
```

**What Happens**:
1. Claude loads full SKILL.md (~3,500 tokens)
2. Claude looks up current user → finds `nodeg` in team file (~800 tokens)
3. Script runs: `run_ic_activity.sh nodeg 2026-04-28 2026-05-28`
4. Returns JSON data (~1,625 tokens)
5. Claude formats report (~650 tokens output)

**Output**:
```
QE Activity Report: User Name (nodeg)
Period: 2026-04-28 to 2026-05-28
GitHub API Calls: 61
Rate Limits:
  Search API: 29/30 remaining (resets at 2026-05-28 16:14:05)
  Core API: 4,784/5000 remaining (resets at 2026-05-28 16:47:40)
Token Usage: ~5,900 input + ~650 output = ~6,550 total (~$0.028)

Work Repositories (PRs merged)
- org/repo-a: 7 PRs
- org/repo-b: 2 PRs
- org/repo-c: 2 PRs

[... full detailed report ...]

Summary
- Strong delivery with healthy PR velocity and excellent code quality
- Balanced workload with good focus on priority items
- Active collaboration through consistent code reviews

Recommendations
- Continue current delivery pace
- Consider mentoring others on successful patterns
- Maintain strong review participation
```

**Cost**: $0.028

---

### Example 2: Compact Skill - Team Analysis

**Scenario**: Weekly analysis of entire 8-person team

**Step 1**: Generate all reports
```bash
# In your terminal
for user in user1 user2 user3 user4 user5 user6 user7; do
  bash .claude/skills/check-ic-activity/scripts/analyze_report.sh \
    $user \
    2026-05-01 2026-05-28 \
    data/team_example.md \
    > /tmp/${user}_report.json 2>/dev/null
done
```

**Step 2**: Ask Claude to format them
```
I have 7 activity reports in JSON format. Please format each one using 
the compact template (SKILL_COMPACT.md). Here's the first one:

[paste /tmp/user1_report.json]
```

After Claude formats the first report:
```
Here's the next one:

[paste /tmp/user2_report.json]
```

**Cost**: 7 × $0.017 = **$0.119** (vs $0.196 with standard skill - 39% savings)

---

### Example 3: Using Cache (Zero Cost)

**Scenario**: You ran analysis this morning, now want to check again

**First Run** (8:00 AM):
```bash
bash .claude/skills/check-ic-activity/scripts/run_ic_activity.sh nodeg 2026-04-28 2026-05-28
```
Output:
```
Fetching fresh data from GitHub API for nodeg (2026-04-28 to 2026-05-28)
GitHub API calls: 61
Results cached to data/github/cache/nodeg_2026-04-28_2026-05-28.json
```

**Second Run** (2:00 PM - within 24h TTL):
```bash
bash .claude/skills/check-ic-activity/scripts/run_ic_activity.sh nodeg 2026-04-28 2026-05-28
```
Output:
```
Using cached data (age: 6h, TTL: 24h)
GitHub API calls: 0 (using cache)
```

**GitHub API Calls**: 0  
**Claude Tokens Used**: Still ~2,900 tokens to format the report  
**Cost**: $0.017 (no GitHub API savings, but cache prevents rate limiting)

---

### Example 4: Force Refresh (Bypass Cache)

**Scenario**: You just merged a PR and want updated stats immediately

```bash
FORCE_REFRESH=true bash .claude/skills/check-ic-activity/scripts/run_ic_activity.sh nodeg 2026-04-28 2026-05-28
```

Output:
```
Fetching fresh data from GitHub API for nodeg (2026-04-28 to 2026-05-28)
GitHub API calls: 61
Results cached to data/github/cache/nodeg_2026-04-28_2026-05-28.json
```

---

## Cache Management

### List all cached reports
```bash
bash .claude/skills/check-ic-activity/scripts/cache_manager.sh list
```

Output:
```
Cached GitHub activity data:
---
  nodeg_2026-04-28_2026-05-28 (6h old)
  user1_2026-04-28_2026-05-28 (12h old)
  user2_2026-04-28_2026-05-28 (1d 2h old)
---
Total: 3 cached entries
```

### Clear cache for specific user
```bash
bash .claude/skills/check-ic-activity/scripts/cache_manager.sh clear nodeg
```

### Clear all cache
```bash
bash .claude/skills/check-ic-activity/scripts/cache_manager.sh clear
```

### View cache metadata
```bash
bash .claude/skills/check-ic-activity/scripts/cache_manager.sh info nodeg_2026-04-28_2026-05-28
```

Output:
```
Cache entry: nodeg_2026-04-28_2026-05-28
  Cached at: 2026-05-28 08:00:00
  Age: 6h
  Size: 8.0K
  Path: data/github/cache/nodeg_2026-04-28_2026-05-28.json
```

---

## Cost Comparison

### Single Report

| Version | Input Tokens | Output Tokens | Total | Cost |
|---------|--------------|---------------|-------|------|
| Standard | 5,951 | 650 | 6,601 | $0.028 |
| Compact | 2,271 | 650 | 2,921 | $0.017 |
| **Savings** | **-62%** | **0%** | **-56%** | **-40%** |

### Team Analysis (8 people)

| Version | Per Report | Team Total | Monthly (4×) | Yearly (52×) |
|---------|------------|------------|--------------|--------------|
| Standard | $0.028 | $0.224 | $0.896 | $11.648 |
| Compact | $0.017 | $0.136 | $0.544 | $7.072 |
| **Savings** | **-40%** | **-40%** | **-40%** | **-40%** |

**Annual Savings**: $4.58 per year using compact mode

---

## Rate Limit Management

GitHub has two separate API rate limits:

### Search API: 30 requests per minute
Used by: `gh search prs`, `gh search issues`, `gh search commits`  
This skill makes: 7 search API calls per report

**Warning threshold**: < 5 remaining

### Core API: 5,000 requests per hour
Used by: `gh api repos/...` for fetching issue/PR details  
This skill makes: ~50-60 core API calls per report

**Warning threshold**: < 100 remaining

### Example Output
```
GitHub API rate limits:
  Search API: 29/30 remaining
  Core API: 4,784/5000 remaining
```

### If Rate Limit is Low
```
WARNING: Core API rate limit is low! Resets at 2026-05-28 16:47:40
```

**What to do**: Wait until the reset time, or use cached data (no API calls)

---

## Understanding the Report

### Scoring Logic (QE-Optimized)

#### Delivery Score
**Metric**: `del_issues_per_week + del_prs_per_week`
- **High**: ≥ 5 combined/week
- **Medium**: 2-4 combined/week
- **Low**: < 2 combined/week

**Rationale**: QE PRs are larger (test suites), issues include bug tracking

#### Focus Score
**Metric**: `foc_wip_count + foc_open_prs` (total work-in-progress)
- **High**: ≤ 5 items
- **Medium**: 6-10 items
- **Low**: > 10 items

**Rationale**: QE work involves parallel bug investigations and test development

#### Quality Score
**Metrics**: PR size AND comments per PR (averaged, rounded down)

PR Size:
- **High**: < 800 LOC
- **Medium**: 800-2000 LOC
- **Low**: > 2000 LOC

Comments per PR:
- **High**: < 4
- **Medium**: 4-8
- **Low**: > 8

#### Collaboration Score
**Metrics**: Reviews per week AND time to first review (averaged, rounded down)

Reviews per week:
- **High**: ≥ 6
- **Medium**: 3-5
- **Low**: < 3

Time to first review:
- **High**: < 24h
- **Medium**: 24-48h
- **Low**: > 48h

---

## Troubleshooting

### Issue: GitHub API 404 errors
```
HTTP 404: 404 Not Found (https://api.github.com/search/issues?...)
```

**Solution**: Re-authenticate with GitHub CLI
```bash
gh auth refresh -h github.com
```

### Issue: Rate limit exceeded
```
WARNING: Search API rate limit is low! Resets at 2026-05-28 16:14:05
```

**Solution**: 
1. Wait until reset time (shown in warning)
2. Use cached data if available
3. Reduce frequency of fresh queries

### Issue: Cache not working
```bash
# Check cache directory exists
ls -la data/github/cache/

# Check cache entries
bash .claude/skills/check-ic-activity/scripts/cache_manager.sh list

# Force refresh to rebuild cache
FORCE_REFRESH=true bash .claude/skills/check-ic-activity/scripts/run_ic_activity.sh <user> <from> <to>
```

### Issue: Team member not found
```
"full_name": "Unknown"
```

**Solution**: Verify GitHub username in team file
```bash
grep -i "Github username" data/team_mlm_qe.md
```

Ensure format matches:
```markdown
### Name
- Full name: First Last
- Email: email@example.com
- Github username: githubuser
- Role: Software Quality Engineer
```

---

## Files Structure

```
.claude/skills/check-ic-activity/
├── README.md                      # This file
├── SKILL.md                       # Standard skill (full documentation)
├── SKILL_COMPACT.md              # Compact skill (production use)
├── COST_OPTIMIZATION.md          # Detailed cost analysis
├── scripts/
│   ├── run_ic_activity.sh        # Core data fetching script
│   ├── analyze_report.sh         # Compact wrapper (extracts team info)
│   └── cache_manager.sh          # Cache management utility
└── [generated files]
```

Data and cache:
```
data/
├── github/
│   ├── cache/                    # Cached GitHub API responses
│   │   ├── username_from_to.json
│   │   └── username_from_to.meta
│   ├── .gitignore               # Excludes cache/ from git
│   └── README.md                # Cache documentation
└── team_*.md                     # Team member context files
```

---

## Advanced Usage

### Custom Cache TTL
```bash
# Cache for 48 hours instead of default 24
CACHE_TTL_HOURS=48 bash .claude/skills/check-ic-activity/scripts/run_ic_activity.sh nodeg 2026-04-28 2026-05-28
```

### Batch Team Analysis Script
```bash
#!/bin/bash
# analyze_team.sh - Generate reports for entire team

TEAM_FILE="data/team_example.md"
FROM="2026-05-01"
TO="2026-05-28"
OUTPUT_DIR="/tmp/team_reports"

mkdir -p "$OUTPUT_DIR"

for user in user1 user2 user3 user4 user5 user6 user7; do
  echo "Analyzing $user..."
  bash .claude/skills/check-ic-activity/scripts/analyze_report.sh \
    "$user" "$FROM" "$TO" "$TEAM_FILE" \
    > "$OUTPUT_DIR/${user}.json" 2>/dev/null
  echo "✓ Saved to $OUTPUT_DIR/${user}.json"
done

echo ""
echo "All reports generated in $OUTPUT_DIR"
echo "Now ask Claude to format them using SKILL_COMPACT.md"
```

Usage:
```bash
chmod +x analyze_team.sh
./analyze_team.sh
```

### Direct JSON Analysis (No Skill)
```bash
# Get raw JSON
bash .claude/skills/check-ic-activity/scripts/run_ic_activity.sh nodeg 2026-04-28 2026-05-28 > activity.json

# Analyze with jq
jq '.del_prs_merged, .del_issues_completed, .col_reviews' activity.json
```

---

## When to Use Which Version

### Use Standard Skill When:
- ✅ Onboarding new team members
- ✅ Learning the scoring system
- ✅ Understanding QE work patterns
- ✅ Ad-hoc analysis (1-2 people)
- ✅ Need detailed context and examples

### Use Compact Skill When:
- ✅ Regular weekly/monthly team analysis
- ✅ Analyzing 3+ people at once
- ✅ Cost is a concern
- ✅ You're familiar with the report format
- ✅ Production/automated workflows

### Use Direct Script (No Claude) When:
- ✅ You just need raw JSON data
- ✅ Building custom dashboards
- ✅ Integrating with other tools
- ✅ Zero Claude API cost needed

---

## Pricing Reference (Claude Sonnet 4.5)

- **Input**: $3.00 per million tokens
- **Output**: $15.00 per million tokens

**Standard Skill**: ~6,600 tokens = $0.028  
**Compact Skill**: ~2,900 tokens = $0.017

---

## Support

For issues or questions:
1. Check this README
2. Review `COST_OPTIMIZATION.md` for cost details
3. Check `SKILL.md` for scoring logic
4. Run cache diagnostics: `bash scripts/cache_manager.sh list`

---

## Changelog

### v1.0.0 (2026-05-28)
- ✅ Initial release with caching
- ✅ Dual API rate limit tracking (Search + Core)
- ✅ Stale issue/PR filtering (2yr/1yr)
- ✅ API call counting
- ✅ Compact mode (40% cost savings)
- ✅ Token usage estimation
