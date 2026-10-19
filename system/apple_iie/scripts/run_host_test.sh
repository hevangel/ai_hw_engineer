#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
cc -std=c11 -Wall -Wextra -Werror -shared -fPIC host/panel.c -o work/panel.so
python3 host/test_transport.py
python3 host/test_panel.py
