#!/usr/bin/env python3
"""Require actual historical BASIC output, not just agreeing RAM writes."""
from pathlib import Path

text = (Path(__file__).resolve().parents[1]/'work/basic_output.txt').read_text()
assert 'SUM=55' in text, 'Original BASIC did not print the computed sum'
assert '0300- 37 09' in text, 'Monitor did not print BASIC arithmetic/lores readback'
assert 'ERR' not in text, f'Original BASIC reported an error: {text!r}'
print('PASS original BASIC printed SUM=55 and Monitor read back 37 09')
