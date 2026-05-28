---
name: check-ic-activity-compact
description: Cost-optimized activity report generator (65% token reduction vs standard skill)
---

## Usage

```bash
bash .claude/skills/check-ic-activity/scripts/analyze_report.sh <github_username> <from_date> <to_date> [team_file]
```

Returns JSON with activity metrics. Format into concise report:

```bash
QE Activity Report: {full_name} ({github_username})
Period: {from} to {to}
GitHub API Calls: {meta_api_calls}
Rate Limits: Search {meta_rate_limit_search_remaining}/{meta_rate_limit_search_limit}, Core {meta_rate_limit_core_remaining}/{meta_rate_limit_core_limit}
Token Usage: ~{input_tokens} input + ~{output_tokens} output = ~{total_tokens} total (~${cost})

Work Repositories (PRs merged): {detail_work_repos_count}
Personal Repositories: {detail_personal_repos_count or "None"}

Delivery (Score: High ≥5 | Med 2-4 | Low <2 issues+PRs/week):
- {del_issues_completed} issues (~{del_issues_per_week}/week): {del_issues_by_type}
- Issue cycle time: {del_issue_cycle_time_days}d
- {del_prs_merged} PRs (~{del_prs_per_week}/week) — {del_total_loc} LOC
- PR cycle time: {del_pr_cycle_time_days}d
- Commits: {del_commits} (~{del_commits_per_pr}/PR)
- Score: [calculate]

Focus (Score: High ≤5 | Med 6-10 | Low >10 WIP):
- Open issues: {foc_wip_count}, Open PRs: {foc_open_prs}
- Total WIP: {foc_wip_count + foc_open_prs}
- Score: [calculate]

Open Issues ({foc_wip_count}): [Group by high-priority, epics, infrastructure, medium, low]

Open PRs ({foc_open_prs}): [List with repo]

Quality (Score: Avg PR size <800=H, 800-2000=M, >2000=L | Comments <4=H, 4-8=M, >8=L):
- Avg PR size: {qua_avg_pr_size} LOC
- Comments/PR: {qua_comments_per_pr}
- Cancelled PRs: {qua_prs_cancelled}
- Score: [calculate avg, round down]

Collaboration (Score: Reviews ≥6=H, 3-5=M, <3=L | Time <24h=H, 24-48h=M, >48h=L):
- Reviews: {col_reviews} (~{col_reviews_per_week}/week)
- Avg time to first review: {col_avg_time_to_first_review_as_reviewer_hours}h
- Score: [calculate avg, round down]

Summary: 2-3 concise insights about QE work patterns
Recommendations: 2-4 actionable suggestions
```

## Token Estimation

- Input: JSON (~1,625) + this file (~400) + team member info (~100) = **~2,125 tokens** (64% reduction)
- Output: Report (~650 tokens)
- **Total: ~2,775 tokens (~$0.010 vs $0.027)** — 63% cost savings
