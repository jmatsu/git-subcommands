#!/usr/bin/env bash

mktemp() {
  command mktemp 2>/dev/null || command mktemp -t tmp
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

usage() {
cat <<HERE
usage: git ignore                          # list all aliases
   or: git ignore [-c|--create]            # create .gitignore by fetching from gitignore.io
   or: git ignore [--append]               # append fetched ignores into existing .gitignore
   or: git ignore [-a|--add] <file...>     # add file... to existing .gitignore and remove caches from git fs.
   or: git ignore [-r|--remove] <file...>  # remove file...
   or: git ignore [--has] <file>           # ask whether the file exists or not
   or: git ignore [-l|--list]              # show all ignores
   or: git ignore [-h|--help]              # show me :)
HERE
}

check_filter_command() {
  local readonly cmd=$(get_filter_command)
  [ -z "${cmd:-}" ] && {
    local msg msg2
    msg="The filter command is not set."
    msg2="Please set by \`git config --add mine.filter [peco|fzf|...]\`"
    error "${msg}" "${msg2}"
  }

  if type ${cmd} >/dev/null 2>&1; then
    :
  else
    local msg msg2
    msg="The filter command '${cmd}' not found."
    msg2="Please set correct one by \`git config --add mine.filter [peco|fzf|...]\`"
    error "${msg}" "${msg2}"
  fi
}

get_filter_command() {
  git config --get mine.filter 2> /dev/null
}

gitignore_api_call() {
  curl -L -s "https://www.gitignore.io/api/$1"
}

gitignore_api_list_call() {
  curl -L -s "https://www.gitignore.io/api/$1"|tr "," "\n"
}

fetch_gitignore_types() {
  gitignore_api_list_call "list"
}

select_langs() {
  check_filter_command

  local readonly cmd=$(get_filter_command)

  SELECTED_LANG=$(fetch_gitignore_types|tr "[:space:]" "\n"|awk 'NR>3{print $0;fflush()}'|"${cmd}")

  echo 'Add another language?'
  while ask; do
    SELECTED_LANG="${SELECTED_LANG},$(fetch_gitignore_types|tr "[:space:]" "\n"|awk 'NR>3{print $0;fflush()}'|"${cmd}")"

    echo 'Add another language?'
  done
}

fetch_gitignore() {
  gitignore_api_call "${SELECTED_LANG}"
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
  select_langs
  fetch_gitignore > "$(get_root)/.gitignore"
}

append() {
  select_langs
  fetch_gitignore >> "$(get_root)/.gitignore"
}

add() {
  local arg
  for arg in "$@"; do
    echo "$arg" >> "$(get_root)/.gitignore"
    git remove --cached "$arg" > /dev/null 2>&1
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

case "${1:--l}" in
  '-c' | '--create' )
    EXECUTION_COMMAND="create"
    ;;
  '--append' )
    EXECUTION_COMMAND="append"
    ;;
  '-a' | '--add' ) # add ignore
    EXECUTION_COMMAND="add"
    require_one_or_more "$1" "$2"
    ;;
  '-r' | '--remove' ) # remove ignore
    EXECUTION_COMMAND="remove"
    require_one_or_more "$1" "$2"
    ;;
  '--has' ) # has specified
    EXECUTION_COMMAND="has"
    ;;
  '-l' | '--list' ) # list ignores
    EXECUTION_COMMAND="list"
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

eval "${EXECUTION_COMMAND:-usage} $@"