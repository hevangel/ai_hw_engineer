#!/usr/bin/env python3
"""Check externally documented copper corrections and analog endpoints.

This is a bounded audit, not certification of all imported connections.
Source: https://www.willegal.net/appleii/appleii-pcb.htm and original S-10/S-11.
Use transcription aliases J13=Red Book K13 (flip-flop), K13=741.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COMPONENTS = json.loads((ROOT/'board/rev0_connectivity.json').read_text())['components']


def net(ref, pin):
    return COMPONENTS[ref]['pins'][str(pin)]['net']


def same(*endpoints):
    nets = [net(*endpoint) for endpoint in endpoints]
    assert len(set(nets)) == 1, f'Copper mismatch {endpoints}: {nets}'


def supply(ref, pin, expected):
    assert net(ref, pin) == expected, f'Supply mismatch {ref}.{pin}'


# Published Red Book errors corrected by direct examination of real copper.
supply('H7', 38, 'GND')
supply('K13', 7, '+5V')
supply('K13', 4, '-5V')
supply('A5', 1, '-12V')
supply('A5', 12, '-5V')
supply('R9', 1, '+5V')
same(('A8', 12), ('A10', 4))
same(('A8', 7), ('A10', 3))
same(('F13', 14), ('B10', 13))
same(('F13', 13), ('J13', 11))
same(('H2', 5), ('B1', 6))  # Board clock 1, not CPU socket's separate clock output.

# Q3 summing/LC/pot topology, including the often missed parallel coil/cap.
same(('B12', 12), ('R5', 1))
same(('R5', 2), ('L1', 1), ('Cap2', 1), ('CT3', 2), ('R6', 1))
same(('L1', 2), ('Cap2', 2), ('CT3', 1), ('R11', 3))
same(('R6', 2), ('R7', 1), ('R8', 1), ('Q3', 3))
same(('R7', 2), ('B10', 5))
same(('R8', 2), ('C13', 8))
same(('R9', 2), ('Q3', 2))
same(('Q3', 1), ('R11', 1), ('J18', 3))
same(('R11', 2), ('R10', 1))

# Q4 AC coupling, diode orientation, shunt cap and speaker return to +5.
same(('J13', 5), ('Cap11', 1))
same(('Cap11', 2), ('R24', 2))
same(('R24', 1), ('CR1', 1), ('Q4', 2))
same(('CR1', 2), ('Q4', 1), ('Cap12', 2))
same(('Q4', 3), ('R25', 2))
same(('R25', 1), ('Cap12', 1), ('SPKR1', 1))
supply('SPKR1', 2, '+5V')

expected_values = {'L1': '27uH', 'Cap2': '47pf', 'CT3': '5-50pF', 'R5': '1K',
                   'R6': '2K7', 'R7': '1K5', 'R8': '2K', 'R9': '10R',
                   'R10': '27R', 'R11': '200R', 'Cap11': '.1uF',
                   'Cap12': '.1uF', 'R24': '47K', 'R25': '27R'}
for ref, value in expected_values.items():
    assert COMPONENTS[ref]['value'] == value, f'Component value mismatch {ref}'
print('PASS bounded copper-correction and Q3/Q4 endpoint/value audit')
