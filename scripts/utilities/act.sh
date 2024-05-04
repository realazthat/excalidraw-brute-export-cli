#!/bin/bash
# https://gist.github.com/mohanpedala/1e2ff5661761d3abd0385e8223e16425
set -e -x -v -u -o pipefail

SCRIPT_DIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")
source "${SCRIPT_DIR}/common.sh"

CACHE_SERVER_PATH="${PWD}/.cache/act/cache-server-path"
ACTION_CACHE_PATH="${PWD}/.cache/act/action-cache"
ACT_PROJECT_PATH="${PWD}/.cache/act/project-clone-path"
mkdir -p "${CACHE_SERVER_PATH}"
mkdir -p "${ACTION_CACHE_PATH}"
mkdir -p "${ACT_PROJECT_PATH}"


chmod -R 777 "${ACT_PROJECT_PATH}" || true
rm -Rf "${ACT_PROJECT_PATH}" || true
mkdir -p "${ACT_PROJECT_PATH}"

git checkout-index --all --prefix="${ACT_PROJECT_PATH}/"
# Set .act-project-path to read-only
chmod -R 555 "${ACT_PROJECT_PATH}"
cd "${ACT_PROJECT_PATH}"

# Use --bind to keep the directory persistent, useful if you need to check the
# contents of the directory after the run for why it failed. However, if you
# do use --bind, you will need to manually clean up the directory after the run,
# because it uses root to create the directory and files.
go run github.com/nektos/act@988556065a83743f17de54adf6c3b7f3cac28e78 \
  push \
  --use-new-action-cache \
  --cache-server-path "${CACHE_SERVER_PATH}" \
  --action-cache-path "${ACTION_CACHE_PATH}" \
  --job build-and-test
