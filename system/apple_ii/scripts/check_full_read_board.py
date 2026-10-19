#!/usr/bin/env python3
"""Require the original Monitor's checksum error indication at its output."""
import sys
from pathlib import Path
text=(Path(__file__).resolve().parents[1]/'work/full_read_output.txt').read_text()
bad=int(sys.argv[1])
assert bad in (0,1)
assert ('ERR' in text)==bool(bad),f'Incorrect checksum-error output: {text!r}'
print('PASS original Monitor checksum error indication:',bool(bad))
