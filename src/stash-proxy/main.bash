#!/usr/bin/env bash

set -Eeuo pipefail

exec::git::stash() {
  exec command git stash "$@"
}

setup_colors() {
  if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
    NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m'
  fi
}

msg() {
  echo >&2 -e "${1-}"
}

info() {
  msg "${GREEN}$1${NOFORMAT}"
}

warn() {
  msg "${YELLOW}$1${NOFORMAT}"
}

err() {
  msg "${RED}$1${NOFORMAT}"
}

die() {
  err "${1-}"
  exit "${2-1}"
}

NOFORMAT='' RED='' GREEN='' YELLOW=''

first_argument="${1-}"

if [[ "$first_argument" = "save" ]]; then
  die "$0 $first_argument is deprecated so the execution is prohibided."
fi

if [[ "$first_argument" =~ -.* ]]; then
  subcommand="push"
elif (("$# > 0")); then
  subcommand="$first_argument"
  shift 1
else
  subcommand="push"
fi

if [[ ! "$subcommand" = "push" ]]; then
  exec::git::stash "$subcommand" "$@"
fi

_args=()
message=''

while :; do
  if (("$# == 0")); then
    break
  fi

  case "${1-}" in
  -m | --message)
    message="${2-}"
    shift
    ;;
  *)
    _args+=("${1-}")
    ;;
  esac

  shift
done

if [[ -z "$message" ]]; then
  die "-m <a reason why you stach changes> is required to avoid confusion."
fi

branch_name="$(git rev-parse --abbrev-ref HEAD)"
head_log="$(git log --pretty="format:%h %s" -1)"

# git stash's message can't handle branch names that contain '/' properly
IFS=" " set -- "-m" "$branch_name ($(git rev-parse --short HEAD)): because of $message. ref: $head_log" "${_args[@]}"

exec::git::stash push "$@"