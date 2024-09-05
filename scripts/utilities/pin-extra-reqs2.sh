#!/bin/bash
# https://gist.github.com/mohanpedala/1e2ff5661761d3abd0385e8223e16425
set -e -x -v -u -o pipefail

SCRIPT_DIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")
source "${SCRIPT_DIR}/common.sh"

TOML="${TOML:-}"
if [[ -z "${TOML}" ]]; then
  echo -e "${RED}TOML must be set${NC}"
  [[ $(realpath "$0"||true) == $(realpath "${BASH_SOURCE[0]}"||true) ]] && EXIT="exit" || EXIT="return"
  ${EXIT} 1
fi

VENV_PATH="${PWD}/.cache/scripts/.venv" source "${PROJ_PATH}/scripts/utilities/ensure-venv.sh"
TOML="${TOML}" EXTRA=dev \
  DEV_VENV_PATH="${PWD}/.cache/scripts/.venv" \
  TARGET_VENV_PATH="${PWD}/.cache/scripts/.venv" \
  bash "${PROJ_PATH}/scripts/utilities/ensure-reqs.sh"



EXTRAS=${EXTRAS:-}
PIN=${PIN:-}

if [[ -z "${PIN}" ]]; then
  echo -e "${RED}PIN must be set${NC}"
  [[ $(realpath "$0"||true) == $(realpath "${BASH_SOURCE[0]}"||true) ]] && EXIT="exit" || EXIT="return"
  ${EXIT} 1
fi

################################################################################
PINNED_REQ_FILE="${PWD}/.cache/scripts/${PIN}-requirements.pinned.txt"
PINNED_REQ_TOUCH_FILE="${PWD}/.cache/scripts/${PIN}-requirements.pinned.touch"
TOML_UPDATE_TOUCH_FILE="${PWD}/.cache/scripts/${PIN}-pyproject.toml.pinned.touch"
################################################################################
# Extract the requirements from the pyproject.toml file into a requirements
# file.
#
# Check if we already did this.
export FILE="${TOML}"
export TOUCH_FILE="${PINNED_REQ_TOUCH_FILE}"

EXTRA_FLAGS=$(echo "${EXTRAS}" | python -c 'import sys; import shlex; extras=sys.stdin.read().split(","); print("\n".join([f" --extra {extra}" for extra in extras]))')
# Add --extra ${PIN} to the EXTRA_FLAGS. This way previous pins are sticky. To
# change them, they have to be changed explicitly. Otherwise there will be a
# conflict.
EXTRA_FLAGS="${EXTRA_FLAGS} --extra ${PIN}"

if bash "${PROJ_PATH}/scripts/utilities/is_not_dirty.sh"; then
  echo -e "${GREEN}Requirements ${PINNED_REQ_FILE} are up to date${NC}"
  [[ $(realpath "$0"||true) == $(realpath "${BASH_SOURCE[0]}"||true) ]] && EXIT="exit" || EXIT="return"
else
  echo -e "${BLUE}Requirements ${PINNED_REQ_FILE} need updating${NC}"
  echo -e "${BLUE}Generating ${PINNED_REQ_FILE}${NC}"

  PINNED_REQ_DIR=$(dirname "${PINNED_REQ_FILE}")
  mkdir -p "${PINNED_REQ_DIR}"
  python -m piptools compile --generate-hashes \
    ${EXTRA_FLAGS} \
    "${TOML}" \
    -o "${PINNED_REQ_FILE}"
  echo -e "${GREEN}Generated ${PINNED_REQ_FILE}${NC}"

  export FILE="${TOML}"
  export TOUCH_FILE="${PINNED_REQ_TOUCH_FILE}"
  bash "${PROJ_PATH}/scripts/utilities/mark_dirty.sh"
fi
################################################################################
# Pin extra requirements in pyproject.toml file.

export FILE="${TOML}"
export TOUCH_FILE="${TOML_UPDATE_TOUCH_FILE}"
if bash "${PROJ_PATH}/scripts/utilities/is_not_dirty.sh"; then
  echo -e "${GREEN}pyproject.toml is up to date${NC}"
else
  echo -e "${BLUE}Altering pyproject.toml${NC}"
  python "${PROJ_PATH}/scripts/utilities/pin-extra-reqs2.py" \
    --reqs "${PINNED_REQ_FILE}" \
    ${EXTRA_FLAGS} \
    --pin "${PIN}" \
    --toml "${TOML}"
  ################################################################################
  # Format the pyproject.toml file
  if toml-sort "${TOML}" --check; then
    echo -e "${GREEN}pyproject.toml needs no formatting${NC}"
  else
    echo -e "${BLUE}pyproject.toml needs formatting${NC}"
    toml-sort --in-place "${TOML}"
    echo -e "${GREEN}pyproject.toml formatted${NC}"
  fi
  if toml-sort "${TOML}" --check; then
    echo -e "${GREEN}pyproject.toml is formatted${NC}"
  else
    echo -e "${RED}pyproject.toml is not formatted${NC}"
    [[ $(realpath "$0"||true) == $(realpath "${BASH_SOURCE[0]}"||true) ]] && EXIT="exit" || EXIT="return"
    ${EXIT} 1
  fi
  ################################################################################
  export FILE="${TOML}"
  export TOUCH_FILE="${TOML_UPDATE_TOUCH_FILE}"
  bash "${PROJ_PATH}/scripts/utilities/mark_dirty.sh"
  echo -e "${GREEN}Pinned ${EXTRAS} => ${PIN} requirements${NC}"
fi
