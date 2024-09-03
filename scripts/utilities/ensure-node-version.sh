#!/bin/bash
# https://gist.github.com/mohanpedala/1e2ff5661761d3abd0385e8223e16425
set -e -x -v -u -o pipefail

SCRIPT_DIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")
source "${SCRIPT_DIR}/common.sh"

NODE_VERSION_PATH=${NODE_VERSION_PATH:-""}

if [[ -z "${NODE_VERSION_PATH}" ]]; then
  echo -e "${RED}NODE_VERSION_PATH is not set${NC}"
  [[ $0 == "${BASH_SOURCE[0]}" ]] && EXIT="exit" || EXIT="return"
  ${EXIT} 1
fi

EXPECTED_NODE_VERSION=$(cat "${NODE_VERSION_PATH}")
# Get ONLY the version number, not the whole string
NODE_VERSION=$(node --version)


if [[ "${NODE_VERSION}" != "${EXPECTED_NODE_VERSION}" ]]; then
  echo -e "${RED}Expected node version ${EXPECTED_NODE_VERSION}, got ${NODE_VERSION}${NC}"
  [[ $0 == "${BASH_SOURCE[0]}" ]] && EXIT="exit" || EXIT="return"
  ${EXIT} 1
fi
