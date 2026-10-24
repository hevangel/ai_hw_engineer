"""Offline regression checks for toolchain update safety and synchronization."""

from contextlib import redirect_stderr, redirect_stdout
import hashlib
import io
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch
from urllib.error import HTTPError

import update_docker as updater


class UpdateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="toolchain test ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for path in ("Dockerfile", "README.md", "docs/toolchain-releases.md"):
            target = self.root / path
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(updater.ROOT / path, target)
        self.original = {p: p.read_bytes() for p in self.root.rglob("*") if p.is_file()}
        self.pins = {"XEZIM_REV": "a" * 40, "VERIBLE_SHA256": "b" * 64}
        self.rows = {"xezim": ("9.0.0, `" + "a" * 40 + "`", "https://example.org/release")}

    def run_update(self, args, discovery=None, branch="scripts/update-tools"):
        with (patch.object(updater, "ROOT", self.root),
              patch.object(updater, "discover", discovery or (lambda current: (self.pins, self.rows))),
              patch.object(updater.subprocess, "check_output", return_value=branch),
              patch.object(updater.subprocess, "run") as build,
              redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO())):
            updater.main(args)
        return build

    def assert_unchanged(self):
        for path, content in self.original.items():
            self.assertEqual(path.read_bytes(), content)

    def test_dry_run_writes_nothing_and_never_builds(self):
        self.run_update(["--dry-run"], branch="main").assert_not_called()
        self.assert_unchanged()

    def test_update_synchronizes_pins_and_docs_without_build(self):
        self.run_update(["--no-build"]).assert_not_called()
        dockerfile = (self.root / "Dockerfile").read_text()
        self.assertIn("ARG XEZIM_REV=" + "a" * 40, dockerfile)
        self.assertIn("ARG VERIBLE_SHA256=" + "b" * 64, dockerfile)
        for path in ("README.md", "docs/toolchain-releases.md"):
            self.assertIn("9.0.0", (self.root / path).read_text())
        before = updater.arguments(self.original[self.root / "Dockerfile"].decode())
        after = updater.arguments(dockerfile)
        for arg in ("UBUNTU_SNAPSHOT", "SBY_REV", "EQY_REV"):
            self.assertEqual(before[arg], after[arg])

    def test_default_builds_selected_tag(self):
        build = self.run_update(["--image", "local/toolchain:test"])
        build.assert_called_once_with(
            ["docker", "build", "--progress=plain", "-t", "local/toolchain:test", "."],
            cwd=self.root, check=True)

    def test_build_failure_propagates_and_leaves_reviewable_files(self):
        with patch.object(updater.subprocess, "run", side_effect=subprocess.CalledProcessError(1, "docker")):
            # run_update replaces run; exercise main directly for this failure.
            with (patch.object(updater, "ROOT", self.root),
                  patch.object(updater, "discover", return_value=(self.pins, self.rows)),
                  patch.object(updater.subprocess, "check_output", return_value="scripts/update-tools"),
                  redirect_stdout(io.StringIO())):
                with self.assertRaises(subprocess.CalledProcessError):
                    updater.main([])
        self.assertIn("9.0.0", (self.root / "README.md").read_text())

    def test_main_and_detached_head_cannot_write(self):
        for branch in ("main", "master", ""):
            with self.assertRaises(ValueError):
                self.run_update(["--no-build"], branch=branch)
        self.assert_unchanged()

    def test_network_failure_writes_nothing(self):
        def fail(current):
            raise HTTPError("https://example.org", 403, "rate limited", {}, None)
        with self.assertRaises(HTTPError):
            self.run_update(["--no-build"], discovery=fail)
        self.assert_unchanged()

    def test_document_layout_failure_writes_nothing(self):
        readme = self.root / "README.md"
        readme.write_text("Changed layout\n")
        self.original[readme] = readme.read_bytes()
        with self.assertRaises(ValueError):
            self.run_update(["--no-build"])
        self.assert_unchanged()

    def test_missing_or_duplicate_arg_rejected(self):
        for dockerfile in ("", "ARG XEZIM_REV=one\nARG XEZIM_REV=two\n"):
            with self.assertRaises(ValueError):
                updater.render(dockerfile, "", "", {"XEZIM_REV": "a" * 40}, {})

    def test_annotated_release_tag_is_peeled(self):
        with patch.object(updater, "get_json", side_effect=[
            {"object": {"type": "tag", "sha": "b" * 40}},
            {"object": {"type": "commit", "sha": "a" * 40}},
        ]):
            self.assertEqual(updater.commit_for_tag("owner/repo", "v1.0"), "a" * 40)

    def test_no_release_retains_snapshot_but_http_errors_fail(self):
        for code in (404, 403, 500):
            error = HTTPError("https://example.org", code, "error", {}, None)
            with patch.object(updater, "get_json", side_effect=error):
                if code == 404:
                    self.assertIsNone(updater.latest("YosysHQ/sby", optional=True))
                else:
                    with self.assertRaises(HTTPError):
                        updater.latest("YosysHQ/sby", optional=True)

    def test_prerelease_and_unsafe_tag_rejected(self):
        for release in ({"prerelease": True}, {"draft": True}, {"tag_name": "bad\nARG INJECT=1"}):
            with patch.object(updater, "get_json", return_value=release):
                with self.assertRaises(ValueError):
                    updater.latest("owner/repo")

    def test_missing_asset_and_checksum_mismatch_rejected(self):
        with self.assertRaises(ValueError):
            updater.asset({"assets": []}, "expected.zip")
        with patch.object(updater, "request", return_value=io.BytesIO(b"archive")):
            with self.assertRaises(ValueError):
                updater.archive_digest("https://example.org/archive", "sha256:" + "0" * 64)
        with patch.object(updater, "request", return_value=io.BytesIO(b"archive")):
            self.assertEqual(updater.archive_digest("https://example.org/archive"),
                             hashlib.sha256(b"archive").hexdigest())

    def test_verilator_uses_release_tag_on_stable_history(self):
        with patch.object(updater, "get_json", side_effect=[
            HTTPError("https://example.org", 404, "no releases", {}, None),
            [{"name": "v5.052"}, {"name": "v5.053-dev"}], [], {"status": "ahead"},
        ]):
            self.assertEqual(updater.latest("verilator/verilator")["tag_name"], "v5.052")


if __name__ == "__main__":
    unittest.main()
