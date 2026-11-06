#!/usr/bin/env python3
"""Measure how Surver (the Surfer waveform server) copes with large VCD files.

Run inside the tools image. For each requested size the script generates a
deterministic VCD of 64 signals (scalar and vector), starts `surver`, waits for
the body to load, queries the status endpoint and records load time, peak
resident memory and the reported byte counts. Results are measurements for the
pinned build in the pinned container, not guaranteed limits.
"""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import subprocess
import sys
import time
import urllib.request

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--work-dir', default='scratchpad/surfer-limits')
parser.add_argument('--sizes-mb', default='10,100,400')
parser.add_argument('--port', type=int, default=18095)
args = parser.parse_args()
work = Path(args.work_dir).resolve()
work.mkdir(parents=True, exist_ok=True)
TOKEN = 'limits-token-1'
SIGNALS = 64


def write_vcd(path, target_bytes):
    with path.open('w', encoding='ascii', newline='\n') as out:
        out.write('$timescale 1ps $end\n$scope module tb $end\n')
        for index in range(SIGNALS):
            width = 1 if index < 32 else 16
            out.write(f'$var wire {width} s{index} sig{index} $end\n')
        out.write('$upscope $end\n$enddefinitions $end\n')
        written, time_step, state = 0, 0, 1
        while written < target_bytes:
            state = (state * 1103515245 + 12345) & 0x7fffffff
            time_step += 1 + (state & 7)
            chunk = [f'#{time_step}\n']
            for index in range(SIGNALS):
                if (state >> (index % 24)) & 3 == 0:
                    value = (state ^ (index * 2654435761)) & 0xffff
                    if index < 32:
                        chunk.append(f'{value & 1}s{index}\n')
                    else:
                        chunk.append(f'b{value:b} s{index}\n')
            text = ''.join(chunk)
            out.write(text)
            written += len(text)


def peak_rss_kb(pid):
    try:
        for line in Path(f'/proc/{pid}/status').read_text().splitlines():
            if line.startswith('VmHWM:'):
                return int(line.split()[1])
    except OSError:
        return None


records = []
for size_mb in [int(item) for item in args.sizes_mb.split(',')]:
    vcd = work / f'limits_{size_mb}mb.vcd'
    write_vcd(vcd, size_mb * 1024 * 1024)
    log = work / f'surver_{size_mb}mb.log'
    started = time.monotonic()
    with log.open('w') as handle:
        process = subprocess.Popen(['surver', '--port', str(args.port), '--token', TOKEN, str(vcd)],
                                   stdout=handle, stderr=subprocess.STDOUT, cwd=work)
    status, loaded_seconds, peak = None, None, 0
    try:
        deadline = started + 900
        while time.monotonic() < deadline and process.poll() is None:
            peak = max(peak, peak_rss_kb(process.pid) or 0)
            try:
                with urllib.request.urlopen(f'http://127.0.0.1:{args.port}/{TOKEN}/get_status', timeout=5) as response:
                    status = json.loads(response.read())
                info = status['file_infos'][0]
                if info.get('bytes') and info.get('bytes_loaded', 0) >= info['bytes']:
                    loaded_seconds = time.monotonic() - started
                    break
            except Exception:
                pass
            time.sleep(0.5)
        peak = max(peak, peak_rss_kb(process.pid) or 0)
    finally:
        process.terminate()
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill()
    text = log.read_text(errors='replace')
    text = re.sub(r'\x1b\[[0-9;]*m', '', text)
    records.append(dict(sizeMb=size_mb, fileBytes=vcd.stat().st_size, signals=SIGNALS,
                        loaded=loaded_seconds is not None,
                        loadSeconds=None if loaded_seconds is None else round(loaded_seconds, 2),
                        peakRssMb=round(peak / 1024, 1),
                        reportedBytes=(status or {}).get('file_infos', [{}])[0].get('bytes'),
                        reportedBytesLoaded=(status or {}).get('file_infos', [{}])[0].get('bytes_loaded'),
                        logTail=text.strip().splitlines()[-2:]))
    print(f"{size_mb} MB: loaded={records[-1]['loaded']} load={records[-1]['loadSeconds']}s peakRSS={records[-1]['peakRssMb']} MB", flush=True)
    vcd.unlink()

summary = dict(recordedAt=datetime.now(timezone.utc).isoformat(), tool='surver', measurements=records,
               passed=all(item['loaded'] for item in records))
(work / 'results.json').write_text(json.dumps(summary, indent=2) + '\n', encoding='utf-8')
print('Results:', work / 'results.json')
sys.exit(0 if summary['passed'] else 1)
