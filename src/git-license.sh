#!/usr/bin/env bash

# ---- https://github.com/dominictarr/JSON.sh/blob/ed3f9dd285ebd4183934adb54ea5a2fda6b25a98/JSON.sh

throw () {
  echo "$*" >&2
  exit 1
}

BRIEF=0
LEAFONLY=0
PRUNE=0
NORMALIZE_SOLIDUS=0

parse_options() {
  set -- "$@"
  local ARGN=$#
  while [ "$ARGN" -ne 0 ]
  do
    case $1 in
      -b) BRIEF=1
          LEAFONLY=1
          PRUNE=1
      ;;
      -l) LEAFONLY=1
      ;;
      -p) PRUNE=1
      ;;
      -s) NORMALIZE_SOLIDUS=1
      ;;
      ?*) echo "ERROR: Unknown option."
          exit 0
      ;;
    esac
    shift 1
    ARGN=$((ARGN-1))
  done
}

awk_egrep () {
  local pattern_string=$1

  gawk '{
    while ($0) {
      start=match($0, pattern);
      token=substr($0, start, RLENGTH);
      print token;
      $0=substr($0, start+RLENGTH);
    }
  }' pattern="$pattern_string"
}

tokenize () {
  local GREP
  local ESCAPE
  local CHAR

  if echo "test string" | egrep -ao --color=never "test" &>/dev/null
  then
    GREP='egrep -ao --color=never'
  else
    GREP='egrep -ao'
  fi

  if echo "test string" | egrep -o "test" &>/dev/null
  then
    ESCAPE='(\\[^u[:cntrl:]]|\\u[0-9a-fA-F]{4})'
    CHAR='[^[:cntrl:]"\\]'
  else
    GREP=awk_egrep
    ESCAPE='(\\\\[^u[:cntrl:]]|\\u[0-9a-fA-F]{4})'
    CHAR='[^[:cntrl:]"\\\\]'
  fi

  local STRING="\"$CHAR*($ESCAPE$CHAR*)*\""
  local NUMBER='-?(0|[1-9][0-9]*)([.][0-9]*)?([eE][+-]?[0-9]*)?'
  local KEYWORD='null|false|true'
  local SPACE='[[:space:]]+'

  $GREP "$STRING|$NUMBER|$KEYWORD|$SPACE|." | egrep -v "^$SPACE$"
}

parse_array () {
  local index=0
  local ary=''
  read -r token
  case "$token" in
    ']') ;;
    *)
      while :
      do
        parse_value "$1" "$index"
        index=$((index+1))
        ary="$ary""$value"
        read -r token
        case "$token" in
          ']') break ;;
          ',') ary="$ary," ;;
          *) throw "EXPECTED , or ] GOT ${token:-EOF}" ;;
        esac
        read -r token
      done
      ;;
  esac
  [ "$BRIEF" -eq 0 ] && value=$(printf '[%s]' "$ary") || value=
  :
}

parse_object () {
  local key
  local obj=''
  read -r token
  case "$token" in
    '}') ;;
    *)
      while :
      do
        case "$token" in
          '"'*'"') key=$token ;;
          *) throw "EXPECTED string GOT ${token:-EOF}" ;;
        esac
        read -r token
        case "$token" in
          ':') ;;
          *) throw "EXPECTED : GOT ${token:-EOF}" ;;
        esac
        read -r token
        parse_value "$1" "$key"
        obj="$obj$key:$value"
        read -r token
        case "$token" in
          '}') break ;;
          ',') obj="$obj," ;;
          *) throw "EXPECTED , or } GOT ${token:-EOF}" ;;
        esac
        read -r token
      done
    ;;
  esac
  [ "$BRIEF" -eq 0 ] && value=$(printf '{%s}' "$obj") || value=
  :
}

parse_value () {
  local jpath="${1:+$1,}$2" isleaf=0 isempty=0 print=0
  case "$token" in
    '{') parse_object "$jpath" ;;
    '[') parse_array  "$jpath" ;;
    # At this point, the only valid single-character tokens are digits.
    ''|[!0-9]) throw "EXPECTED value GOT ${token:-EOF}" ;;
    *) value=$token
       # if asked, replace solidus ("\/") in json strings with normalized value: "/"
       [ "$NORMALIZE_SOLIDUS" -eq 1 ] && value=${value//\\\//\/}
       isleaf=1
       [ "$value" = '""' ] && isempty=1
       ;;
  esac
  [ "$value" = '' ] && return
  [ "$LEAFONLY" -eq 0 ] && [ "$PRUNE" -eq 0 ] && print=1
  [ "$LEAFONLY" -eq 1 ] && [ "$isleaf" -eq 1 ] && [ $PRUNE -eq 0 ] && print=1
  [ "$LEAFONLY" -eq 0 ] && [ "$PRUNE" -eq 1 ] && [ "$isempty" -eq 0 ] && print=1
  [ "$LEAFONLY" -eq 1 ] && [ "$isleaf" -eq 1 ] && \
    [ $PRUNE -eq 1 ] && [ $isempty -eq 0 ] && print=1
  [ "$print" -eq 1 ] && printf "[%s]\t%s\n" "$jpath" "$value"
  :
}

parse () {
  read -r token
  parse_value
  read -r token
  case "$token" in
    '') ;;
    *) throw "EXPECTED EOF GOT $token" ;;
  esac
}

# ---- JSON.sh END

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

get_filter_command() {
  git config --get mine.filter 2> /dev/null
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

gitlicense_api_call() {
  curl -L -s -H "Accept: application/vnd.github.drax-preview+json" -X GET "https://api.github.com/licenses${1:-}"
}

#curl -H "Accept: application/vnd.github.drax-preview+json" -X GET https://api.github.com/licenses | jq ".[].url" | peco --prompt "Select license: > " | sed -e "s/\"//g" | xargs -J % curl -H "Accept: application/vnd.github.drax-preview+json" -X GET % | jq ".body" > LICENSE; eval echo $(cat LICENSE) > LICENSE

fetch_license() {
  check_filter_command

  local readonly cmd=$(get_filter_command)
  local readonly temp_file=$(mktemp)

  gitlicense_api_call|tokenize|parse > "${temp_file}"

  local readonly key=$(cat "${temp_file}"|grep '\[[0-9]*,"key"\]'|awk '$0=$2'|sed -e "s/\"//g"|${cmd})
  [ $? -eq 0 ] && gitlicense_api_call "/${key}"
}

fetch_license