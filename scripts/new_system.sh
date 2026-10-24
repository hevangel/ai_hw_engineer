#!/bin/sh
# Create a new historical system from the shared template.
# Usage: ./scripts/new_system.sh <system_name>

set -eu

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <system_name>" >&2
    exit 1
fi

SYSTEM_NAME=$1
case "$SYSTEM_NAME" in
    ''|[!a-z0-9]*|*[!a-z0-9_-]*)
        echo "ERROR: Use a lowercase letter or digit followed by lowercase letters, digits, underscores or hyphens." >&2
        exit 1
        ;;
esac

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TEMPLATE_DIR=$PROJECT_ROOT/system/_template
SYSTEM_DIR=$PROJECT_ROOT/system/$SYSTEM_NAME

if [ ! -d "$TEMPLATE_DIR" ]; then
    echo "ERROR: System template is missing at $TEMPLATE_DIR" >&2
    exit 1
fi
if [ -e "$SYSTEM_DIR" ] || [ -L "$SYSTEM_DIR" ]; then
    echo "ERROR: System destination already exists at $SYSTEM_DIR" >&2
    exit 1
fi

# Reserve the destination before copying; never overwrite an existing system.
mkdir "$SYSTEM_DIR"
cp -R "$TEMPLATE_DIR/." "$SYSTEM_DIR/"
find "$SYSTEM_DIR" -type f -name '*.md' -exec \
    sed -i "s/\[SYSTEM_NAME\]/$SYSTEM_NAME/g" {} \;

echo "System created at: $SYSTEM_DIR"
echo "Next steps:"
echo "  1. Define hardware, firmware provenance and scope in system/$SYSTEM_NAME/spec/spec.md"
echo "  2. Complete the implementation and verification plans in system/$SYSTEM_NAME/plans/"
echo "  3. Implement RTL, testbenches and host integration in src/, tb/ and host/"
echo "  4. Add verification scripts and record actual results in report/final_report.md"
echo "  5. Update the system README and system/README.md index with sourced history"
echo "See system/TEMPLATE.md for README and real-screenshot conventions."
