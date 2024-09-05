#!/bin/bash
# https://gist.github.com/mohanpedala/1e2ff5661761d3abd0385e8223e16425
set -e -x -v -u -o pipefail

SCRIPT_DIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")
source "${SCRIPT_DIR}/common.sh"

TOML=${TOML:-""}
EXTRAS=${EXTRAS:-""}
PIN=${PIN:-""}
DEV_VENV_PATH=${DEV_VENV_PATH:-}
TARGET_VENV_PATH=${TARGET_VENV_PATH:-}

if [[ $(realpath "$0"||true) == $(realpath "${BASH_SOURCE[0]}"||true) ]]; then
  :
else
  echo -e "${RED}This script should NOT be sourced, execute it like a normal script.${NC}"
  return 1
fi
if [[ -z "${TOML}" ]]; then
  echo -e "${RED}TOML is not set${NC}"
  [[ $(realpath "$0"||true) == $(realpath "${BASH_SOURCE[0]}"||true) ]] && EXIT="exit" || EXIT="return"
  ${EXIT} 1
fi

if [[ -z "${PIN}" ]]; then
  echo -e "${RED}PIN is not set${NC}"
  [[ $(realpath "$0"||true) == $(realpath "${BASH_SOURCE[0]}"||true) ]] && EXIT="exit" || EXIT="return"
  ${EXIT} 1
fi
if [[ -z "${DEV_VENV_PATH}" ]]; then
  echo -e "${RED}DEV_VENV_PATH is not set${NC}"
  [[ $(realpath "$0"||true) == $(realpath "${BASH_SOURCE[0]}"||true) ]] && EXIT="exit" || EXIT="return"
  ${EXIT} 1
fi
if [[ -z "${TARGET_VENV_PATH}" ]]; then
  echo -e "${RED}TARGET_VENV_PATH is not set${NC}"
  [[ $(realpath "$0"||true) == $(realpath "${BASH_SOURCE[0]}"||true) ]] && EXIT="exit" || EXIT="return"
  ${EXIT} 1
fi
################################################################################
# Get the target python executable, where we want to install all the
# requirements to.
VENV_PATH=${TARGET_VENV_PATH} source "${PROJ_PATH}/scripts/utilities/ensure-venv.sh"
PYTHON_EXECUTABLE=$(command -v python)
################################################################################
# Activate the dev venv to install pip-tools to etc.
VENV_PATH=${DEV_VENV_PATH} source "${PROJ_PATH}/scripts/utilities/ensure-venv.sh"
################################################################################

SYNC_TOUCH_FILE="${PWD}/.cache/scripts/${PIN}-requirements.touch"
OUTPUT_REQUIREMENTS_FILE="${PWD}/.cache/scripts/${PIN}-requirements.txt"

export FILE=${TOML}
export TOUCH_FILE=${SYNC_TOUCH_FILE}
if bash "${PROJ_PATH}/scripts/utilities/is_not_dirty.sh"; then
  echo -e "${GREEN}Syncing is not needed${NC}"
  [[ $(realpath "$0"||true) == $(realpath "${BASH_SOURCE[0]}"||true) ]] && EXIT="exit" || EXIT="return"
  ${EXIT} 0
fi
echo -e "${BLUE}Syncing requirements${NC}"

python -m pip install pip-tools

mkdir -p "$(dirname "${OUTPUT_REQUIREMENTS_FILE}")"


EXTRA_FLAGS=$(echo "${EXTRAS}" | python -c 'import sys; import shlex; extras=sys.stdin.read().split(","); print("\n".join([f" --extra {extra}" for extra in extras]))')
python -m piptools compile \
  ${EXTRA_FLAGS} \
  -o "${OUTPUT_REQUIREMENTS_FILE}" \
  "${TOML}"

python -m piptools sync "${OUTPUT_REQUIREMENTS_FILE}" \
  --python-executable "${PYTHON_EXECUTABLE}"

export FILE=${TOML}
export TOUCH_FILE=${SYNC_TOUCH_FILE}
bash "${PROJ_PATH}/scripts/utilities/mark_dirty.sh"

export FILE=${TOML}
export TOUCH_FILE=${SYNC_TOUCH_FILE}
if bash "${PROJ_PATH}/scripts/utilities/is_not_dirty.sh"; then
  :
else
  echo -e "${RED}Syncing failed${NC}"
  [[ $(realpath "$0"||true) == $(realpath "${BASH_SOURCE[0]}"||true) ]] && EXIT="exit" || EXIT="return"
  ${EXIT} 1
fi

echo -e "${GREEN}Synced requirements for ${EXTRAS}, ${PIN}, using ${OUTPUT_REQUIREMENTS_FILE}${NC}"
