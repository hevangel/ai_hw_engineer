#!/usr/bin/env python3
"""Temporary-fixture tests for CPU runner cache fingerprints and locking."""

import json
import copy
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import time
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_runner


def fixture_toolchain(verilator_version='Verilator fixture 1.0',
                      compiler_version='C++ fixture 1.0'):
    return {
        'verilator': {
            'command': ['fake-verilator'],
            'version': verilator_version,
        },
        'compiler': {
            'command': ['fake-c++'],
            'version': compiler_version,
        },
    }


class BuildRunnerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.base = Path(self.temp.name)
        self.root = self.base / 'design'
        self.work = self.root / 'work/sim'
        (self.root / 'src/nested').mkdir(parents=True)
        (self.root / 'tb/nested').mkdir(parents=True)
        (self.root / 'src/core.sv').write_text('module cpu; endmodule\n')
        (self.root / 'src/nested/types.svh').write_text('localparam X = 1;\n')
        (self.root / 'src/nested/glue.v').write_text('module glue; endmodule\n')
        (self.root / 'tb/bootstrap.cpp').write_text('int main() { return 0; }\n')
        (self.root / 'tb/nested/contracts.h').write_text('#define CONTRACT 1\n')
        (self.root / 'tb/nested/unlinked_fixture.cpp').write_text('int fixture;\n')
        self.calls = []
        self.build_environments = []

    def tearDown(self):
        self.temp.cleanup()

    def fake_builder(self, command, **kwargs):
        self.calls.append(list(command))
        self.build_environments.append(dict(kwargs.get('env', {})))
        output_dir = Path(command[command.index('--Mdir') + 1])
        output_dir.mkdir(parents=True, exist_ok=True)
        (output_dir / build_runner.BINARY_NAME).write_bytes(b'fake checked CPU runner')
        return subprocess.CompletedProcess(command, 0, 'fake build passed\n', '')

    def build(self, **kwargs):
        return build_runner.build_or_reuse(
            self.root, self.work, runner=self.fake_builder,
            toolchain=fixture_toolchain(), environment={}, **kwargs)

    def test_matching_fingerprint_reuses_binary_and_atomic_manifest(self):
        first = self.build()
        second = self.build()

        self.assertFalse(first.reused)
        self.assertTrue(second.reused)
        self.assertEqual(first.fingerprint, second.fingerprint)
        self.assertEqual(len(self.calls), 1)
        manifest_path = self.work / build_runner.MANIFEST_NAME
        manifest = json.loads(manifest_path.read_text())
        self.assertEqual(manifest['fingerprint'], first.fingerprint)
        self.assertEqual(manifest['binary'], build_runner.BINARY_NAME)
        self.assertIn('-Wall', manifest['build_plan']['command'])
        self.assertEqual(manifest['build_plan']['environment']['MAKEFLAGS'], '-B')
        self.assertEqual(manifest['build_plan']['make_policy']['forced_makeflags'], ['-B'])
        self.assertIn('-B', self.build_environments[0]['MAKEFLAGS'].split())
        self.assertEqual(list(self.work.glob('*.tmp')), [])

    def test_make_always_rebuilds_when_content_changes_with_restored_mtime(self):
        self.build()
        source = self.root / 'tb/nested/contracts.h'
        original_stat = source.stat()
        source.write_text(source.read_text() + '// content changed\n')
        os.utime(source, ns=(original_stat.st_atime_ns, original_stat.st_mtime_ns))

        rebuilt = self.build()

        self.assertFalse(rebuilt.reused)
        self.assertEqual(len(self.calls), 2)
        self.assertEqual(self.build_environments[-1]['MAKEFLAGS'], '-B')

    def test_recursive_rtl_and_testbench_files_invalidate_cache(self):
        first = self.build()
        files = (
            self.root / 'src/core.sv',
            self.root / 'src/nested/types.svh',
            self.root / 'src/nested/glue.v',
            self.root / 'tb/nested/contracts.h',
            self.root / 'tb/nested/unlinked_fixture.cpp',
        )
        for index, path in enumerate(files, start=1):
            path.write_text(path.read_text() + f'// change {index}\n')
            updated = self.build()
            with self.subTest(path=path.relative_to(self.root)):
                self.assertFalse(updated.reused)
                self.assertNotEqual(first.fingerprint, updated.fingerprint)
                self.assertEqual(len(self.calls), index + 1)
            first = updated

    def test_tool_versions_and_exact_flags_invalidate_cache(self):
        first = self.build()
        newer_toolchain = fixture_toolchain(compiler_version='C++ fixture 2.0')
        second = build_runner.build_or_reuse(
            self.root, self.work, runner=self.fake_builder,
            toolchain=newer_toolchain, environment={})
        third = build_runner.build_or_reuse(
            self.root, self.work, runner=self.fake_builder,
            toolchain=newer_toolchain,
            flags=(*build_runner.BUILD_FLAGS, '--trace'), environment={})

        self.assertFalse(first.reused)
        self.assertFalse(second.reused)
        self.assertFalse(third.reused)
        self.assertEqual(len(self.calls), 3)
        self.assertIn('--trace', self.calls[-1])

    def test_missing_or_modified_binary_invalidates_manifest(self):
        self.build()
        binary = self.work / build_runner.BINARY_NAME
        binary.unlink()
        rebuilt_missing = self.build()
        self.assertFalse(rebuilt_missing.reused)

        binary.write_bytes(b'externally modified')
        rebuilt_modified = self.build()
        self.assertFalse(rebuilt_modified.reused)
        self.assertEqual(len(self.calls), 3)

    def test_failed_build_removes_old_manifest_and_cannot_bless_stale_binary(self):
        self.build()
        source = self.root / 'src/core.sv'
        source.write_text(source.read_text() + '// changed\n')

        def failed_builder(command, **kwargs):
            return subprocess.CompletedProcess(command, 1, '', 'fixture compile error')

        with self.assertRaisesRegex(RuntimeError, 'exit code 1'):
            build_runner.build_or_reuse(
                self.root, self.work, runner=failed_builder,
                toolchain=fixture_toolchain(), environment={})
        manifest_path = self.work / build_runner.MANIFEST_NAME
        self.assertFalse(manifest_path.exists())
        self.assertFalse((self.work / build_runner.BINARY_NAME).exists())

        rebuilt = self.build()
        self.assertFalse(rebuilt.reused)
        self.assertTrue(manifest_path.is_file())
        self.assertEqual(len(self.calls), 2)

    def test_success_without_binary_does_not_write_manifest(self):
        self.work.mkdir(parents=True)
        old_binary = self.work / build_runner.BINARY_NAME
        old_binary.write_bytes(b'preexisting executable must not be blessed')

        def missing_binary_builder(command, **kwargs):
            self.assertFalse(old_binary.exists())
            return subprocess.CompletedProcess(command, 0, 'no binary', '')

        with self.assertRaisesRegex(RuntimeError, 'did not produce'):
            build_runner.build_or_reuse(
                self.root, self.work, runner=missing_binary_builder,
                toolchain=fixture_toolchain(), environment={})
        self.assertFalse((self.work / build_runner.MANIFEST_NAME).exists())
        self.assertFalse(old_binary.exists())

    def test_source_change_during_build_discards_binary_without_manifest(self):
        source = self.root / 'src/core.sv'

        def editing_builder(command, **kwargs):
            result = self.fake_builder(command, **kwargs)
            source.write_text(source.read_text() + '// edited during build\n')
            return result

        with self.assertRaisesRegex(RuntimeError, 'inputs changed during the build'):
            build_runner.build_or_reuse(
                self.root, self.work, runner=editing_builder,
                toolchain=fixture_toolchain(), environment={})

        self.assertFalse((self.work / build_runner.MANIFEST_NAME).exists())
        self.assertFalse((self.work / build_runner.BINARY_NAME).exists())

    @unittest.skipUnless(os.name == 'posix', 'process-group cleanup is POSIX-specific')
    def test_timeout_kills_builder_descendants_before_lock_release(self):
        marker = self.base / 'late-child-write'
        child_code = (
            'import time; from pathlib import Path; '
            f'time.sleep(0.4); Path({str(marker)!r}).write_text("late")'
        )
        parent_code = (
            'import subprocess, sys, time; '
            f'subprocess.Popen([sys.executable, "-c", {child_code!r}]); '
            'time.sleep(10)'
        )
        command = [sys.executable, '-c', parent_code]
        lock_path = self.work / build_runner.LOCK_NAME

        with build_runner._build_lock(lock_path):
            with self.assertRaises(subprocess.TimeoutExpired):
                build_runner._run_builder_process(
                    command, cwd=self.base, env=os.environ.copy(), timeout=0.1)

        # Reacquiring proves the timed-out build released its lock. A surviving
        # child would write after this point if process-group cleanup failed.
        with build_runner._build_lock(lock_path):
            pass
        time.sleep(0.6)
        self.assertFalse(marker.exists(), 'builder descendant wrote after lock release')

    def test_tool_version_change_during_build_discards_binary(self):
        versions = [fixture_toolchain()]

        def provider(_environment):
            return copy.deepcopy(versions[0])

        def changing_tool_builder(command, **kwargs):
            result = self.fake_builder(command, **kwargs)
            versions[0] = fixture_toolchain(verilator_version='Verilator fixture 2.0')
            return result

        with self.assertRaisesRegex(RuntimeError, 'inputs changed during the build'):
            build_runner.build_or_reuse(
                self.root, self.work, runner=changing_tool_builder,
                toolchain_provider=provider, environment={})

        self.assertFalse((self.work / build_runner.MANIFEST_NAME).exists())
        self.assertFalse((self.work / build_runner.BINARY_NAME).exists())

    def test_concurrent_calls_share_one_checked_build(self):
        build_count = 0
        active_builds = 0
        maximum_active = 0
        counter_lock = threading.Lock()

        def slow_builder(command, **kwargs):
            nonlocal build_count, active_builds, maximum_active
            with counter_lock:
                build_count += 1
                active_builds += 1
                maximum_active = max(maximum_active, active_builds)
            time.sleep(0.15)
            output_dir = Path(command[command.index('--Mdir') + 1])
            (output_dir / build_runner.BINARY_NAME).write_bytes(b'one build')
            with counter_lock:
                active_builds -= 1
            return subprocess.CompletedProcess(command, 0, '', '')

        results = []
        errors = []

        def run_one():
            try:
                results.append(build_runner.build_or_reuse(
                    self.root, self.work, runner=slow_builder,
                    toolchain=fixture_toolchain(), environment={}))
            except Exception as error:  # surface worker errors in the test thread
                errors.append(error)

        threads = [threading.Thread(target=run_one) for _ in range(2)]
        for thread in threads:
            thread.start()
        for thread in threads:
            thread.join(timeout=5)

        self.assertFalse(any(thread.is_alive() for thread in threads))
        self.assertEqual(errors, [])
        self.assertEqual(build_count, 1)
        self.assertEqual(maximum_active, 1)
        self.assertEqual(sorted(result.reused for result in results), [False, True])


if __name__ == '__main__':
    unittest.main()
