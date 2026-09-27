#!/usr/bin/env python3
"""Replay the manual JSON through the simulator bridge, with no browser required."""
import argparse
import json
from pathlib import Path
import re
import time
import urllib.request

DEFAULT = Path(__file__).resolve().parents[1] / 'spec/reference/Unicom_141P_examples.json'

def decode_row(cells):
    value = ''.join(cells[:15]).strip()
    a, b = cells[16:18]
    text = (a + b).replace(' ', '')
    symbols = {'×':'*op', '÷':'/', '−':'-', '◇':'ST', 'Ex':'EX', '√':'SQRT'}
    rounded = '^' in text
    text = text.replace('^', '')
    symbol = symbols.get(text, text)
    if re.fullmatch(r'\.{14,15}', value):
        value, symbol = None, 'overflow'
    return {'value':value, 'symbol':symbol, 'red':bool(cells[18]), 'rounded':rounded}

class Panel:
    def __init__(self, url, timeout):
        self.url, self.timeout = url.rstrip('/'), timeout
        self.rows = {}
    def request(self, path, data=None):
        req = urllib.request.Request(self.url+path,
            data=None if data is None else json.dumps(data).encode(),
            headers={'Content-Type':'application/json'})
        with urllib.request.urlopen(req, timeout=10) as response:
            result = json.load(response)
        if data is not None and result.get('ok') is not True:
            raise RuntimeError(f'{path} rejected: {result}')
        return result
    def idle(self):
        deadline = time.monotonic()+self.timeout
        last_error = None
        while time.monotonic() < deadline:
            try:
                state = self.request('/state.json')
                if 'paper_sequence' not in state:
                    raise RuntimeError('Rebuild the bridge: paper_sequence is missing')
                for index, cells in enumerate(state['paper']):
                    row = decode_row(cells)
                    if row['value'] or row['symbol']:
                        self.rows[state['paper_sequence']-6+index] = row
                if state.get('ready') and not state['busy']:
                    return state
            except (OSError, ValueError) as error:
                last_error = str(error)
            time.sleep(.05)
        raise TimeoutError(f'4004 did not become idle within {self.timeout}s; {last_error or "busy"}')
    def press(self, key, codes):
        self.request('/press', {'code':codes[key]})
        return self.idle()

def validate(doc):
    if doc.get('schema_version') != 1:
        raise ValueError('Unsupported schema_version')
    ids = set()
    if not doc.get('examples'): raise ValueError('No examples to replay')
    if any(type(code) is not int or not 129 <= code <= 160 for code in doc['key_codes'].values()):
        raise ValueError('Invalid physical key code')
    for example in doc['examples']:
        if example['id'] in ids: raise ValueError('Duplicate example ID')
        ids.add(example['id'])
        for step in [{'keys':example['setup_keys'], 'switches':example['switches']}] + example['steps']:
            for key in step.get('keys', []):
                if key not in doc['key_codes']: raise ValueError(f'Unknown key {key}')
            for key, value in step.get('switches', {}).items():
                if key not in ('precision','rounding') or value not in (
                    [0,1,2,3,4,5,6,8] if key=='precision' else [0,1,8]):
                    raise ValueError('Invalid switch setting')
            expectations = [step.get('expect',{})] + list(step.get('expect_profiles',{}).values())
            for expected in expectations:
                for row in expected.get('tape',[]):
                    if set(row) != {'value','symbol','red','rounded'}:
                        raise ValueError('Incomplete tape expectation')
                    if (row['value'] is not None and not isinstance(row['value'],str)) or \
                       not isinstance(row['symbol'],str) or \
                       type(row['red']) is not bool or type(row['rounded']) is not bool:
                        raise ValueError('Tape values must retain exact strings and boolean flags')
                for lamp,value in expected.get('lamps',{}).items():
                    if lamp not in ('memory','overflow','negative') or type(value) is not bool:
                        raise ValueError('Invalid lamp expectation')
    return doc

def run(panel, doc, example, profile='manual'):
    state = panel.idle()
    panel.request('/switches', example['switches'])
    for key in example['setup_keys']: state = panel.press(key, doc['key_codes'])
    start = max(panel.rows, default=-1)
    checkpoints = []
    for index, step in enumerate(example['steps']):
        before = max(panel.rows, default=-1)
        if 'switches' in step: panel.request('/switches', step['switches'])
        for key in step.get('keys',[]): state = panel.press(key, doc['key_codes'])
        actual = [r for k,r in sorted(panel.rows.items()) if k>before]
        expected = step.get('expect_profiles',{}).get(profile, step.get('expect',{}))
        errors = []
        if 'tape' in expected and actual[-len(expected['tape']):] != expected['tape']:
            errors.append({'expected_tape':expected['tape'],'actual_tape':actual})
        for lamp, value in expected.get('lamps',{}).items():
            if bool(state['lamps'][lamp]) != value:
                errors.append({'lamp':lamp,'expected':value,'actual':state['lamps'][lamp]})
        checkpoints.append({'step':index+1,'errors':errors})
    return {'id':example['id'],'status':'FAIL' if any(c['errors'] for c in checkpoints) else 'PASS',
            'checkpoints':checkpoints,'tape':[r for k,r in sorted(panel.rows.items()) if k>start]}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('json',nargs='?',type=Path,default=DEFAULT)
    parser.add_argument('--url',default='http://127.0.0.1:8080')
    parser.add_argument('--only',help='Comma-separated example IDs')
    parser.add_argument('--profile',choices=['manual','recovered-rom'],default='manual',
                        help='manual preserves scan answers; recovered-rom uses documented independent-oracle differences')
    parser.add_argument('--timeout',type=float,default=300)
    parser.add_argument('--validate',action='store_true',help='Validate data without running a simulator')
    parser.add_argument('--report',type=Path,default=Path('manual-results.json'))
    args = parser.parse_args()
    doc = validate(json.loads(args.json.read_text(encoding='utf-8')))
    if args.validate:
        print(f'Valid: {len(doc["examples"])} examples'); return 0
    selected = set(args.only.split(',')) if args.only else {e['id'] for e in doc['examples']}
    unknown = selected - {e['id'] for e in doc['examples']}
    if unknown: parser.error(f'Unknown examples: {sorted(unknown)}')
    panel = Panel(args.url,args.timeout)
    results = []
    for example in doc['examples']:
        if example['id'] not in selected: continue
        print(f'RUN {example["id"]}: {example["title"]}',flush=True)
        try: result = run(panel,doc,example,args.profile)
        except (OSError,RuntimeError,TimeoutError,ValueError) as error:
            result = {'id':example['id'],'status':'ERROR','error':str(error)}
        results.append(result)
        print(f'{result["status"]} {example["id"]}',flush=True)
        args.report.parent.mkdir(parents=True,exist_ok=True)
        args.report.write_text(json.dumps({'source':doc['source'],'profile':args.profile,
            'url':args.url,'results':results},indent=2)+'\n',encoding='utf-8')
        if result['status']=='ERROR': break # never queue more into a stalled machine
    return int(any(r['status']!='PASS' for r in results) or len(results)!=len(selected))

if __name__ == '__main__': raise SystemExit(main())
