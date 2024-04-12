#!/bin/bash
# https://gist.github.com/mohanpedala/1e2ff5661761d3abd0385e8223e16425
set -e -x -v -u -o pipefail


npx excalidraw-brute-export-cli \
  -i ./examples/simple.excalidraw \
  --background 1 \
  --embed-scene 1 \
  --embed-scene 1 \
  --scale 1 \
  --format png \
  -o "${PWD}/.deleteme/output.png" \
  --verbose

ls -la "${PWD}/.deleteme/output.png"
