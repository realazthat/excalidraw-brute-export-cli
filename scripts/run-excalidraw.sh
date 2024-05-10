#!/bin/bash
# https://gist.github.com/mohanpedala/1e2ff5661761d3abd0385e8223e16425
set -e -x -v -u -o pipefail

GREEN='\033[0;32m'
NC='\033[0m'

COMMIT=$(cat .github/.excalidraw-tag)
IMAGE_NAME="test-excalidraw"
INSTANCE_NAME="test-excalidraw"
PORT=59876

TMP_DIR=$(mktemp -d)
function cleanup {
  rm -rf "${TMP_DIR}" || true
}
trap cleanup EXIT

DOCKER_IMAGE_EXISTS=$(docker images -q "${IMAGE_NAME}:${COMMIT}" | wc -l)
if [[ "${DOCKER_IMAGE_EXISTS}" -eq 0 ]]; then
  cd "${TMP_DIR}"
  git clone https://github.com/excalidraw/excalidraw.git
  cd excalidraw
  git checkout "${COMMIT}"
  docker build -t "${IMAGE_NAME}:${COMMIT}" .
fi
docker rm -f "${INSTANCE_NAME}" || true
docker run -dit --name "${INSTANCE_NAME}" -p "${PORT}:80" "${IMAGE_NAME}:${COMMIT}"

EXCALIDRAW_URL="http://localhost:${PORT}"

# Wait for the server to start
while true; do
  if curl -s "${EXCALIDRAW_URL}" | grep -q "Excalidraw"; then
    break
  fi
  sleep 1
done


echo -e "${GREEN}Visit http://localhost:${PORT} to see Excalidraw${NC}"
