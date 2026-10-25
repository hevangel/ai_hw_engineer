"""Run every assembled hakanrw/mc6800 test on both the independent ISS and
the RTL testbench and compare the $2000-$20FF result windows byte-for-byte.

The oracle ISS (make_isa_vectors.py) executes each image first; its final
window is the expected result. The RTL window must match it. (Some tests
store computed data — including $FF bytes — into the window, so the old
"no $FF" heuristic was removed; the tests' own branch-based self-checks are
covered by the ISS semantics, which are PRM-sourced and separately gated by
the 197-opcode vector regression.) Exits nonzero on any failure.
"""
import subprocess
import sys
import importlib.util
from pathlib import Path

HERE = Path(__file__).resolve().parent
DESIGN_ROOT = HERE.parent
OUT_DIR = (DESIGN_ROOT / 'work' / 'third').resolve()
BIN = OUT_DIR / 'obj' / 'Vtb_thirdparty'
if DESIGN_ROOT not in OUT_DIR.parents:
    raise RuntimeError('path escapes the design tree')

_spec = importlib.util.spec_from_file_location(
    'm68iss', str(HERE / 'make_isa_vectors.py'))
m68iss = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(m68iss)


def run_iss(image):
    iss = m68iss.ISS()
    iss.mem = bytearray(image)
    iss.reset()
    last_pc, same, steps = None, 0, 0
    while steps < 5_000_000:
        iss.step()
        steps += 1
        if iss.pc == last_pc:
            same += 1
            if same >= 2:
                break
        else:
            same, last_pc = 0, iss.pc
    else:
        return None, None
    return iss.mem[0x2000:0x2100], iss.pc


def run_rtl(name):
    log = subprocess.run(
        [str(BIN), f'+image=work/third/{name}.hex'],
        cwd=str(DESIGN_ROOT), capture_output=True, text=True, timeout=600)
    text = log.stdout + log.stderr
    if 'TSELFLOOP' not in text:
        return None, text
    win_line = next(l for l in text.splitlines() if l.startswith('TWIN'))
    return [int(x, 16) for x in win_line.split()[1:]], text


def main():
    names = (OUT_DIR / 'manifest.txt').read_text().split()
    failures = []
    for name in names:
        image = bytes.fromhex(
            ''.join((OUT_DIR / f'{name}.hex').read_text().split()))
        exp_win, exp_pc = run_iss(image)
        if exp_win is None:
            failures.append(name)
            print(f'FAIL {name}: oracle did not reach a self-loop')
            continue
        rtl_win, text = run_rtl(name)
        if rtl_win is None:
            failures.append(name)
            print(f'FAIL {name}: RTL did not reach a self-loop')
            print(text[-300:])
            continue
        diff = [hex(0x2000 + i) for i, (a, b) in
                enumerate(zip(exp_win, rtl_win)) if a != b]
        if diff:
            failures.append(name)
            print(f'FAIL {name}: window mismatch at {diff[:8]} '
                  f'(iss={bytes(exp_win[:8]).hex()} '
                  f'rtl={bytes(rtl_win[:8]).hex()}...)')
            continue
        print(f'PASS {name}')
    print(f'third-party suite: {len(names) - len(failures)}/{len(names)} '
          f'passed')
    if failures:
        print('failed tests:', ' '.join(failures))
        sys.exit(1)


if __name__ == '__main__':
    main()
