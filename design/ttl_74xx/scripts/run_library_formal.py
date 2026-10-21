#!/usr/bin/env python3
"""Run the independent classic TTL family contracts, including all covers."""
import concurrent.futures
import hashlib
import json
from pathlib import Path
import subprocess
import sys

root=Path(__file__).resolve().parents[1]
families=tuple(json.loads((root/'formal/library_families.json').read_text()))


def source_digest(family):
    config=root/f'formal/ttl_{family}.sby'
    paths=[config,Path(__file__).resolve()]
    in_files=False
    for raw in config.read_text().splitlines():
        line=raw.strip()
        if line.startswith('['):
            in_files=line=='[files]'
            continue
        if in_files and line and not line.startswith('#'):
            paths.append((root/'formal'/line).resolve())
    return hashlib.sha256(b''.join(path.read_bytes() for path in paths)).hexdigest()


def run(job):
    family,task=job
    directory=root/f'work/formal/library_{family}_{task}'
    directory.parent.mkdir(parents=True,exist_ok=True)
    log=directory.parent/f'library_{family}_{task}.log'
    with log.open('w') as output:
        try:
            result=subprocess.run(['sby','-f','-d',str(directory),f'ttl_{family}.sby',task],
                cwd=root/'formal',stdout=output,stderr=subprocess.STDOUT,timeout=300,check=False)
            status=(directory/'status').read_text().split()[0] if (directory/'status').exists() else 'MISSING'
            passed=result.returncode==0 and status=='PASS'
        except subprocess.TimeoutExpired:
            output.write('\nERROR: formal task timed out\n')
            passed=False;status='TIMEOUT'
    print(f'{"PASS" if passed else "FAIL"} formal {family} {task}',flush=True)
    return {'family':family,'task':task,'passed':passed,'status':status,'source_digest':source_digest(family),'log':str(log.relative_to(root))}


def main():
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        results=list(pool.map(run,[(family,task) for family in families for task in ('check','cover')]))
    (root/'work/formal/library_results.json').write_text(json.dumps(results,indent=2)+'\n')
    for result in results:
        if not result['passed']:
            print((root/result['log']).read_text()[-4000:])
    sys.exit(int(any(not result['passed'] for result in results)))


if __name__=='__main__':
    main()
