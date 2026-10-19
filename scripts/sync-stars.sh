#!/usr/bin/env bash
# Star, on the account that owns GH_TOKEN, every repo the source account has
# starred but the token owner has not. Add-only: never unstars anything.
#
# Usage: sync-stars.sh <source-github-handle>
# Env:
#   GH_TOKEN           token of the target account (needs Starring: write)
#   DRY_RUN=TRUE       print the repos that would be starred, make no changes
#   MAX_STARS_PER_RUN  cap on stars per run, leftovers go to the next run (300)
#   DEBUG=TRUE         trace commands
set -e -u -o pipefail

# Same byte-wise collation for sort and comm on every platform.
export LC_ALL=C

# A run of failures means a token or rate-limit problem, not bad repos.
readonly MAX_CONSECUTIVE_FAILURES=5

# List starred repos as lowercase "owner/repo", one per line, sorted.
# Lowercased because the API is case-insensitive for owner/repo, while a
# renamed owner can come back with different casing on each side.
list_stars() {
  local -r endpoint="$1"

  gh api "${endpoint}?per_page=100" --paginate --jq '.[].full_name' \
    | tr '[:upper:]' '[:lower:]' \
    | sort -u
}

# Returns 0 when starred, 1 when the repo was skipped (private, deleted,
# blocked). Exits the script on 401 (bad token) and 429 (rate limited), since
# every later call would fail too.
star_repo() {
  local -r repo="$1" err_file="$2"

  if gh api -X PUT "/user/starred/${repo}" --silent 2>"$err_file"; then
    return 0
  fi

  if grep -qE 'HTTP (401|429)' "$err_file"; then
    cat "$err_file" >&2
    exit 1
  fi

  echo "warn: skipped ${repo}: $(head -n 1 "$err_file")" >&2
  return 1
}

main() {
  if [[ "${DEBUG:-FALSE}" == "TRUE" ]]; then
    set -x
  fi

  local -r source_handle="${1:?usage: sync-stars.sh <source-github-handle>}"
  local -r max_stars="${MAX_STARS_PER_RUN:-300}"
  local -r dry_run="${DRY_RUN:-FALSE}"

  if [[ ! "$max_stars" =~ ^[0-9]+$ ]]; then
    echo "MAX_STARS_PER_RUN must be a non-negative integer, got '${max_stars}'" >&2
    exit 2
  fi

  local work_dir
  work_dir="$(mktemp -d "${TMPDIR:-/tmp}/sync-stars.XXXXXX")"
  # shellcheck disable=SC2064 # expand now: work_dir is local to main
  trap "rm -rf '${work_dir}'" EXIT

  list_stars "/users/${source_handle}/starred" >"${work_dir}/source"
  list_stars "/user/starred" >"${work_dir}/target"
  comm -23 "${work_dir}/source" "${work_dir}/target" >"${work_dir}/missing"

  local -r missing_count="$(wc -l <"${work_dir}/missing" | tr -d ' ')"
  echo "source=$(wc -l <"${work_dir}/source" | tr -d ' ') missing=${missing_count} cap=${max_stars} dry_run=${dry_run}"

  local starred=0 skipped=0 consecutive_failures=0 repo
  while IFS= read -r repo; do
    if [[ "$dry_run" == "TRUE" ]]; then
      echo "would star ${repo}"
      continue
    fi

    if star_repo "$repo" "${work_dir}/err"; then
      echo "starred ${repo}"
      starred=$((starred + 1))
      consecutive_failures=0
    else
      skipped=$((skipped + 1))
      consecutive_failures=$((consecutive_failures + 1))
      # e.g. a token without Starring write access gets 403 on every repo.
      if ((consecutive_failures >= MAX_CONSECUTIVE_FAILURES)); then
        echo "error: ${consecutive_failures} failures in a row, check token permissions or rate limits" >&2
        exit 1
      fi
    fi
    # Starring counts as content creation; spacing calls keeps the backfill
    # under GitHub's secondary rate limits.
    sleep 1
  done < <(head -n "$max_stars" "${work_dir}/missing")

  echo "missing=${missing_count} starred=${starred} skipped=${skipped}"
}

main "$@"
