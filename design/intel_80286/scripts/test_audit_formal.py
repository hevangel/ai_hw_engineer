#!/usr/bin/env python3
"""Exercise evidence rejection independently of expensive solver runs."""
from pathlib import Path
import tempfile
import unittest
import shutil
import json

from audit_formal import audit, sections, task_config


class EvidenceAuditTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.design = Path(self.temp.name)
        (self.design / 'formal').mkdir()
        (self.design / 'src').mkdir()
        self.source = self.design / 'src/example.sv'
        self.source.write_text('module example; endmodule\n')
        self.config = self.design / 'formal/example.sby'
        self.config.write_text('[tasks]\nbmc\nprove\ncover\n[options]\n'
                               'bmc: mode bmc\nprove: mode prove\ncover: mode cover\n'
                               'depth 2\n[engines]\nsmtbmc z3\n[script]\n'
                               'read -formal example.sv\nprep -top example\n'
                               '[files]\n../src/example.sv\n')
        self.work = self.design / 'work'
        for task in ('bmc', 'prove', 'cover'):
            run = self.work / f'example_{task}'
            (run / 'src').mkdir(parents=True)
            (run / 'src/example.sv').write_bytes(self.source.read_bytes())
            (run / 'status').write_text('PASS 0 1\n')
            (run / 'PASS').write_text('saved result\n')
            resolved = task_config(sections(self.config), task)
            (run / 'config.sby').write_text('\n'.join(
                f'[{name}]\n' + '\n'.join(lines) for name, lines in resolved.items()))

    def results(self):
        return audit(self.design, self.work)

    def test_matching_evidence(self):
        self.assertEqual([r['result'] for r in self.results()], ['PASS'] * 3)

    def test_changed_source_invalidates_every_task(self):
        self.source.write_text('module example; logic changed; endmodule\n')
        self.assertTrue(all(any('stale source' in e for e in r['errors'])
                            for r in self.results()))

    def test_matching_empty_source_and_snapshot_rejected(self):
        self.source.write_text('')
        for task in ('bmc', 'prove', 'cover'):
            (self.work / f'example_{task}/src/example.sv').write_text('')
        self.assertTrue(all(any('empty source' in e for e in r['errors'])
                            for r in self.results()))

    def test_changed_configuration_invalidates_every_task(self):
        self.config.write_text(self.config.read_text().replace('depth 2', 'depth 3'))
        self.assertTrue(all(any('configuration differs' in e for e in r['errors'])
                            for r in self.results()))

    def test_cover_is_mandatory(self):
        (self.work / 'example_cover/status').unlink()
        self.assertEqual([r['result'] for r in self.results()], ['PASS', 'PASS', 'FAIL'])

    def test_fail_or_incomplete_status_rejected(self):
        (self.work / 'example_bmc/status').write_text('FAIL 1 1\n')
        (self.work / 'example_prove/PASS').unlink()
        self.assertEqual([r['result'] for r in self.results()], ['FAIL', 'FAIL', 'PASS'])

    def test_missing_snapshot_rejected(self):
        (self.work / 'example_cover/src/example.sv').unlink()
        self.assertEqual(self.results()[2]['result'], 'FAIL')

    def test_unsupported_syntax_fails_closed(self):
        self.config.write_text(self.config.read_text().replace('../src/example.sv', '../src/*.sv'))
        with self.assertRaises(ValueError):
            self.results()

    def test_missing_task_fails_closed(self):
        self.config.write_text(self.config.read_text().replace('bmc\nprove\ncover', 'bmc\nprove'))
        with self.assertRaises(ValueError):
            self.results()

    def test_prove_only_pdr_configuration_is_supported(self):
        pdr_config = self.design / 'formal/intel_80286_pdr.sby'
        pdr_config.write_text('[tasks]\nprove\n[options]\nprove: mode prove\n'
                              '[engines]\nprove: abc pdr\n[script]\n'
                              'read -formal example.sv\nprep -top example\n'
                              '[files]\n../src/example.sv\n')
        run = self.work / 'intel_80286_pdr_prove'
        (run / 'src').mkdir(parents=True)
        (run / 'src/example.sv').write_bytes(self.source.read_bytes())
        (run / 'status').write_text('PASS 0 1\n')
        (run / 'PASS').write_text('saved result\n')
        resolved = task_config(sections(pdr_config), 'prove')
        (run / 'config.sby').write_text('\n'.join(
            f'[{name}]\n' + '\n'.join(lines) for name, lines in resolved.items()))
        # Default audit skips optional PDR; --require-pdr audits it.
        default_results = audit(self.design, self.work)
        self.assertEqual([result['result'] for result in default_results], ['PASS'] * 3)
        pdr_results = audit(self.design, self.work, require_pdr=True)
        self.assertEqual([result['result'] for result in pdr_results], ['PASS'] * 4)

    def test_separate_core_epoch_never_falls_back_to_old_results(self):
        (self.design / 'formal/intel_80286.sby').write_text(self.config.read_text())
        core_work = self.design / 'separate_core'
        for task in ('bmc', 'prove', 'cover'):
            shutil.copytree(self.work / f'example_{task}', core_work / f'intel_80286_{task}')
        self.assertTrue(all(r['result']=='PASS' for r in audit(self.design,self.work,core_work)))
        # A missing result in the requested epoch must fail even if another
        # epoch has a passing status for the same task.
        shutil.copytree(core_work / 'intel_80286_cover', self.work / 'intel_80286_cover')
        (core_work / 'intel_80286_cover/status').unlink()
        results = {r['task']:r for r in audit(self.design,self.work,core_work)}
        self.assertEqual(results['intel_80286_cover']['result'],'FAIL')
        self.assertEqual(results['example_cover']['result'],'PASS')


class CoreElaboratedPropertyAuditTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.design = Path(self.temp.name)
        (self.design / 'formal').mkdir()
        (self.design / 'src').mkdir()
        (self.design / 'src/intel_80286.sv').write_text('module intel_80286; endmodule\n')
        (self.design / 'formal/intel_80286_props.sv').write_text(
            '// Nonempty formal include with retained CPU checks.\n')
        self.config = self.design / 'formal/intel_80286.sby'
        self.config.write_text(
            '[tasks]\nbmc\nprove\ncover\n[options]\n'
            'bmc: mode bmc\nprove: mode prove\ncover: mode cover\n'
            'depth 2\n[engines]\nsmtbmc z3\n[script]\n'
            'read -formal -sv intel_80286.sv\nprep -top intel_80286\n'
            '[files]\n../src/intel_80286.sv\nintel_80286_props.sv\n')
        self.work = self.design / 'component_work'
        self.core_work = self.design / 'core_work'
        self.base_model = {
            'modules': [
                {
                    'name': 'intel_80286',
                    'cell_sorts': [{
                        'type': '$check',
                        'cells': [
                            {'name': 'cpu_assert',
                             'attributes': {'src': 'intel_80286_props.sv:10.5-10.20'},
                             'parameters': {'FLAVOR': 'assert'}},
                            {'name': 'cov_shallow_ex',
                             'attributes': {'src': 'formal/intel_80286_props.sv:11.5-11.20'},
                             'parameters': {'FLAVOR': 'cover'}},
                            {'name': 'cov_deep_ex',
                             'attributes': {'src': 'formal/intel_80286_props.sv:12.5-12.20'},
                             'parameters': {'FLAVOR': 'cover'}},
                        ],
                    }],
                },
                {
                    'name': 'intel_80286_access_check',
                    'cell_sorts': [{
                        'type': '$check',
                        'cells': [
                            {'name': 'component_assert',
                             'attributes': {'src': 'access_check_props.sv:4.5-4.20'},
                             'parameters': {'FLAVOR': 'assert'}},
                            {'name': 'component_cover',
                             'attributes': {'src': 'access_check_props.sv:5.5-5.20'},
                             'parameters': {'FLAVOR': 'cover'}},
                        ],
                    }],
                },
            ],
        }
        self.write_evidence(self.base_model)

    def write_evidence(self, model):
        for task in ('bmc', 'prove', 'cover'):
            run = self.core_work / f'intel_80286_{task}'
            (run / 'src').mkdir(parents=True, exist_ok=True)
            (run / 'src/intel_80286.sv').write_bytes(
                (self.design / 'src/intel_80286.sv').read_bytes())
            (run / 'src/intel_80286_props.sv').write_bytes(
                (self.design / 'formal/intel_80286_props.sv').read_bytes())
            (run / 'status').write_text('PASS 0 1\n')
            (run / 'PASS').write_text('saved result\n')
            resolved = task_config(sections(self.config), task)
            (run / 'config.sby').write_text('\n'.join(
                f'[{name}]\n' + '\n'.join(lines) for name, lines in resolved.items()))
            model_path = run / 'model/design.json'
            model_path.parent.mkdir(parents=True, exist_ok=True)
            model_path.write_text(json.dumps(model))
        (self.core_work / 'intel_80286_prove/model/design_smt2.smt2').write_text(
            '; yosys-smt2-assert 0 cpu_assert intel_80286_props.sv:10.5-10.20\n')
        (self.core_work / 'intel_80286_cover/logfile.txt').write_text(
            '## 0:00:01 Reached cover statement in step 1 at intel_80286: cov_shallow_ex\n')
        witness_dir = self.core_work / 'intel_80286_cover_witnesses'
        (witness_dir / 'src').mkdir(parents=True, exist_ok=True)
        (witness_dir / 'model').mkdir(parents=True, exist_ok=True)
        (witness_dir / 'src/intel_80286.sv').write_bytes(
            (self.design / 'src/intel_80286.sv').read_bytes())
        (witness_dir / 'src/intel_80286_props.sv').write_bytes(
            (self.design / 'formal/intel_80286_props.sv').read_bytes())
        (witness_dir / 'status').write_text('PASS 0 1\n')
        (witness_dir / 'PASS').write_text('verified\n')
        (witness_dir / 'model/sim_prep.il').write_text('# lowered RTLIL placeholder\n')
        (witness_dir / 'model/sim_prep_stat.json').write_text(json.dumps({
            'design': {
                'num_cells_by_type': {
                    '$assert': 1,
                    '$assume': 1,
                    '$cover': 2,
                },
            },
        }))
        group_dir = witness_dir / 'groups/deep_group'
        group_dir.mkdir(parents=True, exist_ok=True)
        (group_dir / 'witness.smtc').write_text(
            'state 0\n'
            'assume (= [rst_n] false)\n'
            'assume (= [bus_ready_i] false)\n'
            'assume (= [bus_rdata_i] #x0000)\n'
            'assume (= [intr_i] false)\n'
            'assume (= [nmi_i] false)\n'
            'assume (= [inta_ready_i] false)\n'
            'assume (= [inta_vector_i] #x00)\n'
            'assume (= [busy_i] false)\n'
            'assume (= [error_n_i] true)\n'
            'assume (= [pereq_i] false)\n\n'
            'state 1\n'
            'assume (= [rst_n] true)\n'
            'assume (= [bus_ready_i] true)\n'
            'assume (= [bus_rdata_i] #x0000)\n'
            'assume (= [intr_i] false)\n'
            'assume (= [nmi_i] false)\n'
            'assume (= [inta_ready_i] false)\n'
            'assume (= [inta_vector_i] #x00)\n'
            'assume (= [busy_i] false)\n'
            'assume (= [error_n_i] true)\n'
            'assume (= [pereq_i] false)\n'
        )
        port_order = [
            ('rst_n', 1), ('bus_ready_i', 1), ('bus_rdata_i', 16), ('intr_i', 1), ('nmi_i', 1),
            ('inta_ready_i', 1), ('inta_vector_i', 8), ('busy_i', 1), ('error_n_i', 1), ('pereq_i', 1),
        ]
        step0_vals = {
            'rst_n': '0', 'bus_ready_i': '0', 'bus_rdata_i': '0' * 16, 'intr_i': '0', 'nmi_i': '0',
            'inta_ready_i': '0', 'inta_vector_i': '0' * 8, 'busy_i': '0', 'error_n_i': '1', 'pereq_i': '0',
        }
        step1_vals = dict(step0_vals, rst_n='1', bus_ready_i='1')
        (group_dir / 'witness.yw').write_text(json.dumps({
            'format': 'Yosys Witness Trace',
            'generator': 'core_cover_witnesses',
            'clocks': [{'path': ['\\clk'], 'edge': 'posedge', 'offset': 0}],
            'signals': [
                {'path': [f'\\{name}'], 'width': width, 'offset': 0, 'init_only': False}
                for name, width in port_order
            ],
            'steps': [
                {'bits': ''.join(step0_vals[name] for name, _ in reversed(port_order))},
                {'bits': ''.join(step1_vals[name] for name, _ in reversed(port_order))},
            ],
        }))
        (group_dir / 'sim.ys').write_text(
            'read_rtlil model/sim_prep.il\n'
            'sim -q -assert -r groups/deep_group/witness.yw '
            '-summary groups/deep_group/summary.json intel_80286\n'
        )
        (group_dir / 'sim.log').write_text('End of script. Logfile hash: 000000\n')
        (group_dir / 'summary.json').write_text(json.dumps({
            'top': 'intel_80286',
            'steps': 1,
            'assertions': [
                {'step': 1, 'type': '$cover', 'path': ['\\cov_deep_ex']},
            ],
        }))
        (witness_dir / 'manifest.json').write_text(json.dumps({
            'engine': 'yosys-sim',
            'model_il': 'model/sim_prep.il',
            'model_stat': 'model/sim_prep_stat.json',
            'groups': [{
                'name': 'deep_group',
                'targets': ['cov_deep_ex'],
                'smtc': 'groups/deep_group/witness.smtc',
                'yw': 'groups/deep_group/witness.yw',
                'script': 'groups/deep_group/sim.ys',
                'log': 'groups/deep_group/sim.log',
                'summary': 'groups/deep_group/summary.json',
            }],
        }))

    def results(self):
        return audit(self.design, self.work, self.core_work)

    def test_cpu_checks_pass_for_every_formal_task(self):
        results = self.results()
        self.assertEqual([result['result'] for result in results], ['PASS'] * 4)
        for result in results[:3]:
            self.assertEqual(result['core_properties'], {'assert': 1, 'cover': 2})
        self.assertEqual(results[3]['core_covers_reached'], 2)
        self.assertEqual(results[3]['core_covers_total'], 2)

    def test_component_checks_do_not_satisfy_cpu_inventory(self):
        model = json.loads(json.dumps(self.base_model))
        model['modules'][0]['cell_sorts'][0]['cells'] = [
            cell for cell in model['modules'][0]['cell_sorts'][0]['cells']
            if cell['parameters']['FLAVOR'] == 'cover']
        self.write_evidence(model)
        for result in self.results()[:3]:
            self.assertEqual(result['result'], 'FAIL')
            self.assertTrue(any('no elaborated CPU assert cells' in error
                                for error in result['errors']))

    def test_cover_is_required_in_each_saved_task_model(self):
        model = json.loads(json.dumps(self.base_model))
        model['modules'][0]['cell_sorts'][0]['cells'] = [
            cell for cell in model['modules'][0]['cell_sorts'][0]['cells']
            if cell['parameters']['FLAVOR'] == 'assert']
        self.write_evidence(model)
        self.assertTrue(all(any('no elaborated CPU cover cells' in error
                                for error in result['errors'])
                            for result in self.results()))

    def test_every_bmc_prove_cover_artifact_is_required(self):
        for missing_task in ('bmc', 'prove', 'cover'):
            with self.subTest(task=missing_task):
                self.write_evidence(self.base_model)
                (self.core_work / f'intel_80286_{missing_task}/model/design.json').unlink()
                results = {result['task']: result for result in self.results()}
                self.assertEqual(results[f'intel_80286_{missing_task}']['result'], 'FAIL')
                self.assertTrue(any('elaborated core property inventory' in error
                                    for error in results[f'intel_80286_{missing_task}']['errors']))
                for task in ('bmc', 'prove', 'cover'):
                    if task != missing_task:
                        self.assertEqual(results[f'intel_80286_{task}']['result'], 'PASS')

    def test_matching_nonempty_include_without_core_checks_is_rejected(self):
        # A matching nonempty source and snapshot can still contain no active
        # assertion/cover cells. Only the CPU module's emitted checks count.
        source = self.design / 'formal/intel_80286_props.sv'
        source.write_text('// properties were accidentally removed\nlogic witness_only;\n')
        model = json.loads(json.dumps(self.base_model))
        model['modules'][0]['cell_sorts'][0]['cells'] = []
        self.write_evidence(model)
        self.assertTrue(all(result['result'] == 'FAIL' and
                            any('no elaborated CPU assert cells' in error
                                for error in result['errors'])
                            for result in self.results()[:3]))

    def test_model_without_cpu_module_fails_closed(self):
        self.write_evidence({'modules': [self.base_model['modules'][1]]})
        self.assertTrue(all(result['result'] == 'FAIL' and
                            any('expected one intel_80286 module' in error
                                for error in result['errors'])
                            for result in self.results()[:3]))

    def test_missing_core_cover_from_union_fails_closed(self):
        (self.core_work / 'intel_80286_cover/logfile.txt').write_text('## 0:00:01 Status: PASSED\n')
        results = {r['task']: r for r in self.results()}
        self.assertEqual(results['intel_80286_cover_witnesses']['result'], 'FAIL')
        self.assertTrue(any('missing core covers' in e
                            for e in results['intel_80286_cover_witnesses']['errors']))

    def test_witness_smtc_rejects_initial_or_internal_signal(self):
        smtc = self.core_work / 'intel_80286_cover_witnesses/groups/deep_group/witness.smtc'
        smtc.write_text('initial\nassume (= [state] #x00)\n')
        results = {r['task']: r for r in self.results()}
        self.assertEqual(results['intel_80286_cover_witnesses']['result'], 'FAIL')
        self.assertTrue(any('disallowed .smtc directive' in e
                            for e in results['intel_80286_cover_witnesses']['errors']))
        smtc.write_text('state 0\nassume (= [state] #x00)\n')
        results = {r['task']: r for r in self.results()}
        self.assertEqual(results['intel_80286_cover_witnesses']['result'], 'FAIL')
        self.assertTrue(any('non-primary-input constraint' in e
                            for e in results['intel_80286_cover_witnesses']['errors']))

    def test_witness_assert_failed_log_or_summary_rejected(self):
        log = self.core_work / 'intel_80286_cover_witnesses/groups/deep_group/sim.log'
        log.write_text('ERROR: Assertion intel_80286.foo failed.\nEnd of script.\n')
        results = {r['task']: r for r in self.results()}
        self.assertEqual(results['intel_80286_cover_witnesses']['result'], 'FAIL')
        self.assertTrue(any('assertion or assumption failure' in e
                            for e in results['intel_80286_cover_witnesses']['errors']))
        self.write_evidence(self.base_model)
        summary = self.core_work / 'intel_80286_cover_witnesses/groups/deep_group/summary.json'
        summary.write_text(json.dumps({
            'top': 'intel_80286',
            'steps': 1,
            'assertions': [
                {'step': 1, 'type': '$assert', 'path': ['\\foo']},
                {'step': 1, 'type': '$cover', 'path': ['\\cov_deep_ex']},
            ],
        }))
        results = {r['task']: r for r in self.results()}
        self.assertEqual(results['intel_80286_cover_witnesses']['result'], 'FAIL')
        self.assertTrue(any('non-cover failures' in e
                            for e in results['intel_80286_cover_witnesses']['errors']))

    def test_witness_yw_rejects_internal_signal_or_x_bits(self):
        yw = self.core_work / 'intel_80286_cover_witnesses/groups/deep_group/witness.yw'
        doc = json.loads(yw.read_text())
        bad_sig = json.loads(json.dumps(doc))
        bad_sig['signals'].append({'path': ['\\_witness_', '\\x'], 'width': 1, 'offset': 0, 'init_only': False})
        yw.write_text(json.dumps(bad_sig))
        results = {r['task']: r for r in self.results()}
        self.assertEqual(results['intel_80286_cover_witnesses']['result'], 'FAIL')
        self.assertTrue(any('non-primary-input signal path' in e
                            for e in results['intel_80286_cover_witnesses']['errors']))
        bad_bits = json.loads(json.dumps(doc))
        bad_bits['steps'][1]['bits'] = 'x' + bad_bits['steps'][1]['bits'][1:]
        yw.write_text(json.dumps(bad_bits))
        results = {r['task']: r for r in self.results()}
        self.assertEqual(results['intel_80286_cover_witnesses']['result'], 'FAIL')
        self.assertTrue(any('invalid or non-binary bits' in e
                            for e in results['intel_80286_cover_witnesses']['errors']))

    def test_witness_stripped_sim_model_assertions_rejected(self):
        stat = self.core_work / 'intel_80286_cover_witnesses/model/sim_prep_stat.json'
        stat.write_text(json.dumps({
            'design': {'num_cells_by_type': {'$assert': 0, '$assume': 1, '$cover': 2}},
        }))
        results = {r['task']: r for r in self.results()}
        self.assertEqual(results['intel_80286_cover_witnesses']['result'], 'FAIL')
        self.assertTrue(any('$assert count' in e
                            for e in results['intel_80286_cover_witnesses']['errors']))

    def test_witness_script_missing_assert_or_using_zinit_rejected(self):
        ys = self.core_work / 'intel_80286_cover_witnesses/groups/deep_group/sim.ys'
        ys.write_text('read_rtlil model/sim_prep.il\nsim -q -r groups/deep_group/witness.yw -summary groups/deep_group/summary.json intel_80286\n')
        results = {r['task']: r for r in self.results()}
        self.assertEqual(results['intel_80286_cover_witnesses']['result'], 'FAIL')
        self.assertTrue(any('missing sim -assert' in e
                            for e in results['intel_80286_cover_witnesses']['errors']))
        ys.write_text('read_rtlil model/sim_prep.il\nsim -q -zinit -assert -r groups/deep_group/witness.yw -summary groups/deep_group/summary.json intel_80286\n')
        results = {r['task']: r for r in self.results()}
        self.assertEqual(results['intel_80286_cover_witnesses']['result'], 'FAIL')
        self.assertTrue(any('-zinit' in e
                            for e in results['intel_80286_cover_witnesses']['errors']))

    def test_witness_stale_source_snapshot_rejected(self):
        (self.core_work / 'intel_80286_cover_witnesses/src/intel_80286.sv').write_text('module stale; endmodule\n')
        results = {r['task']: r for r in self.results()}
        self.assertEqual(results['intel_80286_cover_witnesses']['result'], 'FAIL')
        self.assertTrue(any('stale source snapshot' in e
                            for e in results['intel_80286_cover_witnesses']['errors']))


if __name__ == '__main__':
    unittest.main()
