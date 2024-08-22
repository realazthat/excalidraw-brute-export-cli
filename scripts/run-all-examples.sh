#!/bin/bash
# https://gist.github.com/mohanpedala/1e2ff5661761d3abd0385e8223e16425
set -e -x -v -u -o pipefail

SCRIPT_DIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")
source "${SCRIPT_DIR}/utilities/common.sh"

################################################################################
EXCALIDRAW_BRUTE_EXPORT_CLI_URL=${EXCALIDRAW_BRUTE_EXPORT_CLI_URL:-}
if [[ -z "${EXCALIDRAW_BRUTE_EXPORT_CLI_URL}" ]]; then
  echo -e "${RED}EXCALIDRAW_BRUTE_EXPORT_CLI_URL is not set${NC}"
  exit 1
fi
export EXCALIDRAW_BRUTE_EXPORT_CLI_URL
################################################################################
NODE_VERSION_PATH=${PWD}/.nvmrc \
  bash "${PROJ_PATH}/scripts/utilities/ensure-node-version.sh"
################################################################################
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

# For each sh in examples
find examples -type f -name "*_example.sh" -print0 | while IFS= read -r -d '' EXAMPLE; do
  bash "${EXAMPLE}"
  echo -e "${GREEN}${EXAMPLE} ran successfully${NC}"
done

echo -e "${GREEN}${BASH_SOURCE[0]} ran successfully${NC}"
