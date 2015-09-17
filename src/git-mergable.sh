#!/usr/bin/env bash

mktemp() {
  \mktemp 2>/dev/null || \mktemp -t tmp
}

main() {
  local readonly source_branch="$1"
  local readonly current_branch=$(git rev-parse --abbrev-ref HEAD)
  local readonly temp_file=$(mktemp)

  trap "rm -f ${temp_file}" 1 2 3 15

  git format-patch "${current_branch}..${source_branch}" --stdout > "${temp_file}"
  [ -s "${temp_file}" ] && git apply "${temp_file}" --check
}

main "$@"