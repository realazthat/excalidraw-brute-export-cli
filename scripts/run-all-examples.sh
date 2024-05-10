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
# See generate-readme.sh for explanation.
export FORCE_COLOR=3
export TERM=dumb

# For each sh in examples
find examples -type f -name "*.sh" -print0 | while IFS= read -r -d '' EXAMPLE; do
  bash "${EXAMPLE}"
  echo -e "${GREEN}${EXAMPLE} ran successfully${NC}"
done

echo -e "${GREEN}${BASH_SOURCE[0]} ran successfully${NC}"
