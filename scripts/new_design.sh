#!/bin/sh
# Create one standalone chip or a member inside a canonical family folder.
set -eu

CHIP_PATH=${1:-}
case "$CHIP_PATH" in
    ''|/*|*..*|*//*|*/|*[!a-z0-9_/]*)
        echo 'Usage: scripts/new_design.sh <chip_slug|family_slug/member_slug>' >&2
        exit 2 ;;
esac
CHIP_NAME=$(basename "$CHIP_PATH")
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
TEMPLATE_DIR="$PROJECT_ROOT/design/_template"
DESIGN_DIR="$PROJECT_ROOT/design/$CHIP_PATH"
if [ -e "$DESIGN_DIR" ]; then
    echo "ERROR: Design already exists: $DESIGN_DIR" >&2
    exit 1
fi
mkdir -p "$(dirname "$DESIGN_DIR")"
cp -R "$TEMPLATE_DIR" "$DESIGN_DIR"
find "$DESIGN_DIR" -name '*.md' -exec sed -i "s/\[CHIP_NAME\]/$CHIP_NAME/g" {} +
find "$DESIGN_DIR" -name '*.sh' -exec sed -i "s/\[CHIP_NAME\]/$CHIP_NAME/g" {} +
find "$DESIGN_DIR" -name '.gitkeep' -delete
printf 'Created design/%s\n' "$CHIP_PATH"
printf '%s\n' 'Next: fill the specification and plans, link its canonical/member issue, and update the member/family README and design index.'
