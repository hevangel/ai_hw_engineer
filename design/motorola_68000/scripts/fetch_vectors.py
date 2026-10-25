"""Fetch the SingleStepTests 680x0 vector suite into references/.

The suite (1,000,060 single-instruction tests, 124 opcode files) is too
large to vendor in git (~194 MB compressed), so it is a working-tree
download, mirroring the repo's treatment of other large raw inputs.
Re-run this script once before compiling the harness
(scripts/make_68000_vectors.py).
"""
import json
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
DEST = (HERE.parent / 'references' / 'singlesteptests_680x0').resolve()
if HERE.parent not in DEST.parents:
    raise RuntimeError('destination escapes the design tree')
BASE = ('https://raw.githubusercontent.com/SingleStepTests/680x0/main/'
        '68000/v1/')


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    req = urllib.request.urlopen(
        'https://api.github.com/repos/SingleStepTests/680x0/git/trees'
        '/main?recursive=1')
    tree = json.loads(req.read())
    files = sorted(x['path'].split('/')[-1]
                   for x in tree['tree']
                   if x['path'].startswith('68000/v1/')
                   and x['path'].endswith('.json.gz'))
    print(f'{len(files)} vector files')
    for i, name in enumerate(files):
        dest = DEST / name
        if dest.exists() and dest.stat().st_size > 0:
            continue
        urllib.request.urlretrieve(BASE + name, dest)
        if (i + 1) % 20 == 0:
            print(f'  {i + 1}/{len(files)}')
    print(f'downloaded into {DEST}')


if __name__ == '__main__':
    main()
