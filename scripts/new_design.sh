#!/bin/bash
# Create a new chip design from template
# Usage: ./scripts/new_design.sh <chip_name>

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <chip_name>"
    echo "  Creates a new chip design folder under design/<chip_name>"
    exit 1
fi

CHIP_NAME=$1
PROJECT_ROOT=$(dirname $(dirname $(realpath $0)))
TEMPLATE_DIR=$PROJECT_ROOT/design/_template
DESIGN_DIR=$PROJECT_ROOT/design/$CHIP_NAME

if [ -d "$DESIGN_DIR" ]; then
    echo "ERROR: Design '$CHIP_NAME' already exists at $DESIGN_DIR"
    exit 1
fi

echo "Creating new design: $CHIP_NAME"

# Copy template
cp -r $TEMPLATE_DIR $DESIGN_DIR

# Replace placeholder text in template files
find $DESIGN_DIR -name "*.md" -exec sed -i "s/\[CHIP_NAME\]/$CHIP_NAME/g" {} \;
find $DESIGN_DIR -name "*.sh" -exec sed -i "s/\[CHIP_NAME\]/$CHIP_NAME/g" {} \;

# Remove .gitkeep files (they've served their purpose)
find $DESIGN_DIR -name ".gitkeep" -delete

echo ""
echo "Design created at: $DESIGN_DIR"
echo ""
echo "Directory structure:"
find $DESIGN_DIR -type d | sed "s|$DESIGN_DIR|  design/$CHIP_NAME|"
echo ""
echo "Next steps:"
echo "  1. Edit spec:    design/$CHIP_NAME/spec/spec.md"
echo "  2. Write plan:   design/$CHIP_NAME/plans/implementation_plan.md"
echo "  3. Write RTL:    design/$CHIP_NAME/src/"
echo "  4. Add formal:   design/$CHIP_NAME/formal/"
echo "  5. Write TB:     design/$CHIP_NAME/tb/"
echo "  6. Run:          design/$CHIP_NAME/scripts/run_all.sh"
