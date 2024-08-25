#!/bin/bash
# https://gist.github.com/mohanpedala/1e2ff5661761d3abd0385e8223e16425
set -e -x -v -u -o pipefail

SCRIPT_DIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")
source "${SCRIPT_DIR}/utilities/common.sh"

IDEAL_EXCALIDRAW_TAG=$(cat .github/.excalidraw-tag)
IDEAL_NODE_VERSION="v20.12.1"
WANTED_NODE_VERSION=$(cat .nvmrc)

export PYTHON_VERSION_PATH="${PWD}/scripts/.python-version"
export TOML="${PWD}/scripts/pyproject.toml"
export EXCALIDRAW_TAG=${EXCALIDRAW_TAG-"${IDEAL_EXCALIDRAW_TAG}"}

# This variable will be 1 when we are the ideal version in the GH action matrix.
IDEAL="0"

if [[ "${WANTED_NODE_VERSION}" == "${IDEAL_NODE_VERSION}" && "${EXCALIDRAW_TAG}" == "${IDEAL_EXCALIDRAW_TAG}" ]]; then
  IDEAL="1"
fi

if [[ -z "${GITHUB_ACTIONS:-}" ]]; then
  if [[ "${IDEAL}" != "1" ]]; then
    echo -e "${RED}Somehow we are not 'ideal' outside of GH Action workflow. IDEAL is meant to be 1 when we are running the GH Action matrix configuration that matches the configuration outside of the GH Action workflow. But we are not in the GH Action workflow, yet it is not 1!${NC}"
    exit 1
  fi
fi

ACTUAL_NODE_VERSION=$(node --version)
if [[ "${ACTUAL_NODE_VERSION}" != "${WANTED_NODE_VERSION}" ]]; then
  echo -e "${RED}Node version is not as expected. Wanted: ${WANTED_NODE_VERSION}, Actual: ${ACTUAL_NODE_VERSION}${NC}"
  exit 1
fi

# Check that no changes occurred to files through the workflow.
if [[ "${IDEAL}" == "1" ]]; then
  STEP=pre bash scripts/utilities/changeguard.sh
fi

npm install


EXTRA=dev bash scripts/utilities/pin-extra-reqs.sh
npm run genversion
if [[ -z "${EXCALIDRAW_BRUTE_EXPORT_CLI_URL:-}" ]]; then
  source scripts/run-excalidraw.sh
fi

bash scripts/generate.sh
bash scripts/run-ood-smoke-test.sh
if [[ -z "${GITHUB_ACTIONS:-}" ]]; then
  bash scripts/utilities/act.sh
  bash scripts/precommit.sh
fi

# Check that no changes occurred to files throughout pre.sh to tracked files. If
# changes occurred, they should be staged and pre.sh should be run again.
if [[ "${IDEAL}" == "1" ]]; then
  STEP=post bash scripts/utilities/changeguard.sh
fi

echo -e "${GREEN}Success: pre.sh${NC}"
