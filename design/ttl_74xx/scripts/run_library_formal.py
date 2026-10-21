#!/usr/bin/env python3
"""Run the independent classic TTL family contracts, including all covers."""
import concurrent.futures
import json
from pathlib import Path
import subprocess
import sys

root=Path(__file__).resolve().parents[1]
families=('truth','counter','memory','fifo','shift')


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
    return {'family':family,'task':task,'passed':passed,'status':status,'log':str(log.relative_to(root))}


with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    results=list(pool.map(run,[(family,task) for family in families for task in ('check','cover')]))
(root/'work/formal/library_results.json').write_text(json.dumps(results,indent=2)+'\n')
for result in results:
    if not result['passed']:
        print((root/result['log']).read_text()[-4000:])
sys.exit(int(any(not result['passed'] for result in results)))
