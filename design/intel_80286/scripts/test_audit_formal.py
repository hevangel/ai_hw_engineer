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
        results = self.results()
        self.assertEqual([result['result'] for result in results], ['PASS'] * 4)

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
                            {'name': 'cpu_cover',
                             'attributes': {'src': 'formal/intel_80286_props.sv:11.5-11.20'},
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

    def results(self):
        return audit(self.design, self.work, self.core_work)

    def test_cpu_checks_pass_for_every_formal_task(self):
        results = self.results()
        self.assertEqual([result['result'] for result in results], ['PASS'] * 3)
        for result in results:
            self.assertEqual(result['core_properties'], {'assert': 1, 'cover': 1})

    def test_component_checks_do_not_satisfy_cpu_inventory(self):
        model = json.loads(json.dumps(self.base_model))
        model['modules'][0]['cell_sorts'][0]['cells'] = [
            cell for cell in model['modules'][0]['cell_sorts'][0]['cells']
            if cell['parameters']['FLAVOR'] == 'cover']
        self.write_evidence(model)
        for result in self.results():
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
                            for result in self.results()))

    def test_model_without_cpu_module_fails_closed(self):
        self.write_evidence({'modules': [self.base_model['modules'][1]]})
        self.assertTrue(all(result['result'] == 'FAIL' and
                            any('expected one intel_80286 module' in error
                                for error in result['errors'])
                            for result in self.results()))


if __name__ == '__main__':
    unittest.main()
