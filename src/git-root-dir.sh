#!/usr/bin/env bash

ROOT_DIR=$(git rev-parse --git-dir)

if [ "${ROOT_DIR%/*}" = "${ROOT_DIR}" ]; then
  ROOT_DIR=$(pwd)
else
  ROOT_DIR="${ROOT_DIR%/*}"
fi

echo $ROOT_DIR