#!/usr/bin/env python3
"""Compare all IC pin connectivity with a separately traced copper source.

Never derive the expected net partition from the generated RTL or the KiCad
manifest. rev0_copper_ic_nets.json is extracted from Willegal's Osmond layout.
Net labels differ; both split and shorted nets are checked by pin membership.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
gold = json.loads((ROOT/'board/rev0_copper_ic_nets.json').read_text())
actual = json.loads((ROOT/'board/rev0_connectivity.json').read_text())['components']
models = json.loads((ROOT/'board/models.json').read_text())
ic_refs = {r for r, c in actual.items() if c['part'] in models}
ic_refs |= {'H7', 'B3', 'H13', 'K13'}
assert ic_refs == set(gold['components']), 'IC inventory differs from copper source'
assert len(ic_refs) == 83
forward, reverse = {}, {}
count = 0
for ref, pins in gold['components'].items():
    assert set(actual[ref]['pins']) <= set(pins), f'Nonphysical package pin: {ref}'
    omitted = set(pins) - set(actual[ref]['pins'])
    assert all(pins[p] is None for p in omitted), f'Connected copper pin omitted: {ref}'
    for pin, expected in pins.items():
        endpoint = f'{ref}.{pin}'
        observed = actual[ref]['pins'].get(pin, {}).get('net')
        # Each actual open pin is a distinct electrical node. Missing signal
        # membership in Osmond likewise means open, never one common null net.
        if expected is None:
            assert observed is None or observed.startswith('unconnected-'), \
                f'Copper open pin connected in manifest: {endpoint} -> {observed}'
            expected = f'OPEN:{endpoint}'
        if observed is None or observed.startswith('unconnected-'):
            observed = f'OPEN:{endpoint}'
        forward.setdefault(expected, {}).setdefault(observed, []).append(endpoint)
        reverse.setdefault(observed, {}).setdefault(expected, []).append(endpoint)
        count += 1
for net, partition in forward.items():
    assert len(partition) == 1, f'Copper net split in manifest: {net}: {partition}'
for net, partition in reverse.items():
    assert len(partition) == 1, f'Distinct copper nets shorted in manifest: {net}: {partition}'
assert count == 1368
print(f'PASS independent copper IC audit: {len(ic_refs)} packages, {count} pins, '
      f'{len(forward)} distinct nets/open nodes; no split or shorted IC nets')
