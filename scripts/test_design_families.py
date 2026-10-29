"""Check canonical family/member structure and static design source references."""
import json
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = json.loads((ROOT / 'scripts/design_families.json').read_text(encoding='utf-8'))

class DesignFamilyTests(unittest.TestCase):
    def test_family_indexes_and_member_readmes(self):
        for family, members in MANIFEST['families'].items():
            self.assertTrue((ROOT / 'design' / family / 'README.md').is_file(), family)
            for member in members:
                self.assertTrue((ROOT / 'design' / family / member / 'README.md').is_file(), member)

    def test_old_roots_are_gone_and_destinations_exist(self):
        for old, new in MANIFEST['moves'].items():
            self.assertFalse((ROOT / old).exists(), old)
            self.assertTrue((ROOT / new / 'README.md').is_file(), new)

    def test_catalog_member_profiles(self):
        for catalog, members in MANIFEST.get('catalogs', {}).items():
            self.assertTrue((ROOT / 'design' / catalog / 'README.md').is_file(), catalog)
            for member in members:
                self.assertTrue((ROOT / 'design' / catalog / 'members' / member / 'README.md').is_file(), member)

    def test_static_design_source_references_resolve(self):
        for top in ['design', 'system', 'scripts']:
            for path in (ROOT / top).rglob('*'):
                if not path.is_file() or 'work' in path.relative_to(ROOT).parts or path.suffix not in ['.sh', '.py', '.sv', '.sby', '.ys']:
                    continue
                for source in re.findall(r'(?<![\w])design/[A-Za-z0-9_./-]+\.(?:sv|py|sh|sby)', path.read_text(encoding='utf-8')):
                    self.assertTrue((ROOT / source).is_file(), f'{path.relative_to(ROOT)}: {source}')

    def test_am2911_shared_formal_sources_resolve(self):
        path = ROOT / 'design/amd_am29xx/amd_am2911/formal/amd_am2911.sby'
        files = path.read_text(encoding='utf-8').split('[files]', 1)[1]
        for source in files.splitlines():
            source = source.strip()
            if source:
                self.assertTrue((path.parent / source).is_file(), source)

if __name__ == '__main__':
    unittest.main()
