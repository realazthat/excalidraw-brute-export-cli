#!/bin/bash
# https://gist.github.com/mohanpedala/1e2ff5661761d3abd0385e8223e16425
set -e -x -v -u -o pipefail

SCRIPT_DIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")
source "${SCRIPT_DIR}/utilities/common.sh"

################################################################################
PYTHON_VERSION_PATH=${PWD}/scripts/.python-version \
  VENV_PATH=${PWD}/.cache/scripts/.venv \
  source "${PROJ_PATH}/scripts/utilities/ensure-venv.sh"
PYTHON_VERSION_PATH=${PWD}/scripts/.python-version \
  TOML=${PROJ_PATH}/scripts/pyproject.toml EXTRA=dev \
  DEV_VENV_PATH="${PWD}/.cache/scripts/.venv" \
  TARGET_VENV_PATH="${PWD}/.cache/scripts/.venv" \
  bash "${PROJ_PATH}/scripts/utilities/ensure-reqs.sh"
################################################################################


CUSTOM_WARNING=$(cat << 'EOF'
#!/bin/bash
# WARNING: This file is auto-generated by snipinator. Do not edit directly.
# SOURCE: `{template_file_name}`.

.
EOF
)

python -m snipinator.cli \
  -t "${PROJ_PATH}/examples/simple_example.sh.jinja2" \
  --args '{"example_type": "npm-module", "module_name": "excalidraw-brute-export-cli"}' \
  --warning-header "${CUSTOM_WARNING%.}" \
  --rm \
  --force \
  --create \
  -o "${PROJ_PATH}/examples/simple_example.sh" \
  --chmod-ro \
  --skip-unchanged


python -m snipinator.cli \
  -t "${PROJ_PATH}/examples/simple_example.sh.jinja2" \
  --args '{"example_type": "docker-local", "docker_image_name": "my-excalidraw-brute-export-cli-image"}' \
  --warning-header "${CUSTOM_WARNING%.}" \
  --rm \
  --force \
  --create \
  -o "${PROJ_PATH}/examples/simple-local-docker_example.sh" \
  --chmod-ro \
  --skip-unchanged


LAST_VERSION=$(node -p "require('./package.json').version")
python -m snipinator.cli \
  -t "${PROJ_PATH}/examples/simple_example.sh.jinja2" \
  --args '{"example_type": "docker-remote", "docker_image_name": "ghcr.io/realazthat/excalidraw-brute-export-cli:v'"${LAST_VERSION}"'"}' \
  --warning-header "${CUSTOM_WARNING%.}" \
  --rm \
  --force \
  --create \
  -o "${PROJ_PATH}/examples/simple-remote-docker_example-noautorun.sh" \
  --chmod-ro \
  --skip-unchanged