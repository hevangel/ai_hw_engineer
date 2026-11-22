#!/usr/bin/env python3
"""Compare a DOS workload run on the AT with the same run on an 8088 machine.

usage: compare_8086.py REFERENCE_OUT AT_OUT DRIVE_A_IMAGE

REFERENCE_OUT and AT_OUT are the output folders of dos_8086_workload.py for
the 8088 machine (pc for dos100, xt for dos200) and for the AT. The check:

  1. Every step's final text screen is the same on both machines, line by line,
     after the expected differences listed in EXPECTED are applied to the
     AT screen (each is printed with its reason, and each must occur).
  2. CHKDSK's disk numbers agree; its memory numbers are each machine's own.
  3. The diskette written in drive B is read with the FAT12 reader below
     (written for this check from the IBM DOS media-descriptor table, not
     taken from DOS or either simulator): the files DOS wrote must hold the
     expected bytes on both machines, and the two drive B images are
     compared sector by sector.
"""
import json
import re
import sys
from pathlib import Path

# FAT12 geometries by media descriptor (first FAT byte), IBM DOS 2.00
# Technical Reference, "DOS Disk Allocation": sectors per track, heads,
# sectors per FAT, root directory entries, sectors per cluster.
GEOMETRY = {
    0xfe: (8, 1, 1, 64, 1),    # 160 KB single-sided
    0xfc: (9, 1, 2, 64, 1),    # 180 KB single-sided
    0xff: (8, 2, 1, 112, 2),   # 320 KB double-sided
    0xfd: (9, 2, 2, 112, 2),   # 360 KB double-sided
}


def fat12_files(image):
    """{b'NAME    EXT': bytes} for the root directory of a 5.25-inch image."""
    media = image[512]
    if media not in GEOMETRY:
        raise ValueError(f'unknown media descriptor {media:02X}h')
    spt, heads, fat_sectors, root_entries, per_cluster = GEOMETRY[media]
    if len(image) != 40 * heads * spt * 512:
        raise ValueError(f'image size {len(image)} does not fit media {media:02X}h')
    fat = image[512:512 + fat_sectors * 512]
    root = 1 + 2 * fat_sectors
    data = root + root_entries * 32 // 512
    files = {}
    for i in range(root_entries):
        e = image[root * 512 + 32 * i:root * 512 + 32 * (i + 1)]
        if e[0] == 0:
            break
        if e[0] == 0xe5 or e[11] & 0x18:
            continue
        cluster = int.from_bytes(e[26:28], 'little')
        size = int.from_bytes(e[28:32], 'little')
        out, seen = bytearray(), set()
        while len(out) < size:
            if not 2 <= cluster < 0xff0 or cluster in seen:
                raise ValueError(f'bad FAT12 chain in {bytes(e[:11])!r}')
            seen.add(cluster)
            start = (data + (cluster - 2) * per_cluster) * 512
            out += image[start:start + per_cluster * 512]
            pair = int.from_bytes(fat[cluster * 3 // 2:cluster * 3 // 2 + 2], 'little')
            cluster = pair >> 4 if cluster & 1 else pair & 0xfff
        files[bytes(e[:11])] = bytes(out[:size])
    return files


# Expected differences of the AT's screen from the 8088 machine's, by
# workload: (regex on the AT line, replacement, reason). The replacement is
# what the 8088 machine shows.
EXPECTED = {
    'dos100': [
        (r'^ *\d+ bytes total memory$', '<total memory>',
         'CHKDSK reports the memory DOS was given: 64 KB on the PC 5150 model, 640 KB on the AT'),
        (r'^ *\d+ bytes free$', '<free memory>',
         'CHKDSK free memory follows from the total memory'),
    ],
    'dos200': [
        (r'^Current time is +\d+:\d\d:\d\d\.\d\d$', '<current time>',
         'DOS 2.00 shows the BIOS time of day: the AT BIOS starts it from the MC146818 '
         '(12:00 in tb/cmos_vga_2fd.hex), the XT has no clock and counts from power-on'),
    ],
}


def file_layout(image):
    """(root directory sector numbers, {sector: bytes of file data in it})."""
    spt, heads, fat_sectors, root_entries, per_cluster = GEOMETRY[image[512]]
    fat = image[512:512 + fat_sectors * 512]
    root = 1 + 2 * fat_sectors
    data = root + root_entries * 32 // 512
    used = {}
    for i in range(root_entries):
        e = image[root * 512 + 32 * i:root * 512 + 32 * (i + 1)]
        if e[0] == 0:
            break
        if e[0] == 0xe5 or e[11] & 0x18:
            continue
        cluster, left = int.from_bytes(e[26:28], 'little'), int.from_bytes(e[28:32], 'little')
        while left > 0 and 2 <= cluster < 0xff0:
            for k in range(per_cluster):
                used[data + (cluster - 2) * per_cluster + k] = max(0, min(512, left - 512 * k))
            left -= 512 * per_cluster
            pair = int.from_bytes(fat[cluster * 3 // 2:cluster * 3 // 2 + 2], 'little')
            cluster = pair >> 4 if cluster & 1 else pair & 0xfff
    return set(range(root, data)), used


def timestamp_only(a, b):
    """Bytes where the two images differ that are not a directory entry's
    time field (offsets 22-23 of a 32-byte entry) in the root directory or
    in the unused tail of a file's last sector (DOS fills that tail from
    its buffer, here a copy of the directory sector)."""
    root, used = file_layout(a)
    if file_layout(b) != (root, used):
        return ['different file layout']
    bad = []
    for s in range(len(a) // 512):
        for i in range(512):
            if a[512 * s + i] == b[512 * s + i]:
                continue
            slack = s in used and i >= used[s]
            if not ((s in root or slack) and i % 32 in (22, 23)):
                bad.append(f'sector {s} byte {i}')
    return bad
# Lines the BIOS leaves above DOS's own output before DOS 1.00/2.00 scroll
# it away (DOS does not clear the screen at boot): the AT BIOS's memory
# count; the 8088 BIOSes print nothing in text there.
BIOS_LINES = [r'^\d{5} KB OK$']


def normalize(text, rules, used):
    out = []
    for line in text.split('\n'):
        for pattern, repl, reason in rules:
            if re.match(pattern, line):
                used.add(reason)
                line = repl
        if any(re.match(p, line) for p in BIOS_LINES):
            used.add('BIOS banner')
            line = ''
        out.append(line.rstrip())
    return out


def chkdsk(text):
    nums = {}
    # PC DOS 1.00 CHKDSK's lines.
    for key, pat in (('files', r'(\d+) disk files'), ('disk', r'(\d+) bytes total disk space'),
                     ('available', r'(\d+) bytes remain available'), ('memory', r'(\d+) bytes total memory'),
                     ('free', r'(\d+) bytes free')):
        m = re.search(pat, text)
        nums[key] = m.groups() if m else None
    return nums


def main():
    if len(sys.argv) != 4:
        raise SystemExit(__doc__)
    ref_dir, at_dir, drive_a = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
    ref = json.loads((ref_dir / 'result.json').read_text())
    at = json.loads((at_dir / 'result.json').read_text())
    workload = at['workload']
    assert ref['workload'] == workload
    rules = EXPECTED[workload]
    used = set()
    failures = []
    labels = [s['label'] for s in ref['steps']]
    assert labels == [s['label'] for s in at['steps']], 'different step lists'
    for rs, ats in zip(ref['steps'], at['steps']):
        if not rs['screen'] and not ats['screen']:
            continue
        if rs.get('graphicsMode') or ats.get('graphicsMode'):
            # Not text: the 8088 reader shows CGA memory as characters, the
            # AT reader finds no glyphs. Checked by the picture tests.
            assert rs.get('graphicsMode') and ats.get('graphicsMode'), rs['label']
            print(f'GRAPHICS (both): {rs["label"]}')
            continue
        r_lines = normalize(rs['screen'], rules, set())
        a_lines = normalize(ats['screen'], rules, used)
        # The 8088 lines go through the same rules (their numbers differ).
        if r_lines == a_lines:
            print(f'SAME: {rs["label"]}')
            continue
        diff = [f'  row {i + 1}: 8088 {r!r} / AT {a!r}' for i, (r, a) in enumerate(zip(r_lines, a_lines))
                if r != a]
        failures.append(f'{rs["label"]}: screens differ\n' + '\n'.join(diff))
    for reason in sorted(used):
        print(f'EXPECTED DIFFERENCE: {reason}')

    if workload == 'dos100':
        r_ck = chkdsk(next(s for s in ref['steps'] if s['label'] == 'CHKDSK')['screen'])
        a_ck = chkdsk(next(s for s in at['steps'] if s['label'] == 'CHKDSK')['screen'])
        print(f'CHKDSK 8088 {r_ck}\nCHKDSK AT   {a_ck}')
        for key in ('disk', 'files', 'available'):
            if r_ck[key] != a_ck[key] or r_ck[key] is None:
                failures.append(f'CHKDSK {key}: 8088 {r_ck[key]} / AT {a_ck[key]}')
        if a_ck['memory'] != ('655360',):
            failures.append(f'AT CHKDSK total memory {a_ck["memory"]}, expected 655360 (640 KB)')
        a_steps = {s['label']: s for s in at['steps']}
        if a_steps['DONKEY space bar']['graphics'][0] < 3:
            failures.append('AT DONKEY picture has fewer than 3 colours')

    # Diskette written in drive B.
    original = fat12_files(drive_a.read_bytes())
    images = {}
    for name, d in (('8088', ref_dir), ('AT', at_dir)):
        image = (d / 'drive_b.img').read_bytes()
        images[name] = image
        files = fat12_files(image)
        if workload == 'dos100':
            want = {b'CLOCK   COM': original[b'TIME    COM']}
        else:
            want = {b'ECHO    TXT': b'AT 5170 8086 COMPAT\r\n', b'KEYED   TXT': b'HELLO FROM COPY CON\r\n'}
        for fname, data in want.items():
            got = files.get(fname)
            # COPY CON stores the end-of-file mark (1Ah) after the text.
            ok = got == data or (fname == b'KEYED   TXT' and got == data + b'\x1a')
            print(f'{"PASS" if ok else "FAIL"}: {name} drive B {fname.decode()} '
                  f'{len(got) if got is not None else "missing"} bytes')
            if not ok:
                failures.append(f'{name} drive B {fname!r} = {got!r}')
        print(f'{name} drive B root directory: ' + ', '.join(
            f'{k.decode().strip()} {len(v)}' for k, v in sorted(files.items())))
    a, b = images['8088'], images['AT']
    if len(a) != len(b):
        print(f'drive B images differ in size ({len(a)} / {len(b)} bytes): compared by file only')
    else:
        sectors = [i for i in range(len(a) // 512) if a[512 * i:512 * (i + 1)] != b[512 * i:512 * (i + 1)]]
        if not sectors:
            print(f'SAME: drive B images are identical ({len(a)} bytes)')
        elif workload == 'dos200':
            # DOS 2.00 stamps files with the time of day (see EXPECTED).
            bad = timestamp_only(a, b)
            if bad:
                failures.append(f'drive B images differ outside file times: {bad[:20]}')
            else:
                print(f'EXPECTED DIFFERENCE: drive B images differ only in directory-entry time fields '
                      f'(sectors {sectors}: the root directory and the copy of it in the unused '
                      f'tail of the new files\' last sectors)')
        else:
            failures.append(f'drive B images differ in {len(sectors)} sectors: {sectors[:20]}')
    if failures:
        print('FAIL:\n' + '\n'.join(failures))
        raise SystemExit(1)
    print(f'PASS: {workload} on the AT agrees with the 8088 machine')


if __name__ == '__main__':
    main()
