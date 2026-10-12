#!/usr/bin/env python3
"""Fetch unchanged MIT-licensed Microsoft MS-DOS 1.25 DEBUG.COM."""
import hashlib
from pathlib import Path
import urllib.request

COMMIT = '2d04cacc5322951f187bb17e017c12920ac8ebe2'
ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'work/software'
DEST.mkdir(parents=True, exist_ok=True)
BASE = f'https://raw.githubusercontent.com/microsoft/MS-DOS/{COMMIT}/'
for name, source in [('DEBUG.COM', 'v1.25/bin/DEBUG.COM'), ('LICENSE', 'LICENSE')]:
    path = DEST / name
    if not path.exists():
        with urllib.request.urlopen(BASE + source, timeout=90) as response:
            path.write_bytes(response.read())
    if name == 'DEBUG.COM' and hashlib.sha256(path.read_bytes()).hexdigest() != \
            '217b59ff054a238ace99c51831e227c9edfe0c0c6925a51c99a2d0c6107402ef':
        raise ValueError('Historical DEBUG.COM hash mismatch')
print('Prepared original Microsoft DEBUG.COM (pinned SHA-256 verified)')
