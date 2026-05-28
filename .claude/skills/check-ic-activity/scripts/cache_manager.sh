#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_DIR="$SCRIPT_DIR/../../../../data/github/cache"

usage() {
  cat <<EOF
Usage: $0 <command>

Commands:
  list              List all cached entries with age
  clear [username]  Clear all cache (or specific user's cache)
  info <cache_key>  Show cache metadata

Examples:
  $0 list
  $0 clear nodeg
  $0 clear
  $0 info nodeg_2026-04-28_2026-05-28
EOF
  exit 1
}

list_cache() {
  if [[ ! -d "$CACHE_DIR" ]]; then
    echo "No cache directory found"
    return
  fi

  echo "Cached GitHub activity data:"
  echo "---"

  local count=0
  for meta_file in "$CACHE_DIR"/*.meta; do
    [[ -f "$meta_file" ]] || continue

    local cache_key=$(basename "$meta_file" .meta)
    local cache_time=$(cat "$meta_file")
    local current_time=$(date +%s)
    local age_hours=$(( (current_time - cache_time) / 3600 ))
    local age_days=$(( age_hours / 24 ))

    if [[ $age_days -gt 0 ]]; then
      echo "  $cache_key (${age_days}d ${age_hours}h old)"
    else
      echo "  $cache_key (${age_hours}h old)"
    fi

    count=$((count + 1))
  done

  if [[ $count -eq 0 ]]; then
    echo "  No cached entries"
  else
    echo "---"
    echo "Total: $count cached entries"
  fi
}

clear_cache() {
  local username="$1"

  if [[ ! -d "$CACHE_DIR" ]]; then
    echo "No cache directory found"
    return
  fi

  if [[ -z "$username" ]]; then
    # Clear all
    local count=$(find "$CACHE_DIR" -name "*.json" -o -name "*.meta" | wc -l | tr -d ' ')
    if [[ $count -eq 0 ]]; then
      echo "Cache is already empty"
    else
      rm -f "$CACHE_DIR"/*.json "$CACHE_DIR"/*.meta
      echo "Cleared all cache entries"
    fi
  else
    # Clear specific user
    local count=$(find "$CACHE_DIR" -name "${username}_*.json" -o -name "${username}_*.meta" | wc -l | tr -d ' ')
    if [[ $count -eq 0 ]]; then
      echo "No cache entries found for user: $username"
    else
      rm -f "$CACHE_DIR/${username}_"*.json "$CACHE_DIR/${username}_"*.meta
      echo "Cleared cache for user: $username"
    fi
  fi
}

cache_info() {
  local cache_key="$1"
  local meta_file="$CACHE_DIR/${cache_key}.meta"
  local json_file="$CACHE_DIR/${cache_key}.json"

  if [[ ! -f "$meta_file" ]]; then
    echo "Cache entry not found: $cache_key"
    exit 1
  fi

  local cache_time=$(cat "$meta_file")
  local current_time=$(date +%s)
  local age_hours=$(( (current_time - cache_time) / 3600 ))

  if date -r "$cache_time" +"%Y-%m-%d %H:%M:%S" &>/dev/null 2>&1; then
    # macOS
    local cached_at=$(date -r "$cache_time" +"%Y-%m-%d %H:%M:%S")
  else
    # Linux
    local cached_at=$(date -d "@$cache_time" +"%Y-%m-%d %H:%M:%S")
  fi

  local size=$(du -h "$json_file" | cut -f1)

  echo "Cache entry: $cache_key"
  echo "  Cached at: $cached_at"
  echo "  Age: ${age_hours}h"
  echo "  Size: $size"
  echo "  Path: $json_file"
}

# Main
if [[ $# -lt 1 ]]; then
  usage
fi

COMMAND="$1"
shift

case "$COMMAND" in
  list)
    list_cache
    ;;
  clear)
    clear_cache "${1:-}"
    ;;
  info)
    if [[ $# -lt 1 ]]; then
      echo "Error: cache_key required"
      usage
    fi
    cache_info "$1"
    ;;
  *)
    echo "Unknown command: $COMMAND"
    usage
    ;;
esac
