#!/usr/bin/env bash
# Print a GitHub user's starred repositories as CSV, newest star first.
# Usage: fetch-stars.sh <github-handle>
set -e -u -o pipefail

main() {
  if [[ "${DEBUG:-FALSE}" == "TRUE" ]]; then
    set -x
  fi

  local -r github_handle="${1:?usage: fetch-stars.sh <github-handle>}"

  echo '"repo","starred_at","url","description"'

  # The star+json media type adds the `starred_at` field to each item.
  # --slurp collects every page into one array so the sort is global; jq given
  # via --jq would run once per page and only sort within each page.
  # per_page=100 is the API maximum and keeps the request count low.
  gh api "/users/${github_handle}/starred?per_page=100" \
    --paginate --slurp \
    --header 'Accept: application/vnd.github.v3.star+json' \
    | jq -r 'add
             | sort_by(.starred_at, .repo.full_name)
             | reverse
             | .[]
             | [.repo.full_name, .starred_at, .repo.html_url, .repo.description]
             | @csv'
}

main "$@"
