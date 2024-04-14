#!/bin/bash
# https://gist.github.com/mohanpedala/1e2ff5661761d3abd0385e8223e16425
set -e -x -v -u -o pipefail

SCRIPT_DIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")
source "${SCRIPT_DIR}/utilities/common.sh"


TMP_PROJ_PATH=$(mktemp -d)
TMP_DIR=$(mktemp -d)
function cleanup {
  rm -Rf "${TMP_DIR}" || true
  rm -Rf "${TMP_PROJ_PATH}" || true
}
trap cleanup EXIT

################################################################################
# Build wheel
cd "${TMP_PROJ_PATH}"


# Copy everything including hidden files, skip .gitignore files, and ignore errors.
rsync -av \
  --exclude node_modules/ \
  --exclude '.cache' \
  "${PROJ_PATH}/" "${TMP_PROJ_PATH}/"

# Make everything writable, because `python -m build` copies everything and then
# deletes it, which is a problem if something is read only.
#
# Skips the dot files.
find "${TMP_PROJ_PATH}" -type f -not -path '*/.*' -exec chmod 777 {} +
################################################################################
# Install excalidraw-brute-export-cli and run smoke test


cd "${TMP_PROJ_PATH}"
TARBALL_NAME=$(npm pack)
TARBALL="${TMP_PROJ_PATH}/${TARBALL_NAME}"

cd "${TMP_DIR}"
npm install "${TARBALL}"
echo -e "${GREEN}Success: excalidraw-brute-export-cli installed successfully${NC}"

npx --no-install excalidraw-brute-export-cli --version
npx --no-install excalidraw-brute-export-cli --help
echo -e "${GREEN}Success: excalidraw-brute-export-cli smoke test ran successfully${NC}"

echo -e "${GREEN}${BASH_SOURCE[0]}: Tests ran successfully${NC}"
################################################################################
