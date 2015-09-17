#!/usr/bin/env bash

mktemp() {
  \mktemp 2>/dev/null || \mktemp -t tmp
}

ask() {
  local i
  select i in Yes No; do
    if [ -n "$i" ]; then
      if [ "$i" = "Yes" ]; then
        return 0
      else
        return 1
      fi
    fi
  done
}

error() {
  echo "$1" 1>&2
  exit 1
}

require_one_or_more() {
  if [ -z "$2" ] || [[ "$2" =~ ^-.* ]]; then
      error "'$1' requires one argument"
  fi
}

check_filter_command() {
  local readonly cmd=$(git config --get ignore.filter 2> /dev/null)
  [ -z "${cmd:-}" ] && {
    local msg msg2
    msg="The filter command is not set."
    msg2="Please set by \`git config --add ignore.filter [peco|fzf|...]\`"
    error "${msg}\n${msg2}
  }

  if type ${cmd} >/dev/null 2>&1; then
    echo "${cmd}"
  else
    local msg msg2
    msg="The filter command '${cmd}' not found."
    msg2="Please set correct one by \`git config --add ignore.filter [peco|fzf|...]\`"
    error "${msg}\n${msg2}
  fi
}

gitignore_api_call() {
  curl -L -s "https://www.gitignore.io/api/$1"|tr "," "\n"
}

fetch_gitignore_types() {
  gitignore_api_call "list"
}

fetch_gitignore() {
  local readonly cmd=$(check_filter_command)
  local langs

  langs=$(fetch_gitignore_types|tr "[:space:]" "\n"|awk 'NR>3{print $0;fflush()}'|"${cmd}")

  while $(echo 'Add another language?'; ask); do
    langs="${langs},$(fetch_gitignore_types|tr "[:space:]" "\n"|awk 'NR>3{print $0;fflush()}'|"${cmd}")"
  done

  gitignore_api_call "${langs}"
}

get_root() {
  local root_dir=$(git rev-parse --git-dir)

  if [ "${root_dir%/*}" = "${root_dir}" ]; then
    root_dir=$(pwd)
  else
    root_dir="${root_dir%/*}"
  fi

  echo $root_dir
}

create() {
  fetch_gitignore > "$(get_root)/.gitignore"
}

append() {
  fetch_gitignore >> "$(get_root)/.gitignore"
}

add() {
  local arg
  for arg in "$@"; do
    echo "$arg" >> "$(get_root)/.gitignore"
  done
}

remove() {
  local arg regex=""
  for arg in "$@"; do
    regex="${regex} -e s/^$arg\$//"
  done

  local temp_file=$(mktemp)
  trap "rm -f ${temp_file}" 1 2 3 15

  cat "$(get_root)/.gitignore"|sed $regex > "${temp_file}"
  cat "${temp_file}" > "$(get_root)/.gitignore"
}

list() {
  cat "$(get_root)/.gitignore"|grep -v -e "^#.*" -e "^$"
}

has() {
  local ignored specified="$1" flg
  while read ignored; do
    [ "${specified}" = "${ignored}" ] && echo "${specified} found." && flg="found" && break
  done < <(cat "$(get_root)/.gitignore"|grep -v -e "#.*" -e "^$")

  [ "${flg}" = "found" ]
}

## opt-parse
EXECUTION_COMMAND=

case "$1" in
    '-c', '--create' )
        EXECUTION_COMMAND="create"
        ;;
    '--append' )
        EXECUTION_COMMAND="append"
        ;;
    '-a', '--add' ) # add ignore
        EXECUTION_COMMAND="add"
        require_one_or_more "$2"
        ;;
    '-r', '--remove' ) # remove ignore
        EXECUTION_COMMAND="remove"
        require_one_or_more "$2"
        ;;
    '--has' ) # has specified
        EXECUTION_COMMAND="has"
        ;;
    '-l', '--list' ) # list ignores
        EXECUTION_COMMAND="list"
        ;;
    -*) # unregistered options
        error "Unknown option '$1'"
        ;;
    *) # arguments which is not option
        error "Unknown arguments '$1'"
        ;;
esac

shift 1

eval "${EXECUTION_COMMAND} $@"