#!/bin/bash
# https://gist.github.com/mohanpedala/1e2ff5661761d3abd0385e8223e16425
set -e -x -v -u -o pipefail

SCRIPT_DIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")
source "${SCRIPT_DIR}/utilities/common.sh"

VHS_PS1=${VHS_PS1:-}
if [[ -z "${VHS_PS1}" ]]; then
  echo -e "${RED}VHS_PS1 is not set${NC}"
  [[ $0 == "${BASH_SOURCE[0]}" ]] && EXIT="exit" || EXIT="return"
  ${EXIT} 1
fi

# This is meant to run inside the vhs docker container.
apt-get -y install git curl unzip rsync

export NVM_DIR="${HOME}/.nvm"
if [[ -d "${NVM_DIR}" ]]; then
  echo -e "${BLUE}NVM is already installed${NC}"
else
  echo -e "${BLUE}Installing NVM${NC}"
  cd ~
  git clone https://github.com/nvm-sh/nvm.git .nvm
  cd ~/.nvm
  git checkout v0.39.7
fi
cd ~
[[ -s "${NVM_DIR}/nvm.sh" ]] && \. "${NVM_DIR}/nvm.sh"
NODE_VERSION=$(cat "${PROJ_PATH}/.nvmrc")
nvm install ${NODE_VERSION}

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


# Make everything writable, just in case the build system needs to  delete files
# copies everything and then deletes it, which is a problem if something is read
# only.
#
# Skips the dot files.
find "${TMP_PROJ_PATH}" -type f -not -path '*/.*' -exec chmod 777 {} +

cp "${PROJ_PATH}/.nvmrc" "${TMP_PROJ_PATH}/.nvmrc"
nvm use ${NODE_VERSION}
TARBALL_NAME=$(npm pack)
TARBALL="${TMP_PROJ_PATH}/${TARBALL_NAME}"
################################################################################
cd "${TMP_DIR}"
cp "${PROJ_PATH}/.nvmrc" "${TMP_DIR}/.nvmrc"
nvm use ${NODE_VERSION}
################################################################################
NODE_VERSION_PATH=${PWD}/.nvmrc \
  bash "${PROJ_PATH}/scripts/utilities/ensure-node-version.sh"
################################################################################
if npx --loglevel verbose --no-install excalidraw-brute-export-cli --version; then
  echo -e "${RED}Expected excalidraw-brute-export-cli to to fail in a clean environment${NC}"
  echo -e "${RED}excalidraw-brute-export-cli is installed globally?${NC}"

  npm install which@4.0.0 --prefix "${TMP_DIR}"
  npx --no-install  which excalidraw-brute-export-cli

  exit 1
else
  echo -e "${GREEN}Success: excalidraw-brute-export-cli failed in a clean environment${NC}"
fi
################################################################################

cp -r "${PROJ_PATH}/examples" "${TMP_DIR}/examples"
npm install "${TARBALL}" --prefix "${TMP_DIR}"
echo -e "${GREEN}Success: excalidraw-brute-export-cli installed successfully${NC}"

npx playwright install firefox
################################################################################


npx excalidraw-brute-export-cli --help
npx excalidraw-brute-export-cli --version
echo -e "${GREEN}Success: excalidraw-brute-export-cli smoke test ran successfully${NC}"

mkdir -p .github
export PS1="${VHS_PS1}"
vhs "${PROJ_PATH}/.github/demo.tape"
cp -f .github/demo.gif "${PROJ_PATH}/.github/demo.gif"

echo -e "${GREEN}${BASH_SOURCE[0]}: Tests ran successfully${NC}"
################################################################################
