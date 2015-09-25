#!/usr/bin/env bash

usage() {
cat <<HERE
usage: git branch-extras [-m|--mergable|mergable] <branch>
          # ask whether <branch> can be merged into current branch or not.
   or: git branch-extras [-l|--list] [--all|--remote|--local]
          # show branches which are filtered.
   or: git branch-extras [-c|--current|current]
          # show current branch name.
   or: git branch-extras [-e|--exists|exists] <branch>
          # ask whether <branch> exists or not.
   or: git branch-extras [-h|--help]
          # show me :)
HERE
}

mktemp() {
  command mktemp 2>/dev/null || command mktemp -t tmp
}

error() {
  local msg
  for msg in "$@"; do
    echo "$msg" 1>&2
  done

  exit 1
}

require_one_or_more() {
  if [ -z "$2" ] || [[ "$2" =~ ^-.* ]]; then
      error "'$1' requires one argument"
  fi
}

list() {
  list::all
}

list::local() {
  git branch --list
}

list::remote() {
  git branch --list -r # for listing mode, just in case.
}

list::all() {
  git branch --list -a # for listing mode, just in case.
}

current() {
  git rev-parse --abbrev-ref HEAD
}

exists() {
  local name="$1"

  [ "_${name}" = "_$(git branch --list "${name}"|sed -e 's/\*//g' -e 's/ //g')" ]
}

mergable() {
  local readonly source_branch="$1"
  local readonly current_branch=$(current)
  local readonly temp_file=$(mktemp)

  trap "rm -f ${temp_file}" 1 2 3 15

  git format-patch "${current_branch}..${source_branch}" --stdout > "${temp_file}"
  [ -s "${temp_file}" ] && git apply "${temp_file}" --check
}

## opt-parse
EXECUTION_COMMAND=
EXECUTION_COMMAND_SUFFIX=

case "${1:--l}" in
  '-c' | '--current' | 'current' )
    EXECUTION_COMMAND="current"
    ;;
  '-m' | '--mergable' | 'mergable' )
    EXECUTION_COMMAND="mergable"
    ;;
  '-e' | '--exists' | 'exists' ) # add ignore
    EXECUTION_COMMAND="exists"
    require_one_or_more "$1" "$2"
    ;;
  '-l' | '--list' ) # list ignores
    EXECUTION_COMMAND="list"
    ;;
  '--all' ) # list ignores
    EXECUTION_COMMAND_SUFFIX="::all"
    ;;
  '--local' ) # list ignores
    EXECUTION_COMMAND_SUFFIX="::local"
    ;;
  '--remote' ) # list ignores
    EXECUTION_COMMAND_SUFFIX="::remote"
    ;;
  '-h' | '--help' ) # list ignores
    EXECUTION_COMMAND="usage"
    ;;
  -*) # unregistered options
    error "Unknown option '$1'"
    ;;
  *) # arguments which is not option
    error "Unknown arguments '$1'"
    ;;
esac

shift 1

eval "${EXECUTION_COMMAND:-usage}${EXECUTION_COMMAND_SUFFIX:-} $@"