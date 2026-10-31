from pathlib import Path
import json
import tempfile
import unittest

from preflight import inspect, property_counts


class PreflightTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'formal').mkdir()
        (self.root / 'scripts').mkdir()
        self.props = self.root / 'formal/cpu_props.sv'
        self.props.write_text('assert(a); assume(b); cover(c); // assert(fake);\n')
        (self.root / 'formal/property_inventory.json').write_text(json.dumps({
            'formal/cpu_props.sv': {'assert': 1, 'assume': 1, 'cover': 1}}))
        (self.root / 'formal/cpu.sby').write_text('[files]\ncpu_props.sv\n')
        (self.root / 'scripts/run_all.sh').write_text('python3 "$SCRIPT_DIR/check.py"\n')
        self.check = self.root / 'scripts/check.py'
        self.check.write_text('print("check")\n')

    def test_valid(self):
        self.assertEqual(inspect(self.root), [])

    def test_truncated_properties(self):
        self.props.write_text('')
        self.assertTrue(any('empty property' in e for e in inspect(self.root)))

    def test_deleted_cover(self):
        self.props.write_text('assert(a); assume(b);')
        self.assertTrue(any('inventory changed' in e for e in inspect(self.root)))

    def test_missing_dependency(self):
        self.check.unlink()
        self.assertTrue(any('dependency check.py' in e for e in inspect(self.root)))

    def test_comments_cannot_supply_obligations(self):
        self.assertEqual(property_counts('// assert(a);\n/* cover(c); */ assume(b);'),
                         {'assert': 0, 'assume': 1, 'cover': 0})

    def test_missing_inventory(self):
        (self.root / 'formal/property_inventory.json').unlink()
        self.assertTrue(inspect(self.root))


if __name__ == '__main__':
    unittest.main()
