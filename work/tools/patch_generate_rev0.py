"""One-shot patch for system/apple_ii/scripts/generate_rev0.py (CRLF file)."""
from pathlib import Path

path = Path("system/apple_ii/scripts/generate_rev0.py")
text = path.read_text()

pairs = [
(
"""ROOT = Path(__file__).resolve().parents[1]


def generate():
    document = json.loads((ROOT/'board/rev0_connectivity.json').read_text())
    models = json.loads((ROOT/'board/models.json').read_text())
    components = document['components']""",
"""ROOT = Path(__file__).resolve().parents[1]
TIMING_FILE = ROOT / 'board/timing.json'


def load_timing(mode):
    \"\"\"Return the per-part propagation delay for every modelled package.

    Delays come from board/timing.json, whose entries cite manufacturer
    datasheets. Missing data is an error rather than a silent default: an
    unknown part must not quietly inherit another part's timing.
    \"\"\"
    table = json.loads(TIMING_FILE.read_text())
    key = {'typ': 'typ_ns', 'max': 'max_ns'}.get(mode)
    delays = {}
    for part, entry in table['parts'].items():
        if key is None:
            delays[part] = 0
            continue
        value = entry.get(key)
        if not isinstance(value, int):
            raise SystemExit(f\"timing.json: {part} has no integer {key} (mode {mode})\")
        delays[part] = value
    return delays


def generate(timing_mode='typ'):
    document = json.loads((ROOT/'board/rev0_connectivity.json').read_text())
    models = json.loads((ROOT/'board/models.json').read_text())
    delays = load_timing(timing_mode)
    components = document['components']""",
),
(
"""        model=models[c['part']]
        parameters=' #(.T_PD(5ns))'
        if c['part']=='4116':parameters=' #(.T_PD(20ns))'
        if c['part']=='ROM_Chip':parameters=f' #(.T_PD(5ns), .ROM_FILE(ROM_{ref.split("-")[-1]}))'
        if c['part']=='2513':parameters=' #(.T_PD(5ns), .ROM_FILE(CHAR_ROM))'""",
"""        model=models[c['part']]
        if c['part'] not in delays:raise SystemExit(f\"timing.json: no delay for {c['part']} ({ref})\")
        tpd=delays[c['part']]
        parameters=f' #(.T_PD({tpd}))'
        if c['part']=='ROM_Chip':parameters=f' #(.T_PD({tpd}), .ROM_FILE(ROM_{ref.split("-")[-1]}))'
        if c['part']=='2513':parameters=f' #(.T_PD({tpd}), .ROM_FILE(CHAR_ROM))'""",
),
(
"""        boundary_packages=['H7: CPU socket','B3: flash timer','H13: paddle timers','K13: cassette amplifier'],
        status='Digital connectivity experiment; mixed-signal/full-board sign-off pending.')""",
"""        boundary_packages=['H7: CPU socket','B3: flash timer','H13: paddle timers','K13: cassette amplifier'],
        timing=dict(mode=timing_mode,units='ns',table='board/timing.json',
            part_delays={p:delays[p] for p in sorted({c['part'] for c in components.values() if c['part'] in models})}),
        status='Digital connectivity experiment; mixed-signal/full-board sign-off pending.')""",
),
(
"""def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check',action='store_true')
    args=parser.parse_args()
    sv,metadata=generate()
    outputs=[(ROOT/'src/apple_ii_rev0_digital.sv',sv),(ROOT/'board/rev0_generated.json',metadata)]
    for path,data in outputs:
        if args.check:
            if not path.exists() or path.read_text()!=data:raise SystemExit(f'Stale generated file: {path}')
        else:
            path.parent.mkdir(parents=True,exist_ok=True)
            path.write_text(data,encoding='utf-8',newline='\\n')
    print('Revision-0 digital wiring generated from manifest.' if not args.check else 'Generated wiring matches manifest.')""",
"""def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check',action='store_true')
    parser.add_argument('--timing',choices=['typ','max','zero'],default='typ',
        help='per-part propagation delay set from board/timing.json')
    parser.add_argument('--out-src',help='write generated RTL here instead of src/')
    parser.add_argument('--out-json',help='write generated metadata here instead of board/')
    args=parser.parse_args()
    sv,metadata=generate(args.timing)
    outputs=[(Path(args.out_src) if args.out_src else ROOT/'src/apple_ii_rev0_digital.sv',sv),
             (Path(args.out_json) if args.out_json else ROOT/'board/rev0_generated.json',metadata)]
    for path,data in outputs:
        if args.check:
            if not path.exists() or path.read_text()!=data:raise SystemExit(f'Stale generated file: {path}')
        else:
            path.parent.mkdir(parents=True,exist_ok=True)
            path.write_text(data,encoding='utf-8',newline='\\n')
    print('Generated wiring matches manifest.' if args.check
          else f'Revision-0 digital wiring generated from manifest ({args.timing} timing).')""",
),
]

for old, new in pairs:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"expected one match, found {count}:\n{old[:80]}")
    text = text.replace(old, new)

path.write_text(text, newline="\r\n")
print("patched", path)
