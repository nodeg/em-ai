---
name: check-gh-board
description: >
  Evaluate the daily health of a GitHub Projects v2 board: flow, people load, and bugs at risk.
  Use whenever the user wants a daily-standup-ready view of a board — what's stuck, who's
  overloaded, who can pull, what's blocked.
---

## Tool

Run this script using the Bash tool:

```
bash .claude/skills/check-gh-board/scripts/fetch_gh_project.sh <PROJECT_NUMBER> <ORG_NAME> --metrics-only
```

- `PROJECT_NUMBER`: numeric project number (e.g. `32`)
- `ORG_NAME`: organization name (e.g. `SUSE`, `myorg`) — required, no default
- `--metrics-only`: exclude items array (98% token reduction, always use this)
- **Read-only**: This script only queries data via GraphQL, no mutations are performed.

The script outputs JSON with `fetched_at`, `project`, and `metrics` objects.

---

## Instructions

### Resolving the input

The skill accepts either:
- A **team name** (e.g. `mlm_qe`) → extract minimal context using:
  ```
  bash .claude/skills/check-gh-board/scripts/extract_team_context.sh data/team_{name}.md
  ```
  This outputs `{org, project_number, team_roster}` in ~65 tokens instead of ~830 tokens for the full team file.
  Then use org and project_number for the board fetch, keep team_roster for idle filtering.
- A **project number with org** (e.g. `32 SUSE`) → use the provided org and project number. No roster available; skip roster-based filters and say so.

If the team file is missing or has no `Default board`, ask the user for both the org name and project number before continuing.

### Analysis steps

1. Resolve the input as above. If a team name is provided:
   - Extract minimal context with `extract_team_context.sh` (~65 tokens)
   - Parse `org`, `project_number`, and `team_roster` from the output
2. Run the board fetch script with `--metrics-only`. Stop and report the error if it fails.
3. Extract API metrics from `meta.api_calls` and `meta.rate_limit`.
4. Calculate token usage:
   - Count input tokens: SKILL_COMPACT.md (~1,648 tokens) + team context (~65 tokens) + JSON output (~3,520 tokens) = ~5,233 input tokens
   - Estimate output tokens: ~650 tokens for formatted report
   - Calculate cost: (5,233 × $3/1M) + (650 × $15/1M) = $0.016 + $0.010 = ~$0.026
5. Use the pre-computed `metrics` for all rubric checks.
6. Filter idle assignees to only `team_roster` members.
7. Produce the structured report below.

---

## Scoring Rubrics

### Flow Health

**Stuck** (use `metrics.stuck`):
- 🟢 None | 🟡 1–2 warnings (≥5d), no critical | 🔴 Any critical (≥10d), or ≥3 warnings

**Blocked** (use `metrics.blocked_count` and `metrics.blocked`):
- 🟢 0 | 🟡 1–2 | 🔴 ≥3, or any blocked item also stuck ≥10d

**Unassigned in In Progress** (use `metrics.unassigned_in_progress`):
- 🟢 None | 🔴 Any

**Overall Flow state**:
- 🟢 Moving — all signals 🟢
- 🟡 At Risk — any 🟡, no 🔴
- 🔴 Stalled — any 🔴

### People Health

**WIP balance** (use `metrics.assignees`):
- Overloaded: assignee with `count ≥ 4` in In Progress, or `count ≥ 3` AND `stuck_count ≥ 2`
- Heavy stuck: assignee with `stuck_count ≥ 2` regardless of count

**Idle / can-pull** (use `metrics.idle_assignees`):
- Filter to the team roster: only include names that match `team_roster` (full names from the team file)
- If no team file was loaded, skip this signal and write "Idle filter unavailable — no team file resolved."

**Overall People state**:
- 🟢 Healthy — no overload, no unassigned in progress
- 🟡 At Risk — 1 overloaded person, or any single 🟡 signal
- 🔴 Stretched — multiple overloaded, or any unassigned in progress, or someone with `stuck_count ≥ 3`

### Bugs at Risk

Use `metrics.bugs_at_risk` as-is, sorted by risk.

**Overall Bugs state**:
- 🟢 No red, no yellow | 🟡 Any yellow, no red | 🔴 Any red

### Epic Health

Use `metrics.epics`. List epics that are open, with their assignees. Informational only — no specific scoring.

---

## Output Format

Return ONLY this structure:

---

📋 Board Snapshot — ORG/PROJECT_NUMBER: Name
GitHub API Calls: X
Rate Limit:
  GraphQL API: X/5000 remaining (resets at YYYY-MM-DD HH:MM:SS)
Token Usage: ~X input + ~X output = ~X total (~$X.XX)

- Total (snapshot): X · In Progress: X · To Do: X · Done last 36h: X
- Blocked: X
- Status distribution: Status (count), Status (count), ...

🌊 Flow Health — 🟢 Moving / 🟡 At Risk / 🔴 Stalled

- Stuck: 🟢/🟡/🔴 — X warnings, X critical
  - #NUMBER — title (Xd in status, assignee)[ · BLOCKED]
  - ...up to ~6, prioritize critical
- Blocked: 🟢/🟡/🔴 — X items
  - #NUMBER — title (status, assignee, Xd in status)
  - ...
- Unassigned in In Progress: #NUMBER — title, #NUMBER — title  |  None

👥 People Health — 🟢 Healthy / 🟡 At Risk / 🔴 Stretched

- Overloaded: Name (X WIP, X stuck), ...  |  None
- Heavy stuck: Name (X stuck), ...  |  None
- Can pull (idle): Name, Name  |  None visible  |  Idle filter unavailable — no team file

🛤️ Epic Health

- #NUMBER — epic title (status, assignees)
- #NUMBER — epic title (status, assignees)
- ...
- No epics on board  |  (only when no epics)

🐞 Bugs at Risk — 🟢 / 🟡 / 🔴

- 🔴 #NUMBER — title
  priority · assignee
- 🟡 #NUMBER — title
  priority · assignee
- ...
- Bugs without high priority on the board: X (informational)

🧭 Summary

- 3–5 bullets max. The actionable story for today's standup. Focus on:
  - The 1–2 issues most likely to slip today
  - Who needs help (overloaded, heavy stuck)
  - Who can pull (idle)
  - Top blocker to unblock
  - Any high-priority bug

🎯 Recommendations

1. [Verb] Specific concrete action — cite #NUMBER or Name
2. ...
(2–5 items, ordered by urgency)

---

## Style Guidelines

- Always cite issue numbers, durations, and people by name — no vague observations.
- Mention assignee on every stuck/blocked/at-risk item so the EM knows who to talk to.
- Be concise and direct — EM tone, no fluff.
- Prioritize signal over completeness: if there are 20 stuck items, list the top ~6 most severe and say "and N more".

## Constraints

- DO NOT flag unassigned issues in To Do — only in In Progress.
- DO NOT list as idle anyone outside `team_roster` when a team file was loaded.
- DO NOT recompute metrics from `items`; trust the pre-computed `metrics`.
- DO NOT show Done items older than 36h (the script already trims them).
- Avoid generic recommendations like "improve communication". Be specific: "ping <name> on #NUMBER — stuck Xd with no recent update".
