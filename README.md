# EM AI

**EM AI turns Claude into an Engineering Manager operating system.**

Not a generic AI. Not a blank prompt.

A context-aware, opinionated system that understands:
- your team
- your manager style
- your context
- how you run engineering

## Why Claude EM

It comes with:
1. Persistent context → **your team** + **your way of working**
2. Reusable workflows → **skills** that support real EM tasks

Claude EM is built for **day-to-day EM work**:
- Plan initiatives with clear scope and trade-offs
- Write epics and stories that engineers can actually build
- Analyze IC performance using real data (Jira + GitHub)
- Prepare 1:1s with context and intent
- Think through org and leadership decisions

It is intentionally **CLI-first**: faster, more predictable, and more cost-efficient (tokens).

Works out of the box with **Jira** and **GitHub**. Other tools can be added via CLI scripts or MCP servers.

---

## Quick start (2 minutes)

1. Clone this repository.

2. Install Claude Code:

```bash
npm install -g @anthropic-ai/claude-code
```

3. Add your team context and EM style:

* Copy `data/team_example.md` → `data/team_myteam.md` and fill in your team and members.
* Copy `data/em_style_example.md` → `data/em_style.md` and fill in your style.

4. Open Claude in your workspace:

```bash
claude
```

5. Try your first prompt:

> Analyze doms last 30 days, please.

---

## Example use cases

* Plan an initiative
  > We have recurring CI flakiness slowing down delivery. Plan an initiative to reduce it

* Analyze IC activity
  > Analyze Maria's last 30 days

* Prepare a 1:1
  > Prepare a 1:1 with Ana. She’s delivering less lately and seems disengaged. I want to understand what's going on

* Write a strategy
  > Write a strategy to reduce operational load on the team while maintaining reliability

* Mentor
  > I'm considering reorganizing the team into two squads. Help me think through trade-offs and risks

* Prepare the daily meeting
  > Give me a daily-ready view of the team's board

* Generate a user story map
  > Generate a user story map from this PRD: [paste PRD]

* Check an epic
  > Check this epic

* Write a delivery epic
  > Write an epic to implement rate limiting in our API. Include scope, risks, and definition of done

* Write a discovery epic
  > We have performance issues in the frontend. Write a discovery epic to understand root causes and options
 
 ---

## How it works

* **CLAUDE.md** defines how Claude should behave
* **EM style** (`data/em_style.md`) defines your personal way of working
* **Skills** (`.claude/skills/`) are reusable prompts for real EM tasks
* **Team context** (`data/team_*.md`) defines your team
* **Data** (`data/`) stores shared information (Jira, GitHub, etc.)
* **Initiatives** are folders where work, analysis, and outputs live
* **CLI-first approach**: prefers CLI tools over MCP servers to stay fast, predictable, and low-cost in terms of tokens

---

## Skills

| Skill | What it does |
|---|---|
| `/check-gh-board` | Daily health check of a GitHub project board (v2): flow, people load, stuck/blocked issues, and bugs at risk of breaching SLA |
| `/check-epic` | Analyze an Epic's definition, decomposition, and execution using Jira data |
| `/check-ic-activity` | Analyze an IC's delivery, quality, and collaboration using Jira + GitHub data |
| `/mentor-me` | Think through a leadership situation with an Engineering Director mindset |
| `/one-on-one` | Prepare for a 1:1 — situation read, key questions, risks, and opening line |
| `/plan-initiative` | Structure a rough idea into a scoped initiative with epics and next steps |
| `/us-mapping` | Generate a User Story Map from a PRD or Figma design |
| `/write-epic-build` | Write a delivery epic with scope, risks, and definition of done |
| `/write-epic-technical-discovery` | Write a discovery epic focused on reducing uncertainty and enabling a decision |
| `/write-strategy` | Draft a strategy doc (Rumelt + Larson) with diagnosis, policies, and actions |
| `/write-us` | Draft a user story following INVEST and vertical slicing |
| `/write-vision` | Draft a vision doc with value proposition, capabilities, and constraints |

---

## Workspace structure

```bash
em-ai/
├── data/                       # Shared data across initiatives
│   ├── team_{name}.md          # Team context files
│   ├── em_style.md             # Engineering Manager style
│   ├── [source]/               # One folder per data source (GitHub for example)
│   └── tmp/                    # Temporary files
└── [initiative-name]/          # One folder per initiative
    ├── data/                   # Initiative-specific data
    ├── tmp/                    # Temporary files
    ├── scripts/                # Analysis and processing
    └── output/                 # Results and reports
```

---

## Setup (full)

### 1. Create your workspace

Fork or simply clone this repository. This gives you a fully independent workspace you can customize.

---

### 2. Install Claude Code

Check the [official docs](https://docs.anthropic.com/claude-code) and use your preferred installation method.

---

### 3. Configure your team and EM profile

Add

* Your EM style
* Your team details
* Your expectations from Claude
* Your way of working

by

* Copying `data/team_example.md` → `data/team_myteam.md` and fill in your team and member details.
* Copying `data/em_style_example.md` → `data/em_style.md` and fill in your style.

---

### 4. Install CLI tools

Claude EM is designed to work primarily with CLI tools instead of MCP, as they are faster and more cost-efficient.

**GitHub CLI (`gh`)**

```bash
brew install gh
gh auth login
```

> Docs: https://cli.github.com

---

### 5. Configure credentials

Create a `.env.local` file at the workspace root (git-ignored):

```bash
GITHUB_TOKEN="your-github-token"

```

Getting credentials:
- **GitHub token**: https://github.com/settings/tokens (scopes: `repo`, `read:org`, `read:user`)

---

### 7. (Optional) Configure MCP servers

MCP servers give Claude direct access to Jira, GitHub, and Figma without CLI or scripts.

```bash
claude mcp add --plugin atlassian
claude mcp add --plugin github
claude mcp add --plugin figma
```

### 8. (Optional) Get the most out of 1:1s

The `/one-on-one` skill works with nothing but a one-line prompt, but it gets sharper the more context you give it through the team file.

**Per-person 1:1 doc.** Give any member a living doc and the skill will read it when preparing the conversation — open topics, agreed actions, signals to watch, goals, and what happened in past 1:1s:

* Add a `1:1 file:` link to the member in `data/team_{your-team}.md`
* The value can be a URL or a path, and the doc can be in **any format** — the skill adapts to whatever's there
* For a suggested starting point, see `.claude/skills/one-on-one/references/person-file-example.md`
* It's fully optional: if it's missing or unreachable, the skill simply ignores it

**Career Frameworks.** Fill in the `## Career Frameworks` section of the team file with links (per level) to your expectations docs. The skill reads the one matching the member's seniority when the conversation turns to expectations or growth.

---

## Notes

* You don’t need full setup to start — Quick Start is enough
* CLI tools and MCP improve automation but are optional
* The system works best when your team context is accurate and up to date

---

## Contributing

Contributions are welcome:

* Feedback from real usage
* Suggestions
* New skills
* Support for additional tools

---

## Origin

Original project called [claude-em](https://github.com/jcesarperez/claude-em)
developed by Julio César Pérez Arques.

## License

MIT
