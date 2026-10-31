#!/usr/bin/env python3
"""Import immutable physical-Harris-286 records; never generate expected ISA results."""
import argparse
import gzip
import hashlib
import json
from pathlib import Path
import urllib.request

from work_paths import get_work_root
ROOT = Path(__file__).resolve().parents[1]
WORK_ROOT = get_work_root(ROOT)
DEST = WORK_ROOT / 'hardware'
REVISION = '37c73caf53dcd22d3dd369ff09305d13d117a4fe'
BASE = f'https://raw.githubusercontent.com/SingleStepTests/80286/{REVISION}/'
# Git identities/sizes from the revision-pinned repository tree, not a mutable branch.
FILES = {
    'LICENSE': ('2b073398da738bdf76b9ccdc009e27ee060c8fab', 1070),
    'README.md': ('5635951f97d4a0f0947e2b13271ead6a6cb3b4ab', 25884),
    'revocation_list.txt': ('b589c24fa5316cad0899e8ceff310ab6f7f38991', 249),
    'v1_real_mode/04.MOO.gz': ('172b76dcb3d8ffaf6d6cbe8cbe7f63eff7752367', 821202),
    'v1_real_mode/05.MOO.gz': ('3dcb3727b5f20526f8b6d22f9368c94f18ce866d', 918281),
    'v1_real_mode/14.MOO.gz': ('bb3fc51d766cff5f80e2b9eefef05da64d741ea6', 822277),
    'v1_real_mode/15.MOO.gz': ('e99c64e9bb4d97ed953265fe1de612bc4da143d6', 919079),
    'v1_real_mode/1C.MOO.gz': ('aebecf509cbcb802cc50aa6ed224934eb7fc3dde', 822267),
    'v1_real_mode/1D.MOO.gz': ('83dbb7731217f96bb3f019da58704fcc1bb49f7d', 918805),
    'v1_real_mode/2C.MOO.gz': ('0bbd80d27343cfba0166a59fec749b7f4457892a', 821592),
    'v1_real_mode/2D.MOO.gz': ('59c89a6919f2a40f00e3be0ae6ff5611a7e62e40', 918402),
    'v1_real_mode/3C.MOO.gz': ('21af5e7f2e81ed84bbe17f18b7a97ee617bfc36a', 809378),
    'v1_real_mode/3D.MOO.gz': ('78635597f4e12c1b7b197b3aed47aedfc3e6a611', 907138),
    'v1_real_mode/40.MOO.gz': ('18833d1c0d651e280ca3edc613751d94ef341163', 152810),
    'v1_real_mode/41.MOO.gz': ('a70380e146c2e81651d33018473dc7cdeb924423', 153098),
    'v1_real_mode/42.MOO.gz': ('588880c7aca8ca34e7dd15b7da7315b095dbfd87', 152281),
    'v1_real_mode/43.MOO.gz': ('52c0772b562c3fac77bc96378edde77f13d9a7e2', 152545),
    'v1_real_mode/44.MOO.gz': ('79e8d855d005f16f65b5f5326f2f5442c4659f50', 152375),
    'v1_real_mode/45.MOO.gz': ('5cc14183c192e478fdf27416b00fb4674be57df9', 152930),
    'v1_real_mode/46.MOO.gz': ('777300e0502804c950455c38ddeb1652b0632019', 153045),
    'v1_real_mode/47.MOO.gz': ('3dc59c5ded54b3da57d7009d92713c3fbfe13425', 152509),
    'v1_real_mode/48.MOO.gz': ('68866a60e5a1ed075fa505f43fee49d6dda0b4ba', 152351),
    'v1_real_mode/49.MOO.gz': ('2c2ff4b44185b157a3079b80430f236c5ee67d35', 152824),
    'v1_real_mode/4A.MOO.gz': ('456a4a67a9246f9a9dd4f4e3adc6bbf48370242a', 152059),
    'v1_real_mode/4B.MOO.gz': ('517d97b6c65067a4f6773b05d1aed97657e35c99', 152025),
    'v1_real_mode/4C.MOO.gz': ('9f96a9b693534b850a6f01385373568e2fe6c76b', 152459),
    'v1_real_mode/4D.MOO.gz': ('c00daadd4557837b8c2e27b4814ac4ed7a970453', 152527),
    'v1_real_mode/4E.MOO.gz': ('ec4b7e46d981bca7bd0f936722caab86e6fc4e9c', 152250),
    'v1_real_mode/4F.MOO.gz': ('9a3ec3bf74c36e4a9483ad64f68fc6b32cc02fe1', 152227),
    'v1_real_mode/F6.1.MOO.gz': ('ebf477c0723b42ce7c0d80955075abe8b4798123', 1088023),
    'v1_real_mode/F7.1.MOO.gz': ('87bfd7537771ec2859f102ef9f8cceebd060ef7a', 1186630),
}
ARITHMETIC_IMMEDIATE_SIZES = {
    0x04: 1, 0x05: 2,  # ADD AL/AX, immediate
    0x14: 1, 0x15: 2,  # ADC AL/AX, immediate
    0x1c: 1, 0x1d: 2,  # SBB AL/AX, immediate
    0x2c: 1, 0x2d: 2,  # SUB AL/AX, immediate
    0x3c: 1, 0x3d: 2,  # CMP AL/AX, immediate
}
REGISTERS = ('ax','cx','dx','bx','sp','bp','si','di','es','cs','ss','ds','ip','flags')
# Intel Appendix B: the selected ADD/ADC/SBB/SUB/CMP forms define all arithmetic
# flags; INC/DEC define all except CF, which they preserve. Other named FLAGS are
# unchanged. Mask reserved FLAGS bits only.
FLAGS_MASK = 0x7fd7
TEST_ALIAS_FLAGS_MASK = 0x7fc7
INSTRUCTION_PREFIXES = (0x26, 0x2e, 0x36, 0x3e, 0xf0, 0xf2, 0xf3)


def flags_mask(opcode):
    """Return the externally defined status-bit mask for a selected opcode."""
    if opcode in (0xf6, 0xf7):
        # TEST defines CF/PF/ZF/SF/OF; AF is undefined and is not compared.
        return TEST_ALIAS_FLAGS_MASK
    return FLAGS_MASK


def _decode_encoding(code, filename):
    """Validate captured instruction + HLT bytes and return opcode/modrm.

    For TEST /1, decoding accepts every ModRM addressing mode so the importer
    can explicitly list memory/fault records outside the register adapter.
    The selected normalizer below narrows those records to mod=3.
    """
    if len(filename) < 2:
        raise ValueError(f'Unsupported physical opcode file: {filename}')
    try:
        opcode = int(filename[:2], 16)
    except ValueError as exc:
        raise ValueError(f'Unsupported physical opcode file: {filename}') from exc
    prefix = 0
    while prefix < len(code) and code[prefix] in INSTRUCTION_PREFIXES:
        prefix += 1
    if prefix >= len(code) or code[prefix] != opcode or code[-1] != 0xf4:
        raise ValueError(f'Unsupported encoding in selected physical file: {filename}: {bytes(code).hex()}')
    if opcode not in (0xf6, 0xf7) and any(
            byte in (0xf0, 0xf2, 0xf3) for byte in code[:prefix]):
        raise ValueError(f'Unsupported encoding in selected physical file: {filename}: {bytes(code).hex()}')

    if opcode in ARITHMETIC_IMMEDIATE_SIZES:
        operand_size = ARITHMETIC_IMMEDIATE_SIZES[opcode]
        expected_length = prefix + 1 + operand_size + 1
        modrm = None
    elif 0x40 <= opcode <= 0x4f:
        expected_length = prefix + 2
        modrm = None
    elif opcode in (0xf6, 0xf7):
        operand_size = 1 if opcode == 0xf6 else 2
        if len(code) < prefix + 2:
            raise ValueError(f'Unsupported encoding in selected physical file: {filename}: {bytes(code).hex()}')
        modrm = code[prefix + 1]
        if ((modrm >> 3) & 7) != 1:
            raise ValueError(f'Unsupported TEST group extension in {filename}: ModRM=0x{modrm:02X}')
        mod, rm = modrm >> 6, modrm & 7
        displacement_size = (2 if mod == 0 and rm == 6 else
                             1 if mod == 1 else
                             2 if mod == 2 else 0)
        expected_length = prefix + 1 + 1 + displacement_size + operand_size + 1
    else:
        raise ValueError(f'Unsupported physical opcode file: {filename}')

    if len(code) != expected_length:
        raise ValueError(f'Unsupported encoding in selected physical file: {filename}: {bytes(code).hex()}')
    return opcode, modrm


def fetch(path):
    blob, size = FILES[path]
    cached = DEST / Path(path).name
    if cached.exists():
        data = cached.read_bytes()
    else:
        with urllib.request.urlopen(BASE+path, timeout=90) as response:
            data = response.read(size+1)
    identity = hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
    if len(data) != size or identity != blob:
        raise ValueError(f'Pinned hardware artifact size/Git-blob mismatch: {path}')
    if not cached.exists():
        cached.write_bytes(data)
    return data, {'path':path, 'url':BASE+path, 'git_blob':blob, 'bytes':size,
                  'sha256':hashlib.sha256(data).hexdigest()}


def normalized(test, filename):
    initial = test['initial']['regs']
    if set(initial) != set(REGISTERS):
        raise ValueError(f'Incomplete physical initial register state: {filename}:{test["idx"]}')
    final = dict(initial)
    final.update(test['final']['regs'])
    if set(final) != set(REGISTERS):
        raise ValueError('Unexpected physical final register field')
    if initial['flags'] & 0x300:
        raise ValueError('Physical IF/TF case needs explicit interrupt/debug replay')
    if initial['flags'] & 0x7000:
        raise ValueError('Physical IOPL/NT case cannot be initialized through real-mode POPF')
    if test.get('exception'):
        raise ValueError('Selected register-only corpus unexpectedly contains an exception')
    if test['initial']['queue'] or test['final']['queue']:
        raise ValueError('Physical prefetch queue replay is not implemented')
    code = test['bytes']
    opcode, modrm = _decode_encoding(code, filename)
    if opcode in (0xf6, 0xf7) and (modrm is None or modrm >> 6 != 3):
        raise ValueError(f'TEST /1 memory form is outside the register-only adapter: {filename}:{test["idx"]}')
    if final['cs'] != initial['cs'] or final['ip'] != ((initial['ip']+len(code)) & 65535):
        raise ValueError('Physical non-flow record violates documented post-HLT PC accounting')
    initial_ram = dict(test['initial']['ram'])
    final_ram = dict(initial_ram)
    final_ram.update(test['final']['ram'])
    if final_ram != initial_ram:
        raise ValueError('Selected register-only physical record has unexpected memory changes')
    start = initial['cs']*16+initial['ip']
    for index, byte in enumerate(code):
        if initial_ram.get(start+index) != byte:
            raise ValueError('Physical encoded instruction differs from initial RAM')
    return initial, final, code, initial_ram, final_ram, opcode


def _test_alias_mode(test, filename):
    """Return a TEST /1 ModRM byte after validating its captured encoding."""
    code = test['bytes']
    opcode, modrm = _decode_encoding(code, filename)
    if opcode not in (0xf6, 0xf7) or modrm is None:
        raise ValueError(f'Expected a TEST /1 alias record in {filename}')
    return modrm


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--download-only', action='store_true')
    args = parser.parse_args()
    DEST.mkdir(parents=True, exist_ok=True)
    artifacts = {}
    payloads = {}
    for path in FILES:
        data, manifest = fetch(path)
        artifacts[path] = manifest
        payloads[path] = data
    (DEST / 'artifacts.json').write_text(json.dumps({'revision':REVISION,'artifacts':artifacts}, indent=2)+'\n')
    if args.download_only:
        print(f'PASS: {len(artifacts)} immutable physical-286 artifacts checked')
        return
    from hardware_moo import parse_moo
    revoked = set()
    for line in payloads['revocation_list.txt'].decode().splitlines():
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        if len(line) != 40 or any(c not in '0123456789abcdef' for c in line):
            raise ValueError('Malformed pinned physical-test revocation')
        revoked.add(line)
    cases = []
    excluded = []
    coverage_exclusions = []
    inventory = []
    initial_cf_histogram = {}
    opcode_flag_masks = {}
    per_file_counts = {}
    for path, data in payloads.items():
        if not path.endswith('.MOO.gz'):
            continue
        image = parse_moo(gzip.decompress(data))
        inventory.append({'file':path,'cpu':image['cpu'],'version':image['version'],
                          'records':len(image['tests'])})
        cf_counts = {'CF0':0, 'CF1':0}
        file_counts = {'selected':0, 'revoked':0, 'coverage_excluded':0}
        filename = Path(path).name
        opcode = int(filename[:2], 16)
        for test in image['tests']:
            label = f'{Path(path).name}:{test["idx"]}:{test["hash"]}'
            if test['hash'] in revoked:
                excluded.append({'case':label,'reason':'upstream revoked physical capture'})
                file_counts['revoked'] += 1
                continue
            modrm = None
            if opcode in (0xf6, 0xf7):
                modrm = _test_alias_mode(test, filename)
                if modrm >> 6 != 3 or test.get('exception'):
                    coverage_exclusions.append({
                        'case':label,
                        'reason':'memory/fault replay outside register adapter',
                        'modrm':f'0x{modrm:02X}',
                        'mod':modrm >> 6,
                        'form':'register' if modrm >> 6 == 3 else 'memory',
                        'exception':test.get('exception'),
                    })
                    file_counts['coverage_excluded'] += 1
                    continue
            initial, final, code, initial_ram, final_ram, opcode = normalized(test, filename)
            cf_counts['CF1' if initial['flags'] & 1 else 'CF0'] += 1
            file_counts['selected'] += 1
            opcode_flag_masks[f'{opcode:02X}'] = hex(flags_mask(opcode))
            cases.append((label, initial, final, code, initial_ram, final_ram,
                          opcode, flags_mask(opcode)))
        if sum(file_counts.values()) != len(image['tests']):
            raise ValueError(f'Physical record accounting mismatch in {path}: {file_counts}')
        if not cf_counts['CF0'] or not cf_counts['CF1']:
            raise ValueError(f'Physical initial-CF coverage missing in {path}: {cf_counts}')
        initial_cf_histogram[path] = cf_counts
        per_file_counts[path] = file_counts
    with (DEST / 'vectors.txt').open('w') as output:
        for label, initial, final, code, initial_ram, final_ram, opcode, mask in cases:
            output.write(f'HWCASE {label} {bytes(code).hex()} {opcode:x} {mask:x}\n')
            for tag, regs in (('INITIAL',initial),('FINAL',final)):
                output.write(tag+' '+ ' '.join(f'{regs[key]:x}' for key in REGISTERS)+'\n')
            for tag, memory in (('RAM_INITIAL',initial_ram),('RAM_FINAL',final_ram)):
                output.write(f'{tag} {len(memory):x}')
                for address, byte in sorted(memory.items()):
                    output.write(f' {address:x} {byte:x}')
                output.write('\n')
            output.write('END\n')
    manifest = {'revision':REVISION,'scope':'Physical real-mode ADD/ADC/SBB/SUB/CMP AL/AX immediate, INC/DEC GPR opcodes 40h..4Fh, and physical TEST aliases F6/F7 /1 register forms; functional architectural replay, no native-cycle claim',
                'inventory':inventory,'cases':len(cases),'excluded':excluded,'revocations':sorted(revoked),
                'coverage_exclusions':coverage_exclusions,
                'coverage_exclusion_counts':{
                    'total':len(coverage_exclusions),
                    'reason':'memory/fault replay outside register adapter',
                    'by_file':{path:counts['coverage_excluded'] for path,counts in per_file_counts.items()},
                },
                'record_accounting':per_file_counts,
                'initial_cf_histogram':initial_cf_histogram,
                'flags_mask':hex(FLAGS_MASK),
                'opcode_flag_masks':opcode_flag_masks,
                'vector_sha256':hashlib.sha256((DEST/'vectors.txt').read_bytes()).hexdigest(),
                'artifacts':artifacts}
    (DEST / 'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(f'PASS: imported {len(cases)} immutable physical-286 records; '
          f'{len(excluded)} revoked and {len(coverage_exclusions)} out-of-adapter records explicitly excluded')


if __name__ == '__main__':
    main()
