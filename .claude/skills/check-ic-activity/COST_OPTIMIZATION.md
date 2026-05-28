# Cost Optimization for IC Activity Reports

## Token Usage Comparison

| Component | Standard Skill | Compact Skill | Savings |
|-----------|---------------|---------------|---------|
| **Skill Instructions** | 14,085 chars (~3,521 tokens) | 2,344 chars (~586 tokens) | **-2,935 tokens (-83%)** |
| **Team Context** | 3,200 chars (~800 tokens) | 200 chars (~50 tokens) | **-750 tokens (-94%)** |
| **JSON Data** | 6,521 chars (~1,630 tokens) | 6,538 chars (~1,635 tokens) | +5 tokens (+0.3%) |
| **Total Input** | **~5,951 tokens** | **~2,271 tokens** | **-3,680 tokens (-62%)** |
| **Output (Report)** | ~650 tokens | ~650 tokens | 0 tokens |
| **TOTAL** | **~6,601 tokens** | **~2,921 tokens** | **-3,680 tokens (-56%)** |

## Cost Comparison

| Metric | Standard | Compact | Savings |
|--------|----------|---------|---------|
| Input cost | $0.0179 | $0.0068 | -$0.0111 (-62%) |
| Output cost | $0.0098 | $0.0098 | $0.0000 (0%) |
| **Cost per report** | **$0.0277** | **$0.0166** | **-$0.0111 (-40%)** |
| **Cost for 8-person team** | **$0.22** | **$0.13** | **-$0.09 (-40%)** |
| **Monthly (4x team analysis)** | **$0.88** | **$0.53** | **-$0.35 (-40%)** |
| **Yearly (52x team analysis)** | **$11.47** | **$6.91** | **-$4.56 (-40%)** |

## Optimization Techniques Applied

### 1. Minimal Skill Instructions (-83% tokens)
**Before**: 14KB SKILL.md with extensive documentation, examples, scoring logic
**After**: 2.3KB SKILL_COMPACT.md with just the report template

**What was removed**:
- Caching documentation and examples
- Detailed scoring explanations
- Style guidelines
- QE work pattern interpretation
- Example summaries and recommendations

**What remains**:
- Report format template
- Scoring thresholds (condensed)
- Field mapping

### 2. Targeted Team Member Extraction (-94% tokens)
**Before**: Loads entire team file with 9 members (3.2KB)
**After**: Extracts only the target member's full name and role (~200 chars)

**Implementation**: `analyze_report.sh` script uses grep/sed to extract just 2 fields

### 3. Direct JSON Pass-through (0% change)
The activity data JSON remains unchanged - it's already optimized

## Usage

### Standard Skill (for documentation/learning)
```bash
/check-ic-activity --days 30 nodeg
```
Cost: ~$0.028 per report

### Compact Skill (for production use)
```bash
bash .claude/skills/check-ic-activity/scripts/analyze_report.sh nodeg 2026-04-28 2026-05-28 data/team_example.md
```

Then paste the JSON output and ask Claude:
> Format this activity report following the template in SKILL_COMPACT.md

Cost: ~$0.017 per report (40% savings)

## Recommendations

1. **Use compact version for regular team analysis** - Saves 40% on costs
2. **Use standard version for training/onboarding** - Better documentation
3. **Cache aggressively** - Subsequent queries within 24h cost $0
4. **Batch team analysis** - Analyze everyone at once rather than spread out

## Future Optimization Opportunities

1. **Compress JSON field names** (could save ~200 tokens)
   - `meta_rate_limit_search_remaining` → `rl_s_rem`
   - Requires updating the script

2. **Remove unused fields from JSON** (could save ~100 tokens)
   - `detail_personal_repositories` is often empty
   - `meta_commits_personal` is often 0

3. **Pre-aggregate metrics** (could save ~300 tokens)
   - Calculate scores in bash, return only final scores
   - Trade-off: Less transparency

**Estimated max savings**: Additional 20% reduction → **$0.013 per report**
