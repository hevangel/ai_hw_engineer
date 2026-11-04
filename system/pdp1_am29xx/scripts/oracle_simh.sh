#!/bin/bash
# Run the SIMH PDP-1 oracle over the image files in work/<name>.hex.
# Invoked inside the pdp1-oracle image, with the repository mounted at /work.
set -eu
cd /work
for name in "$@"; do
  script="/tmp/$name.simh"
  {
    echo "set cpu history=512"
    echo "set dpy disabled"
    echo "set pc 0"
    while read -r addr word; do
      [ -z "$addr" ] && continue
      echo "dep $addr $word"
    done < "work/$name.hex"
    echo "set pc 0"
    echo "run"
    echo "show cpu history"
    echo "exit"
  } > "$script"
  /usr/local/bin/pdp1 "$script" > "work/$name.simh.out" 2>&1 || true
done
echo "oracle runs complete"
