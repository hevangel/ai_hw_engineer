"""Offline safety and response-validation checks for the documentation updater."""

from contextlib import redirect_stderr, redirect_stdout
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import update_tool_docs as updater


class ToolDocsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="tool docs test ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        folder = self.root / "docs" / "verilator"
        folder.mkdir(parents=True)
        self.guide = folder / "overview.md"
        self.guide.write_text("Project-specific instructions\n")
        self.sources = {"verilator": {"license": "https://example.org/LICENSE", "pages": {
            "overview": "https://example.org/overview", "install": "https://example.org/install"}}}
        self.body = "# Upstream guide\n\n" + "Official instructions and examples.\n" * 10

    def invoke(self, args, fetch=None, branch="docs/update-tools"):
        with (patch.object(updater, "ROOT", self.root),
              patch.object(updater, "load_sources", return_value=self.sources),
              patch.object(updater.shutil, "which", return_value="/bin/firecrawl"),
              patch.object(updater.subprocess, "check_output", return_value=branch),
              patch.object(updater, "scrape", side_effect=fetch or (lambda *args: self.body)),
              redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO())):
            updater.main(args)

    def test_refresh_preserves_project_guides_and_creates_index(self):
        self.invoke(["--tool", "verilator"])
        self.assertEqual(self.guide.read_text(), "Project-specific instructions\n")
        reference = self.root / "docs/verilator/upstream/overview.md"
        self.assertIn(self.body, reference.read_text())
        self.assertIn("Source: <https://example.org/overview>", reference.read_text())
        self.assertIn("verilator/upstream/install.md", (self.root / "docs/upstream-index.md").read_text())

    def test_dry_run_fetches_without_writes(self):
        self.invoke(["--dry-run"], branch="main")
        self.assertEqual(list(self.root.rglob("*.md")), [self.guide])

    def test_list_does_not_fetch_or_require_cli(self):
        with (patch.object(updater, "ROOT", self.root),
              patch.object(updater, "load_sources", return_value=self.sources),
              patch.object(updater, "scrape") as scrape,
              patch.object(updater.shutil, "which") as which,
              redirect_stdout(io.StringIO())):
            updater.main(["--list"])
        scrape.assert_not_called()
        which.assert_not_called()

    def test_failed_second_fetch_leaves_all_existing_references_unchanged(self):
        self.invoke([])
        before = {p: p.read_bytes() for p in self.root.rglob("*.md")}
        calls = iter([self.body + "Changed\n", ValueError("request failed")])
        def fetch(*args):
            item = next(calls)
            if isinstance(item, Exception):
                raise item
            return item
        with self.assertRaises(ValueError):
            self.invoke([], fetch=fetch)
        self.assertEqual(before, {p: p.read_bytes() for p in self.root.rglob("*.md")})

    def test_page_filter_and_unchanged_content_keep_timestamp(self):
        self.invoke(["--page", "overview"])
        reference = self.root / "docs/verilator/upstream/overview.md"
        before = reference.read_bytes()
        self.invoke(["--page", "overview"])
        self.assertEqual(before, reference.read_bytes())
        self.assertFalse((reference.parent / "install.md").exists())
        self.assertNotIn("install.md", (self.root / "docs/upstream-index.md").read_text())

    def test_unknown_page_and_main_branch_rejected(self):
        with self.assertRaises(SystemExit):
            self.invoke(["--page", "unknown"])
        for branch in ("main", "master", ""):
            with self.assertRaises(ValueError):
                self.invoke([], branch=branch)
        self.assertFalse((self.root / "docs/upstream-index.md").exists())

    def test_symlink_destination_rejected(self):
        outside = self.root / "outside"
        outside.mkdir()
        (self.guide.parent / "upstream").symlink_to(outside, target_is_directory=True)
        with self.assertRaises(ValueError):
            self.invoke([])
        self.assertEqual(list(outside.iterdir()), [])

    def test_path_escape_and_unsafe_sources_rejected(self):
        with patch.object(updater, "ROOT", self.root):
            with self.assertRaises(ValueError):
                updater.destination("../escaped.md")
        for url in ("http://example.org", "https://user:secret@example.org", "file:///etc/passwd"):
            with self.assertRaises(ValueError):
                updater.source_url(url)

    def scrape_response(self, payload, code=0):
        with patch.object(updater.subprocess, "run", return_value=subprocess.CompletedProcess(
                [], code, stdout=json.dumps(payload), stderr="")) as run:
            result = updater.scrape("https://example.org/guide", "/bin/firecrawl")
        self.assertIn("--max-age", run.call_args.args[0])
        return result

    def test_cli_flat_and_wrapped_json_supported(self):
        data = {"markdown": self.body, "metadata": {"statusCode": 200}}
        self.assertEqual(self.scrape_response(data), self.body)
        self.assertEqual(self.scrape_response({"success": True, "data": data}), self.body)

    def test_bad_responses_rejected(self):
        for data in (
            {"success": False},
            {"markdown": self.body, "metadata": {"statusCode": 404}},
            {"markdown": "", "metadata": {"statusCode": 200}},
            {"markdown": self.body, "metadata": {}},
            {"markdown": self.body, "metadata": {"statusCode": 200, "title": "Just a moment..."}},
        ):
            with self.assertRaises(ValueError):
                self.scrape_response(data)
        with self.assertRaises(ValueError):
            self.scrape_response({}, code=1)


if __name__ == "__main__":
    unittest.main()
