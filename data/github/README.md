# GitHub Data Cache

This directory contains cached GitHub API responses for the `check-ic-activity` skill.

## Structure

```bash
data/github/
└── cache/
    ├── {username}_{from_date}_{to_date}.json  # Cached activity data
    └── {username}_{from_date}_{to_date}.meta  # Cache timestamp
```

## Purpose

The cache prevents GitHub API rate limiting by storing activity query results locally. When the same query is made within the cache TTL (default 24 hours), the cached result is returned instead of making a new API call.

## Cache Management

Use the cache manager script to view and manage cached data:

```bash
# List all cached entries
bash .claude/skills/check-ic-activity/scripts/cache_manager.sh list

# Clear all cache
bash .claude/skills/check-ic-activity/scripts/cache_manager.sh clear

# Clear cache for specific user
bash .claude/skills/check-ic-activity/scripts/cache_manager.sh clear nodeg

# View cache metadata
bash .claude/skills/check-ic-activity/scripts/cache_manager.sh info nodeg_2026-04-28_2026-05-28
```

## Configuration

- **TTL**: Set `CACHE_TTL_HOURS` environment variable (default: 24)
- **Force refresh**: Set `FORCE_REFRESH=true` to bypass cache

## Gitignore

Cache files are gitignored to prevent committing large/stale data to the repository.
