#!/bin/bash
# https://gist.github.com/mohanpedala/1e2ff5661761d3abd0385e8223e16425
set -e -x -v -u -o pipefail

export NVM_DIR=${NVM_DIR:-"${HOME}/.nvm"}

{ set +x +v; } 2>/dev/null; [[ -s "${NVM_DIR}/nvm.sh" ]] && \. "${NVM_DIR}/nvm.sh"; set -x -v
nvm install
nvm use


# SNIPPET_START
npm install
npx --no-install excalidraw-brute-export-cli \
  -i ./examples/simple.excalidraw \
  --background 1 \
  --embed-scene 1 \
  --embed-scene 1 \
  --scale 1 \
  --format png \
  -o "${PWD}/.deleteme/output.png" \
  --verbose
# SNIPPET_END
