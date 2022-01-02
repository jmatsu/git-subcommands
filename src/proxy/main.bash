#!/usr/bin/env bash

set -Eeuo pipefail

delegate() {
  if ! type command > /dev/null 2>&1; then
    echo 'command is required to use git-proxy' 1>&2
    exit 1
  elif let "$# > 0"; then
    # git git git git... :)
    while [[ "$1" == "git" ]]; do
      shift 1
    done

    if [[ "$1" = "stash" ]]; then
      shift 1
      IFS=" " set -- "stash-proxy.bash" "$@"
    fi

    exec command git "$@"
  else
    exec command git
  fi
}

delegate "$@"
