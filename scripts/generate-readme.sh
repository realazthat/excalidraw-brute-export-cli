#!/bin/bash
# https://gist.github.com/mohanpedala/1e2ff5661761d3abd0385e8223e16425
set -e -x -v -u -o pipefail

################################################################################
SCRIPT_DIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")
source "${SCRIPT_DIR}/utilities/common.sh"

################################################################################
EXCALIDRAW_BRUTE_EXPORT_CLI_URL=${EXCALIDRAW_BRUTE_EXPORT_CLI_URL:-}
if [[ -z "${EXCALIDRAW_BRUTE_EXPORT_CLI_URL}" ]]; then
  echo -e "${RED}EXCALIDRAW_BRUTE_EXPORT_CLI_URL is not set${NC}"
  exit 1
fi
################################################################################
PYTHON_VERSION_PATH=${PWD}/scripts/.python-version \
  VENV_PATH=${PWD}/.cache/scripts/.venv \
  source "${PROJ_PATH}/scripts/utilities/ensure-venv.sh"
PYTHON_VERSION_PATH=${PWD}/scripts/.python-version \
  TOML=${PROJ_PATH}/scripts/pyproject.toml EXTRA=dev \
  DEV_VENV_PATH="${PWD}/.cache/scripts/.venv" \
  TARGET_VENV_PATH="${PWD}/.cache/scripts/.venv" \
  bash "${PROJ_PATH}/scripts/utilities/ensure-reqs.sh"
################################################################################
NODE_VERSION_PATH=${PWD}/.nvmrc \
  bash "${PROJ_PATH}/scripts/utilities/ensure-node-version.sh"
################################################################################

bash scripts/format.sh

# FORCE_COLOR and TERM are set, to produce consistent results across different
# systems.
#
# Explanation:
#
# @caporal/core is used for argument parsing.
#
# chalk/chalk, via @caporal/core, uses an internal copy of the supports-color
# library (https://github.com/chalk/supports-color) here:
# <https://github.com/chalk/chalk/blob/main/source/vendor/supports-color/index.js>.
#
# supports-color is terminal-emulator-dependent.
#
# But we want it to produce consistent results for the README output.
#
# To do this, we set the FORCE_COLOR environment variable to 3.
#
# However, this older version of supports-color does not always listen to
# FORCE_COLOR, so we also have to set TERM to 'dumb'.
export FORCE_COLOR=3
export TERM=dumb

# https://www.npmjs.com/package/cli-width, via @caporal/core, detects column
# width, and snipinator's rich_cols isn't cutting it.
export CLI_WIDTH=120
export LINES=40
export COLUMNS=120
python -m snipinator.cli \
  -t "${PROJ_PATH}/.github/README.md.jinja2" \
  -o "${PROJ_PATH}/README.md" \
  --rm --force --create --chmod-ro
################################################################################
LAST_VERSION=$(node -p "require('./package.json').version")
python -m mdremotifier.cli \
  -i "${PROJ_PATH}/README.md" \
  --url-prefix "https://github.com/realazthat/excalidraw-brute-export-cli/blob/v${LAST_VERSION}/" \
  --img-url-prefix "https://raw.githubusercontent.com/realazthat/excalidraw-brute-export-cli/v${LAST_VERSION}/" \
  -o "${PROJ_PATH}/.github/README.remotified.md"
