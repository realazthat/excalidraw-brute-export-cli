#!/bin/bash
# WARNING: This file is auto-generated by snipinator. Do not edit directly.
# SOURCE: `examples/simple_example.sh.jinja2`.

#!/bin/bash
# https://gist.github.com/mohanpedala/1e2ff5661761d3abd0385e8223e16425
set -e -x -v -u -o pipefail
set +v
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
PS4="${GREEN}$ ${NC}"

EXCALIDRAW_BRUTE_EXPORT_CLI_URL=${EXCALIDRAW_BRUTE_EXPORT_CLI_URL:-}
if [[ -z "${EXCALIDRAW_BRUTE_EXPORT_CLI_URL}" ]]; then
  echo -e "${RED}EXCALIDRAW_BRUTE_EXPORT_CLI_URL is not set${NC}"
  exit 1
fi



# Don't run this in act/GH actions because act doesn't play with with nested
# docker; the paths mess up.
if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
  echo -e "${YELLOW}This script is not meant to be run in GitHub Actions.${NC}"
  exit 0
fi

: ECHO_SNIPPET_START
# SNIPPET_START
docker build -t my-excalidraw-brute-export-cli-image .

# /data in the docker image is the working directory, so paths are simpler.
docker run --rm --tty \
  -u "$(id -u):$(id -g)" \
  -v "${PWD}:/data" \
  -e EXCALIDRAW_BRUTE_EXPORT_CLI_URL --network host \
  my-excalidraw-brute-export-cli-image \
  -i ./examples/simple.excalidraw \
  --background 1 \
  --embed-scene 0 \
  --dark-mode 0 \
  --scale 1 \
  --format svg \
  -o "./examples/simple_example_output.svg"

ls "./examples/simple_example_output.svg"

# SNIPPET_END
: ECHO_SNIPPET_END
