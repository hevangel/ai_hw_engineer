#!/usr/bin/env python3
"""Reproduce the factual IC-pad fixture from the pinned independent Osmond file.

Download https://www.willegal.net/appleii/A2rev0.zip and extract only
appleiiboardV3a36.osm. This program never reads KiCad pin nets or generated RTL.
The package inventory selects scope; footprint pin labels and signal membership
come entirely from the independently traced source.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shlex

ROOT = Path(__file__).resolve().parents[1]
FILE_SHA = '7ba43b7783159ac7899f3883a524229177e8436f9403ed6f47100264934000c9'
ZIP_SHA = '994555e231da779b7f262d2c2fa5ab7475341d0a66a0520eb06968d6f45db3f1'


def normalized(name):
    return ' '.join(name.split())


def extract(path):
    assert hashlib.sha256(path.read_bytes()).hexdigest() == FILE_SHA, 'Unreviewed copper source'
    text = path.read_text(encoding='utf-8')
    models = json.loads((ROOT/'board/models.json').read_text())
    inventory = json.loads((ROOT/'board/rev0_connectivity.json').read_text())['components']
    refs = {r for r, c in inventory.items() if c['part'] in models}
    refs |= {'H7', 'B3', 'H13', 'K13'}
    parts = {normalized(shlex.split(m[2])[0]): normalized(shlex.split(m[1])[0])
             for m in re.finditer(r'^Part (.*?) \{ Name (.*?) (?:Value .*? )?Loc \{', text, re.M)}
    aliases = {'C1': 'C-1', 'H7': '6502', 'A5': 'A-4', 'J13': 'K-13',
               'K13': 'K-13_1', 'ROM-F8': 'RO F'}
    labels = {r: aliases.get(r, r if r in parts else
                            re.sub(r'^([A-Z]+)(\d+)$', r'\1-\2', r)) for r in refs}
    assert len(set(labels.values())) == 83 and all(n in parts for n in labels.values())
    reverse = {v: k for k, v in labels.items()}
    signals = {}
    for match in re.finditer(r'^Signal (.*?)\s*\n\{(.*?)\}', text, re.M | re.S):
        name = normalized(shlex.split(match[1])[0])
        for endpoint in shlex.split(match[2]):
            ref, pin = endpoint.rsplit('-', 1)
            ref = normalized(ref)
            if ref in reverse:
                endpoint = (reverse[ref], pin)
                assert endpoint not in signals, f'Duplicate source pad {endpoint}'
                signals[endpoint] = name
    types = {normalized(shlex.split(m[1])[0]): re.findall(r'^Pin (\d+) \{', m[2], re.M)
             for m in re.finditer(r'^Type (.*?) \{(.*?)(?=^Type |^Part |^TextPart |^Signal |\Z)',
                                  text, re.M | re.S)}
    components = {r: {p: signals.get((r, p)) for p in types[parts[label]]}
                  for r, label in labels.items()}
    assert sum(map(len, components.values())) == 1368
    assert len(signals) == 1330
    return {'schema': 1, 'source': {
        'url': 'https://www.willegal.net/appleii/A2rev0.zip', 'zip_sha256': ZIP_SHA,
        'file': 'appleiiboardV3a36.osm', 'file_sha256': FILE_SHA,
        'note': 'Factual IC pin-net extraction from a separately traced working copper replica; '
                'excludes artwork, tracks and non-IC components.'},
        'package_labels': dict(sorted(labels.items())),
        'components': {r: components[r] for r in sorted(components)}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    document = extract(args.source)
    fixture = ROOT/'board/rev0_copper_ic_nets.json'
    if args.check:
        assert json.loads(fixture.read_text()) == document, 'Stale copper fixture'
    else:
        fixture.write_text(json.dumps(document, indent=2)+'\n', encoding='utf-8', newline='\n')
    print('PASS reproducible independent copper extraction: 83 ICs, 1368 pads')


if __name__ == '__main__':
    main()
