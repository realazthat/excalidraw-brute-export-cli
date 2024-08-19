#!/bin/bash
# https://gist.github.com/mohanpedala/1e2ff5661761d3abd0385e8223e16425
set -e -x -v -u -o pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

IDEAL_NODE_VERSION="v20.12.1"
WANTED_NODE_VERSION=$(cat .nvmrc)
ACTUAL_NODE_VERSION=$(node --version)

IDEAL_EXCALIDRAW_TAG=$(cat .github/.excalidraw-tag)
EXCALIDRAW_TAG=${EXCALIDRAW_TAG:-${IDEAL_EXCALIDRAW_TAG}}

EXCALIDRAW_INSTANCE_NAME=${EXCALIDRAW_INSTANCE_NAME:-"test-excalidraw"}
EXCALIDRAW_PORT=${EXCALIDRAW_PORT:-}
IMAGE_NAME="test-excalidraw"

if [[ -z "${EXCALIDRAW_TAG}" ]]; then

  echo -e "${RED}EXCALIDRAW_TAG is not set, set it to an excalidraw github tag, or the string 'https://excalidraw.com'.${NC}"
  exit 1
fi

if [[ "${EXCALIDRAW_TAG}" = "https://excalidraw.com" ]]; then
  echo -e "${BLUE}No specified EXCALIDRAW_TAG, not starting excalidraw docker container${NC}"
  export EXCALIDRAW_BRUTE_EXPORT_CLI_URL="https://excalidraw.com"
  exit 0
fi

if [[ -z "${EXCALIDRAW_PORT}" ]]; then
  if [[ "${IDEAL_NODE_VERSION}" == "${WANTED_NODE_VERSION}" && "${WANTED_NODE_VERSION}" == "${ACTUAL_NODE_VERSION}" ]]; then
    EXCALIDRAW_PORT=59876
  else
    EXCALIDRAW_PORT=$(python3 -c 'import socket; s=socket.socket(); s.bind(("",0)); print(s.getsockname()[1]); s.close()')
  fi
fi

TMP_DIR=$(mktemp -d)
function cleanup {
  rm -rf "${TMP_DIR}" || true
}
trap cleanup EXIT

DOCKER_IMAGE_EXISTS=$(docker images -q "${IMAGE_NAME}:${EXCALIDRAW_TAG}" | wc -l)
if [[ "${DOCKER_IMAGE_EXISTS}" -eq 0 ]]; then
  OLD_PWD="${PWD}"
  cd "${TMP_DIR}"
  git clone https://github.com/excalidraw/excalidraw.git
  cd excalidraw
  git checkout "${EXCALIDRAW_TAG}"
  docker build -t "${IMAGE_NAME}:${EXCALIDRAW_TAG}" .
  cd "${OLD_PWD}"
fi
docker rm -f "${EXCALIDRAW_INSTANCE_NAME}" || true
docker run -dit --name "${EXCALIDRAW_INSTANCE_NAME}" -p "${EXCALIDRAW_PORT}:80" "${IMAGE_NAME}:${EXCALIDRAW_TAG}"

export EXCALIDRAW_BRUTE_EXPORT_CLI_URL="http://localhost:${EXCALIDRAW_PORT}"

# Wait for the server to start
while true; do
  if curl -s "${EXCALIDRAW_BRUTE_EXPORT_CLI_URL}" | grep -q "Excalidraw"; then
    break
  fi
  sleep 1
done


echo -e "${GREEN}Visit ${EXCALIDRAW_BRUTE_EXPORT_CLI_URL} to see Excalidraw${NC}"
