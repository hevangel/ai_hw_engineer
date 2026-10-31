#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
(cd "$ROOT/formal" && sby -f intel_8008.sby prove && sby -f intel_8008.sby cover)
