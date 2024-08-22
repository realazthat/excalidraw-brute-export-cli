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

TMP_PROJ_PATH=$(mktemp -d)
TMP_DIR=$(mktemp -d)
function cleanup {
  rm -Rf "${TMP_DIR}" || true
  rm -Rf "${TMP_PROJ_PATH}" || true
}
trap cleanup EXIT

################################################################################
# Build package tarball
cd "${TMP_PROJ_PATH}"


# Copy everything including hidden files, and ignore errors.
rsync -av \
  --exclude node_modules/ \
  --exclude '.cache' \
  --exclude '.git' \
  "${PROJ_PATH}/" "${TMP_PROJ_PATH}/"

# Make everything writable, because `python -m build` copies everything and then
# deletes it, which is a problem if something is read only.
#
# Skips the dot files.
find "${TMP_PROJ_PATH}" -type f -not -path '*/.*' -exec chmod 777 {} +


cd "${TMP_PROJ_PATH}"
TARBALL_NAME=$(npm pack)
TARBALL="${TMP_PROJ_PATH}/${TARBALL_NAME}"
################################################################################

cd "${TMP_DIR}"

if npx --loglevel verbose --no-install excalidraw-brute-export-cli --version; then
  echo -e "${RED}Expected excalidraw-brute-export-cli to to fail in a clean environment${NC}"
  echo -e "${RED}excalidraw-brute-export-cli is installed globally?${NC}"

  npm install which@4.0.0 --prefix "${TMP_DIR}"
  npx --no-install  which excalidraw-brute-export-cli

  exit 1
else
  echo -e "${GREEN}Success: excalidraw-brute-export-cli failed in a clean environment${NC}"
fi


cp -r "${PROJ_PATH}/examples" "${TMP_DIR}/examples"

npm install "${TARBALL}" --prefix "${TMP_DIR}"
npx playwright install firefox
echo -e "${GREEN}Success: excalidraw-brute-export-cli installed successfully${NC}"

npx --no-install excalidraw-brute-export-cli --version
npx --no-install excalidraw-brute-export-cli --help
bash examples/simple_example.sh
echo -e "${GREEN}Success: excalidraw-brute-export-cli smoke test ran successfully${NC}"

echo -e "${GREEN}${BASH_SOURCE[0]}: Tests ran successfully${NC}"
################################################################################
