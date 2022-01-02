#!/usr/bin/env bash

usage() {
cat <<HERE
usage: git ahead
          # dispatch to `git ahead -l`
   or: git ahead <-f|--first>
          # first commit hash
   or: git ahead <-l|--list>
          # commit hash list
   or: git ahead <-c|--count>
          # ahead of tracked by xxx commits
   or: git ahead [-h|--help]
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

current() {
  git rev-parse --abbrev-ref HEAD
}

tracked() {
  git rev-parse --abbrev-ref $(current)@{upstream}
}

ahead() {
  list
}

first() {
  list|tail -1|sed 's/^<//'
}

list() {
  git rev-list --left-right $(current)...$(tracked)|sed 's/^<//'
}

count() {
  git rev-list --left-right $(current)...$(tracked) --count
}

## opt-parse
EXECUTION_COMMAND=

case "${1:--l}" in
  '-l' | '--list' | 'list' )
    EXECUTION_COMMAND="list"
    ;;
  '-c' | '--count' | 'count' )
    EXECUTION_COMMAND="count"
    ;;
  '-f' | '--first' | 'first' ) # add ignore
    EXECUTION_COMMAND="first"
    ;;
  '-h' | '--help' | 'usage' ) # list ignores
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

eval "${EXECUTION_COMMAND:-usage} $@"