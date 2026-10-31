"""Download each cited datasheet and extract its switching-characteristics text.

Writes a compact digest so the numbers in board/timing.json can be checked
against the primary source rather than against a summary.
"""
import json
import re
import sys
import urllib.request
from pathlib import Path

ROOT = Path(r'B:\ai_hw_engineer')
CACHE = ROOT / 'work' / 'timing' / 'ds2'
CACHE.mkdir(parents=True, exist_ok=True)
OUT = ROOT / 'work' / 'timing-sources' / 'digest.txt'

table = json.loads((ROOT / 'work' / 'timing' / 'ls_logic.json').read_text())['parts']


def fetch(part, url):
    dest = CACHE / f'{part}.pdf'
    if dest.exists() and dest.stat().st_size > 10000:
        return dest
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req, timeout=90) as r:
        dest.write_bytes(r.read())
    return dest


def screenshot_text(path):
    import pymupdf
    doc = pymupdf.open(path)
    pages = [p.get_text() for p in doc]
    return doc, pages


lines = []
for part, meta in table.items():
    url = meta['source']
    lines.append(f'===== {part} ({url})')
    try:
        path = fetch(part, url)
    except Exception as exc:
        lines.append(f'  DOWNLOAD FAILED: {exc}')
        continue
    try:
        doc, pages = screenshot_text(path)
    except Exception as exc:
        lines.append(f'  PARSE FAILED: {exc}')
        continue
    joined = '\n'.join(pages)
    docs = sorted(set(re.findall(r'SDLS\s?\d+[A-Z]?', joined)))
    lines.append(f'  pages={len(pages)} docids={docs}')
    target = None
    for i, text in enumerate(pages):
        low = text.lower()
        if 'switching characteristics' in low:
            target = (i, text)
            break
    if target is None:
        lines.append('  NO switching-characteristics heading found')
        continue
    idx, text = target
    start = text.lower().index('switching characteristics')
    chunk = text[start:start + 1400].replace('\n', ' | ')
    lines.append(f'  p{idx + 1}: {chunk}')

OUT.write_text('\n'.join(lines), encoding='utf-8')
print(f'wrote {OUT} ({OUT.stat().st_size} bytes), {len(table)} parts')
