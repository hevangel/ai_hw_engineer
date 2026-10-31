"""Assemble system/apple_ii/board/timing.json from the cited datasheet table.

Input : work/timing/ls_logic.json  (per-part values, source URL, page, notes)
Output: system/apple_ii/board/timing.json

Corrections applied here, each traceable to the 29 October 2026 datasheet pass:
  * document numbers kept only where the PDF text layer or a rendered page prints
    them; the rest cite the URL and printed page instead of an unverified number;
  * 74LS51 typical rounded up from 12.5 ns to 13 ns, because T_PD is an integer;
  * 74LS161 and 74LS257 publish no typical delay, so the maximum is used for both
    modes and the entry says so.
"""
import json
from pathlib import Path

ROOT = Path(r'B:\ai_hw_engineer')
SRC = json.loads((ROOT / 'work' / 'timing' / 'ls_logic.json').read_text())['parts']
OUT = ROOT / 'worktree' / 'apple-ii-timing' / 'system' / 'apple_ii' / 'board' / 'timing.json'

# Literature numbers that the TI scan actually prints. Everything else keeps the
# URL and page only, because an unprinted number is not a citation.
CONFIRMED = {
    '74LS00': 'SDLS025D', '74LS04': 'SDLS029C', '74LS08': 'SDLS033',
    '74LS11': 'SDLS131', '74LS51': 'SDLS113', '74LS74': 'SDLS119',
    '74LS86': 'SDLS124', '74LS153': 'SDLS055A', '74LS174': 'SDLS068A',
    '74LS175': 'SDLS068A', '74LS251': 'SDLS085', '74LS259': 'SDLS086',
    '74LS283': 'SDLS095A',
}

# Parts whose datasheet has no typical column: the maximum is used for both modes.
MAX_ONLY = {
    '74LS161': 'Fairchild DM74LS161A switching characteristics publish no typical; '
               'worst CL = 15 pF maximum (tPHL clock to ripple carry) used for both modes',
    '74LS257': 'Signetics 54LS/74LS257 AC table publishes maxima only; '
               'S to Zn maximum used for both modes',
}

TYP_OVERRIDE = {'74LS51': 13}

# Board parts the model cannot time: the DRAM/ROM devices have no access-time or
# refresh behaviour, so they keep the legacy output delay in every timing mode.
IDEALIZED = {
    '4116': 'DRAM model has no row-access, column-access or refresh timing '
            '(review item P3); board keeps the legacy 20 ns output delay',
    'ROM_Chip': 'ROM model is an idealized lookup with no access time; '
                'board keeps the legacy 5 ns output delay',
    '2513': 'Character-ROM model is an idealized lookup with no access time; '
            'board keeps the legacy 5 ns output delay',
}

# Non-TI parts, both read from manufacturer documents but not at the board's load.
DRIVERS = {
    '8T97': {
        'typ_ns': 8, 'max_ns': 13,
        'source': {
            'document': 'Signetics 8T95/96/97/98 product specification, 4 Dec 1985 (853-0445 81495)',
            'section': 'AC electrical characteristics',
            'page': '6-53',
            'url': 'https://www.parastream.com/downloads/datasheets/Signetics%208T95,%2096,%2097,%2098.pdf',
        },
        'note': 'Datasheet load is CL = 50 pF, not 15 pF; using the 50 pF maximum '
                'at the board load is conservative. tPLH max 12 ns, tPHL max 13 ns.',
    },
    '8T28': {
        'typ_ns': 17, 'max_ns': 17,
        'source': {
            'document': 'AMD Am8T26A/Am8T28 Schottky three-state quad bus driver/receiver',
            'section': 'Switching characteristics (driver and receiver propagation delay)',
            'page': '12-84',
            'url': 'https://datasheet.octopart.com/N8T26B-AMD-datasheet-182221349.pdf',
        },
        'note': 'Second-source AMD sheet: 17 ns maximum for both directions, no typical. '
                'No Signetics 8T28 delay was readable; both modes use the AMD maximum.',
    },
}

parts = {}
for part, meta in SRC.items():
    entry = {
        'typ_ns': meta['tpd_typ_ns'],
        'max_ns': meta['tpd_max_ns'],
        'parameter': meta['parameter'],
        'note': meta['notes'],
        'source': {
            'document': CONFIRMED.get(part),
            'page': meta['page'],
            'url': meta['source'],
            'section': 'switching characteristics, VCC = 5 V, TA = 25 C',
        },
    }
    if part in CONFIRMED:
        pass
    else:
        entry['source']['document_note'] = (
            'literature number not printed in the scan; cited by URL and printed page')
    if part in TYP_OVERRIDE:
        entry['typ_ns'] = TYP_OVERRIDE[part]
        entry['note'] += ' Typical rounded up from 12.5 ns to 13 ns (integer T_PD).'
    if part in MAX_ONLY:
        entry['typ_ns'] = entry['max_ns']
        entry['note'] = MAX_ONLY[part] + '. ' + entry['note']
    parts[part] = entry

parts.update(DRIVERS)
for part, note in IDEALIZED.items():
    parts[part] = {'idealized': True, 'note': note}

parts['8T97-AppleII'] = {'same_as': '8T97'}
parts['8T28-AppleII'] = {'same_as': '8T28'}

document = {
    'schema': 2,
    'conditions': 'VCC=5V, CL=15pF, TA=25C unless the entry says otherwise',
    'note': 'Per-package propagation delay for the revision-0 board. Characterized '
            'entries cite the manufacturer document that publishes them, with the '
            'printed page; entries marked idealized describe models that have no '
            'access-time behaviour and keep the legacy placeholder in every mode.',
    'parts': dict(sorted(parts.items())),
}

OUT.write_text(json.dumps(document, indent=2) + '\n', encoding='utf-8', newline='\n')
print(f'wrote {OUT} with {len(document["parts"])} entries')
print('idealized:', sorted(IDEALIZED))
print('no document:', sorted(p for p in SRC if p not in CONFIRMED))
