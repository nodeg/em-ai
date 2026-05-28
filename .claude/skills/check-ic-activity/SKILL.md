---
name: check-ic-activity
description: >
  Use this skill whenever the user wants to analyze the activity of a Software Quality Engineer (SQE/QE/QA).
  You have access to a CLI tool that retrieves activity data from GitHub (PRs, issues, reviews, commits).
  Optimized for QE work patterns: test infrastructure, automation, bug tracking, and code review.

---

## Tool

Run this script using the Bash tool:

```
bash .claude/skills/check-ic-activity/scripts/run_ic_activity.sh <github_username> <from_date> <to_date>
```

- `github_username`: the user's GitHub handle (e.g. `nodeg`)
- `from_date`: start date in `YYYY-MM-DD` format (e.g. `2026-02-01`)
- `to_date`: end date in `YYYY-MM-DD` format (e.g. `2026-02-28`)

To resolve `github_username` for a team member, check `data/team_*.md` files first.

### Caching

The script implements intelligent caching to prevent GitHub API rate limiting:

- **Cache location**: `data/github/cache/`
- **Cache key**: `{username}_{from_date}_{to_date}.json`
- **Default TTL**: 24 hours (configurable via `CACHE_TTL_HOURS` environment variable)
- **Force refresh**: Set `FORCE_REFRESH=true` to bypass cache

**Cache behavior:**
- On first run for a given user/date range, fetches from GitHub API and caches the result
- Subsequent runs within the TTL return cached data instantly (no API calls)
- Cache automatically expires after TTL hours
- Cache messages are sent to stderr, so they don't interfere with JSON output

**Examples:**
```bash
# Use cache if available (default)
bash .claude/skills/check-ic-activity/scripts/run_ic_activity.sh nodeg 2026-04-28 2026-05-28

# Force refresh from GitHub API
FORCE_REFRESH=true bash .claude/skills/check-ic-activity/scripts/run_ic_activity.sh nodeg 2026-04-28 2026-05-28

# Custom TTL (48 hours)
CACHE_TTL_HOURS=48 bash .claude/skills/check-ic-activity/scripts/run_ic_activity.sh nodeg 2026-04-28 2026-05-28
```

### Cache Management

A cache manager script is provided for viewing and clearing cached data:

```bash
# List all cached entries
bash .claude/skills/check-ic-activity/scripts/cache_manager.sh list

# Clear all cache
bash .claude/skills/check-ic-activity/scripts/cache_manager.sh clear

# Clear cache for specific user
bash .claude/skills/check-ic-activity/scripts/cache_manager.sh clear Pablogoliva

# View cache metadata
bash .claude/skills/check-ic-activity/scripts/cache_manager.sh info Pablogoliva_2026-04-28_2026-05-28
```

**Date resolution** — convert user expressions to `from_date` and `to_date` before calling the script. If no time range is specified, default to the last 14 days:
- (no date specified) → FROM = today - 14 days, TO = today
- "last 14 days" → FROM = today - 14 days, TO = today
- "last month" → FROM = first day of previous month, TO = last day of previous month
- "February 2026" → FROM = 2026-02-01, TO = 2026-02-28
- "this week" → FROM = Monday of current week, TO = today

The script outputs JSON metrics (alphabetically sorted, prefixed by category):
```json
{
  "col_avg_time_to_first_review_as_reviewer_hours": number,
  "col_reviews": number,
  "col_reviews_per_week": number,
  "del_issue_cycle_time_days": number,
  "del_pr_cycle_time_days": number,
  "del_commits": number,
  "del_commits_per_pr": number,
  "del_issues_by_type": { "Bug": number, "Enhancement": number, "Task": number },
  "del_issues_completed": number,
  "del_issues_per_week": number,
  "del_prs_merged": number,
  "del_prs_per_week": number,
  "del_total_loc": number,
  "foc_open_prs": number,
  "foc_wip_count": number,
  "period_days": number,
  "qua_avg_pr_size": number,
  "qua_comments_per_pr": number,
  "qua_prs_cancelled": number,
  "detail_open_issues": [{"number": number, "title": string, "repository": string, "labels": [string], "url": string}],
  "detail_open_prs": [{"number": number, "title": string, "repository": string, "url": string}],
  "detail_work_repositories": [string],
  "detail_work_repos_count": {"repo/name": number},
  "detail_personal_repositories": [string],
  "detail_personal_repos_count": {"repo/name": number},
  "meta_github_username": string,
  "meta_prs_personal": number,
  "meta_commits_personal": number,
  "meta_api_calls": number,
  "meta_rate_limit_search_remaining": number,
  "meta_rate_limit_search_limit": number,
  "meta_rate_limit_search_reset": number,
  "meta_rate_limit_search_reset_time": string,
  "meta_rate_limit_core_remaining": number,
  "meta_rate_limit_core_limit": number,
  "meta_rate_limit_core_reset": number,
  "meta_rate_limit_core_reset_time": string
}
```

**Note:** All data is sourced from GitHub (issues, PRs, reviews, commits).

**API Call Tracking:**
- The `meta_api_calls` field shows the number of GitHub API calls made to generate the data
- When using cached data, the stderr output shows "GitHub API calls: 0 (using cache)"
- Fresh data typically requires 7 base API calls + additional calls per issue/PR/review for details

**Rate Limit Tracking:**
- The script tracks TWO separate GitHub API rate limits:
  - **Search API**: 30 requests per minute (used by `gh search` commands)
  - **Core API**: 5000 requests per hour (used by `gh api` commands for details)
- Search API fields:
  - `meta_rate_limit_search_remaining`: Remaining search API calls
  - `meta_rate_limit_search_limit`: Total search API limit (30)
  - `meta_rate_limit_search_reset`: Unix timestamp when search limit resets
  - `meta_rate_limit_search_reset_time`: Human-readable search reset time
- Core API fields:
  - `meta_rate_limit_core_remaining`: Remaining core API calls
  - `meta_rate_limit_core_limit`: Total core API limit (5000)
  - `meta_rate_limit_core_reset`: Unix timestamp when core limit resets
  - `meta_rate_limit_core_reset_time`: Human-readable core reset time
- Warnings:
  - Search API: Warning if remaining < 5
  - Core API: Warning if remaining < 100

**Filtering of Open Items:**
- Open issues are filtered to exclude issues not updated in the last 2 years (based on `updatedAt`)
- Open PRs are filtered to exclude PRs not updated in the last 1 year (based on `updatedAt`)
- This prevents stale items from skewing the current focus metrics

**Personal vs Work Repositories:**
- Personal repositories (username/repo-name) are tracked separately but **excluded from scoring metrics**
- Only work repositories (org/repo-name or other users' repos) count toward delivery, quality, and collaboration scores
- Both personal and work repos are shown in the detailed repository sections for full visibility

---

## Instructions

1. Look up the user's `github_username` and full name from `data/team_*.md`
2. Run the script with the Bash tool
3. Analyze the returned metrics
4. Produce a structured report with scoring and recommendations
5. **Calculate token usage and cost estimates**:
   - **Input tokens calculation**:
     - SKILL.md instructions: ~3,500 tokens (14KB file)
     - JSON data from script: char_count ÷ 4 (typically ~1,600 tokens for 6.5KB JSON)
     - Team context file: ~800 tokens (3.2KB file)
     - **Estimated input**: ~5,900 tokens
   - **Output tokens calculation**:
     - Formatted report character count ÷ 4
     - **Estimated output**: ~600-800 tokens (2.5-3KB report)
   - **Cost calculation** using Claude Sonnet 4.5 pricing:
     - Input: $3.00 per million tokens
     - Output: $15.00 per million tokens
     - Formula: (input_tokens × $3 / 1,000,000) + (output_tokens × $15 / 1,000,000)
     - **Typical cost per report**: ~$0.02 ($0.018 input + $0.012 output)
6. **Include detailed sections** showing:
   - Team member's full name in the report header
   - Work repositories where PRs were merged (with counts) — these count toward metrics
   - Personal repositories where PRs were merged (with counts) — shown for visibility but excluded from scoring
   - Open issues grouped by priority (High → Epics → Infrastructure → Medium → Low/Other)
   - Open PRs with their repositories
6. **Scoring and metrics** are based on work repositories only — personal repos are informational
7. **Open Issues formatting**: Categorize by priority and type for better readability. Each issue should appear in only one category (the highest priority/most specific one it qualifies for)

---

## Scoring Logic (QE-Optimized)

### Delivery
QE work combines test automation, bug tracking, and infrastructure improvements. Score based on combined throughput:
- **Combined metric**: del_issues_per_week + del_prs_per_week
  - High ≥ 5 | Medium 2–4 | Low < 2
  - Rationale: QE PRs tend to be larger (test suites, infrastructure) and take longer; issues include bug tracking and verification work

### Focus
QE engineers juggle bug investigations, test development, and infrastructure work. Score based on total WIP:
- **Combined metric**: foc_wip_count (open issues) + foc_open_prs
  - High ≤ 5 | Medium 6–10 | Low > 10
  - Rationale: QE work often involves parallel bug investigations and longer-running test development

### Quality
QE PRs are typically larger (test suites, configs, automation). Score each metric independently, then average (round down):
- qua_avg_pr_size: High < 800 | Medium 800–2000 | Low > 2000
  - Rationale: Test files and automation code are naturally larger than feature code
- qua_comments_per_pr: High < 4 | Medium 4–8 | Low > 8
  - Rationale: Test code and infrastructure should be straightforward; high comments suggest complexity issues

If the individual scores differ, show each metric's score inline next to its value in the report.

### Collaboration
QE engineers provide critical code review from a quality perspective. Score each independently, then average (round down):
- col_reviews_per_week: High ≥ 6 | Medium 3–5 | Low < 3
  - Rationale: QE reviews catch quality issues; 6+ reviews/week shows strong engagement
- col_avg_time_to_first_review_as_reviewer_hours: High < 24h | Medium 24–48h | Low > 48h
  - Rationale: Fast feedback prevents quality issues from propagating

If the individual scores differ, show each metric's score inline next to its value in the report.

---

## QE Work Pattern Interpretation

When analyzing metrics, consider these QE-specific patterns:

**Issues:**
- Bugs closed = reactive quality work (finding, tracking, verifying fixes)
- Enhancements = proactive improvements (test coverage, automation, tooling)
- Tasks = maintenance, infrastructure, CI/CD improvements

**PRs:**
- Test automation, framework improvements, CI/CD configs
- Typically larger than feature code (test suites, test data)
- Longer cycle times acceptable for comprehensive test coverage

**Reviews:**
- Critical QE contribution — catching quality issues early
- Reviews should focus on testability, edge cases, error handling
- High review participation = strong quality advocacy

**Focus Patterns:**
- High WIP may indicate: multiple bug investigations, long-running test development, or context switching between reactive and proactive work
- Open issues often = bugs awaiting verification or complex investigations

---

Return ONLY this format:

QE Activity Report: [Full Name] ([GitHub Username])
Period: FROM to TO
GitHub API Calls: X
Rate Limits:
  Search API: X/30 remaining (resets at YYYY-MM-DD HH:MM:SS)
  Core API: X/5000 remaining (resets at YYYY-MM-DD HH:MM:SS)
Token Usage: ~X,XXX input + ~X,XXX output = ~X,XXX total (~$X.XX)

Work Repositories (PRs merged)
- repo/name: X PRs
- repo/name: Y PRs
(list all repositories from detail_work_repos_count)

Personal Repositories (PRs merged - not included in metrics)
- username/repo-name: X PRs
- username/repo-name: Y PRs
(list all repositories from detail_personal_repos_count, or "None" if empty)

Delivery
- X issues closed (~X.X issues/week)
  - X Bugs, X Enhancements, X Tasks
- Issue cycle time: Xd
- Y PRs merged (~Y.Y PRs/week) — X LOC total
- PR cycle time: Xd
- Commits: X (~X.X commits/PR)
- Score: High | Medium | Low

Current Focus
- Issues assigned (open): X
- Open PRs: X
- Total WIP: X
- Score: High | Medium | Low

Open Issues Detail ([total count])

High Priority ([count])
- #[number] [repository] — [title]
  (only issues with "high-priority" label)

Epics ([count])
- #[number] [repository] — [title]
  (only issues with "epic" or "epics" label, if not already shown in high-priority)

Infrastructure ([count])
- #[number] [repository] — [title]
  (only issues with "infrastructure" label, if not already shown above)

Medium Priority ([count])
- #[number] [repository] — [title]
  (only issues with "medium-priority" label)

Low Priority / Other ([count])
- #[number] [repository] — [title]
  (remaining issues)

**Note**: Group issues by priority and type for better visibility. Show label-based categorization. Issues may appear in multiple categories if they have multiple relevant labels - prioritize showing them in the highest-priority/most-specific category only.

Open PRs Detail
(for each PR in detail_open_prs, show):
- #[number] [repository] — [title]

Quality
- Avg PR size: X LOC
- Comments per PR: X
- Cancelled PRs: X
- Score: High | Medium | Low

Collaboration
- Reviews given: X (~X.X/week)
- Avg time to first review as reviewer: Xh
- Score: High | Medium | Low

Summary
- 2–3 concise insights about behavior and patterns
- Consider QE-specific work: test automation vs bug tracking, proactive vs reactive work, quality advocacy

Recommendations
- 2–4 actionable, practical suggestions
- Focus on QE trade-offs: reactive bug work vs proactive automation, breadth vs depth in testing, individual contribution vs team support

---

## Style Guidelines

- Be concise and direct (engineering manager tone)
- Avoid fluff
- Prefer interpretation over raw data repetition
- Highlight trade-offs, not just metrics
- Do not hallucinate missing data
- **QE context**: Consider test automation, bug tracking, infrastructure work, and quality advocacy in your analysis

---

## Example Summary (QE-focused style reference)

- Strong test automation delivery with healthy PR cycle times
- Balancing bug investigations with infrastructure improvements
- Active quality advocate through consistent code reviews

## Example Recommendations (QE-focused style reference)

- Reduce parallel bug investigations to improve issue resolution time
- Continue strong review participation — quality feedback is valuable
- Consider batching smaller test additions to reduce PR overhead
- Balance reactive bug work with proactive test automation
