#!/usr/bin/env python3
"""Reproduce the 12.0-3 VPI packaging defect using hash-pinned source archives.

Run inside the original Icarus overlay (headers/libraries/compiler installed).
Configure and generate only the VPI helper; no full simulator build/install.
All source extraction and generated files stay in the requested work directory.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tarfile

HASHES = {
    'upstream': 'a68cb1ef7c017ef090ebedb2bc3e39ef90ecc70a3400afb4aa94303bc3beaa7d',
    'debian': '73472c6695debcddd8f8efe2439aee0493de89916fa8f562c1ddf9faaaeaa8da',
}
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--upstream-tar', required=True)
parser.add_argument('--debian-tar', required=True)
parser.add_argument('--work-dir', required=True)
parser.add_argument('--report', required=True)
args = parser.parse_args()
work = Path(args.work_dir).resolve()
if work.exists() and any(work.iterdir()):
    parser.error('work-dir must be absent or empty to preserve previous evidence')
work.mkdir(parents=True, exist_ok=True)
for name, filename in [('upstream', args.upstream_tar), ('debian', args.debian_tar)]:
    archive = Path(filename)
    if hashlib.sha256(archive.read_bytes()).hexdigest() != HASHES[name]:
        raise ValueError('Source archive hash mismatch: '+name)
    with tarfile.open(archive) as stream:
        stream.extractall(work, filter='data')
source = work / 'iverilog-12_0'
assert (source / 'Makefile.in').is_file()
package_patch = work / 'debian/patches/filter-out_iverilog-vpi_flags.patch'
fix = Path(__file__).resolve().parent / 'patches/iverilog-prefix-map-filter.patch'
old = '$(shell echo $(CFLAGS) | sed -e \'s/-ffile-prefix-map=.*\\.//\')'
assert old in package_patch.read_text(encoding='utf-8')

# Both maps are valid compiler options. The second has a dotted version suffix.
file_map = '-ffile-prefix-map=/build/reproducible-path/iverilog-12.0-3=.'
debug_map = '-fdebug-prefix-map=/build/reproducible-path/iverilog-12.0-3=/usr/src/iverilog-12.0-3'
flags = f'-g -O2 {file_map} -fstack-protector-strong -Wformat -Werror=format-security {debug_map}'
env = dict(os.environ, CFLAGS=flags, CXXFLAGS=flags)

def run(command, cwd, label, expected_failure=False, marker=None):
    result = subprocess.run(command, cwd=cwd, env=env, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120)
    (work / (label+'.log')).write_text(result.stdout, encoding='utf-8')
    passed = result.returncode != 0 if expected_failure else result.returncode == 0
    if marker:
        passed = passed and marker in result.stdout
    if not passed:
        raise RuntimeError(f'{label} failed qualification (exit {result.returncode}):\n{result.stdout[-3000:]}')
    return result

run(['autoconf'], source, 'autoconf')
run(['./configure', '--prefix=/usr'], source, 'configure')
results = []
for phase in ['upstream', 'debian', 'fixed']:
    if phase != 'upstream':
        selected = package_patch if phase == 'debian' else fix
        run(['patch', '--batch', '--fuzz=0', '-p1', '-i', str(selected)], source, phase+'-patch')
        run(['./config.status', 'Makefile'], source, phase+'-configure')
    helper = source / 'iverilog-vpi'
    if helper.exists():
        helper.unlink()
    run(['make', 'iverilog-vpi'], source, phase+'-make')
    phase_dir = work / 'helpers' / phase
    phase_dir.mkdir(parents=True)
    copy = phase_dir / 'iverilog-vpi'
    shutil.copy2(helper, copy)
    observed = {}
    for language, switch in [('c', '--cflags'), ('cpp', '--ccflags')]:
        observed[language] = run(['sh', str(copy), switch], phase_dir, phase+'-'+language+'-flags').stdout.strip()
        tokens = shlex.split(observed[language])
        if phase == 'debian':
            assert '0-3' in tokens, observed
            assert '-fstack-protector-strong' not in tokens, observed
        else:
            assert '0-3' not in tokens, observed
            assert '-fstack-protector-strong' in tokens, observed
            assert debug_map in tokens, observed
            assert (file_map in tokens) == (phase == 'upstream'), observed
        testcase = phase_dir / language
        testcase.mkdir()
        linkage = 'extern "C" {\n' if language == 'cpp' else ''
        end = '}\n' if language == 'cpp' else ''
        module = testcase / ('probe.'+('cpp' if language == 'cpp' else 'c'))
        module.write_text('#include <vpi_user.h>\n'+linkage+
            'static PLI_INT32 on_start(p_cb_data data) { (void)data; vpi_printf("VPI SOURCE PROBE PASS\\n"); return 0; }\n'
            'static void register_probe(void) { s_cb_data cb={0}; cb.reason=cbStartOfSimulation; cb.cb_rtn=on_start; vpi_register_cb(&cb); }\n'
            'void (*vlog_startup_routines[])(void)={register_probe,0};\n'+end, encoding='utf-8')
        built = run(['sh', str(copy), str(module)], testcase, phase+'-'+language+'-build',
                    expected_failure=phase=='debian', marker='0-3' if phase=='debian' else None)
        if phase != 'debian':
            testbench = testcase/'tb.v'
            testbench.write_text('module tb; initial begin #1; $finish; end endmodule\n',encoding='utf-8')
            run(['iverilog', '-o', 'tb.vvp', str(testbench)], testcase, phase+'-'+language+'-tb')
            loaded = run(['vvp', '-M', str(testcase), '-m', 'probe', 'tb.vvp'], testcase,
                         phase+'-'+language+'-load', marker='VPI SOURCE PROBE PASS')
        results.append({'phase': phase, 'language': language, 'flags': observed[language],
                        'buildExit': built.returncode, 'expectedFailure': phase=='debian',
                        'moduleLoadPassed': phase!='debian'})
        print(f'PASS {phase} {language}: '+('reproduced compiler failure' if phase=='debian' else 'compile and module load'), flush=True)
report = Path(args.report).resolve()
report.parent.mkdir(parents=True, exist_ok=True)
report.write_text(json.dumps({'archiveSha256': HASHES, 'controlledFlags': flags,
                             'cases': results, 'passed': True},indent=2)+'\n',encoding='utf-8')
print('Source-level reproduction passed; report:',report,flush=True)
