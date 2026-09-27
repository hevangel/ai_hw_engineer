#!/usr/bin/env python3
"""Unit checks for the replay oracle; no calculator arithmetic is implemented."""
import copy
import json
import unittest
from replay_manual import DEFAULT, Panel, decode_row, run, validate
from check_reference import compare


def row(value='11', symbol='*', red=False, rounded=False):
    return dict(value=value, symbol=symbol, red=red, rounded=rounded)


class FakePanel:
    def __init__(self, printed, lamps=None):
        self.rows = {}
        self.printed = iter(printed)
        self.state = {'lamps': lamps or {'memory': False, 'overflow': False, 'negative': False}}
    def idle(self): return self.state
    def request(self, *_): return {'ok': True}
    def press(self, *_):
        self.rows[len(self.rows)] = next(self.printed)
        return self.state


class ReplayTests(unittest.TestCase):
    def setUp(self):
        self.doc = json.loads(DEFAULT.read_text(encoding='utf-8'))
        self.example = {'id':'unit','setup_keys':[], 'switches':{'precision':0,'rounding':0},
                        'steps':[{'keys':['1'],'expect':{'tape':[row()]}}]}

    def test_dataset_and_all_profiles_validate(self):
        self.assertEqual(len(validate(self.doc)['examples']), 42)

    def test_duplicate_lines_are_not_deduplicated(self):
        cells = list('             11') + [' ', ' ', '*', 0]
        empty = [' ']*18 + [0]
        panel = Panel('', 1)
        snapshots = iter({'paper_sequence': seq, 'paper':[empty]*6+[cells],
                          'ready':True,'busy':False} for seq in (1,2))
        panel.request = lambda _: next(snapshots)
        panel.idle(); panel.idle()
        self.assertEqual(list(panel.rows.values()), [row(),row()])

    def test_exact_precision_is_required(self):
        self.assertEqual(run(FakePanel([row('11.0')]),self.doc,self.example)['status'],'FAIL')

    def test_wrong_symbol_and_ink_fail(self):
        self.assertEqual(run(FakePanel([row(symbol='SQRT',red=True)]),self.doc,self.example)['status'],'FAIL')

    def test_profiles_are_explicit(self):
        self.example['steps'][0]['expect_profiles']={'recovered-rom':{'tape':[row('12')]}}
        self.assertEqual(run(FakePanel([row('12')]),self.doc,self.example)['status'],'FAIL')
        self.assertEqual(run(FakePanel([row('12')]),self.doc,self.example,'recovered-rom')['status'],'PASS')
        self.assertEqual(self.example['steps'][0]['expect']['tape'][0]['value'],'11')

    def test_lamp_mismatch_fails(self):
        self.example['steps'][0]['expect']['lamps']={'overflow':True}
        self.assertEqual(run(FakePanel([row()]),self.doc,self.example)['status'],'FAIL')

    def test_overflow_and_rounding_decoding(self):
        self.assertEqual(decode_row(['.']*15+[' ',' ',' ',1]),row(None,'overflow',True))
        self.assertEqual(decode_row(list('             11')+[' ','^','*',0]),row(rounded=True))

    def test_numeric_expectation_rejected(self):
        bad=copy.deepcopy(self.doc)
        bad['examples'][0]['steps'][0]['expect']['tape'][0]['value']=12.34
        with self.assertRaises(ValueError): validate(bad)

    def test_invalid_key_rejected(self):
        self.doc['key_codes']['1']=999
        with self.assertRaises(ValueError): validate(self.doc)

    def test_no_examples_cannot_pass(self):
        self.doc['examples']=[]
        with self.assertRaises(ValueError): validate(self.doc)

    def test_reference_trace_is_checked(self):
        trace = '#EXAMPLE unit\n#RESET\nROW|11| |*|false\n#STEP 0\nLAMPS|0\n'
        doc = {'examples':[self.example]}
        self.assertEqual(compare(trace,doc,'manual')[0]['status'],'PASS')
        self.assertEqual(compare(trace.replace('ROW|11','ROW|12'),doc,'manual')[0]['status'],'FAIL')

    def test_incomplete_reference_trace_cannot_pass(self):
        with self.assertRaises(RuntimeError):
            compare('#EXAMPLE unit\n#RESET\n',{'examples':[self.example]},'manual')


if __name__ == '__main__': unittest.main()
