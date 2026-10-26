"""Offline regression checks for Docker Hub publishing helpers."""

from contextlib import redirect_stdout
from datetime import datetime, timezone
import io
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import publish_docker as publisher


class PublishTests(unittest.TestCase):
    def test_version_tag_uses_date_and_short_commit(self):
        now = datetime(2026, 10, 25, 23, 59, tzinfo=timezone.utc)
        self.assertEqual(publisher.version_tag(now, "38b0a04" + "f" * 33), "2026.10.25-38b0a04")

    def test_short_description_fits_docker_hub(self):
        self.assertLessEqual(len(publisher.SHORT_DESCRIPTION), 100)

    def test_toolchain_table_comes_from_release_manifest(self):
        table = publisher.toolchain_table(publisher.MANIFEST.read_text(encoding="utf-8"))
        self.assertTrue(table.startswith("| Component |"))
        self.assertIn("| Verilator |", table)
        self.assertNotIn("\n\n", table)

    def test_overview_template_renders_completely(self):
        values = {key: "x" for key in ("IMAGE", "VERSION", "REVISION", "REVISION_URL", "BUILD_DATE",
                                       "RUNTIME_VERSIONS", "TOOLCHAIN_TABLE")}
        values["REVISION_URL"] = "https://example.org/commit"
        overview = publisher.render_overview(publisher.TEMPLATE.read_text(encoding="utf-8"), values)
        self.assertNotIn("{{", overview)
        # Docker Hub cannot resolve repository-relative links.
        self.assertNotRegex(overview, r"\]\((?!https://)")

    def test_unfilled_placeholder_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "IMAGE"):
            publisher.render_overview("docker pull {{IMAGE}}", {})

    def test_oversized_overview_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "Docker Hub allows"):
            publisher.render_overview("x" * (publisher.FULL_DESCRIPTION_LIMIT + 1), {})

    def test_version_output_takes_first_nonempty_line(self):
        output = "".join(f"@@{name}\n\n{name} 1.0\nextra\n" for name, _ in publisher.VERSION_COMMANDS)
        versions = publisher.parse_versions(output)
        self.assertEqual(versions["Yosys"], "Yosys 1.0")
        self.assertIn("| Yosys | `Yosys 1.0` |", publisher.versions_table(versions))

    def test_missing_version_output_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "Verilator"):
            publisher.parse_versions("@@Yosys\nYosys 1.0\n")

    def test_publish_requires_credentials(self):
        with patch.dict("os.environ", {"DOCKERHUB_USERNAME": "someone"}, clear=True), \
                patch.object(publisher, "default_env_file", return_value=None), \
                patch.object(publisher, "check_source") as check, self.assertRaises(SystemExit):
            publisher.main([])
        check.assert_not_called()

    def test_env_file_parsing(self):
        values = publisher.parse_env("# comment\n\nexport A=1\nB = \"two words\"\nC='x=y'\nD=\n")
        self.assertEqual(values, {"A": "1", "B": "two words", "C": "x=y", "D": ""})

    def test_malformed_env_line_is_rejected_without_echoing_it(self):
        with self.assertRaises(ValueError) as caught:
            publisher.parse_env("DOCKERHUB_TOKEN secret-value\n")
        self.assertIn("line 1", str(caught.exception))
        self.assertNotIn("secret-value", str(caught.exception))

    def test_environment_overrides_env_file(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / ".env"
            path.write_text("DOCKERHUB_USERNAME=from-file\nDOCKERHUB_TOKEN=file-token\n", encoding="utf-8")
            with patch.dict("os.environ", {"DOCKERHUB_USERNAME": "from-env"}, clear=True), \
                    redirect_stdout(io.StringIO()):
                publisher.load_env(path)
                self.assertEqual(os.environ["DOCKERHUB_USERNAME"], "from-env")
                self.assertEqual(os.environ["DOCKERHUB_TOKEN"], "file-token")

    def test_dirty_tree_is_rejected(self):
        with patch.object(publisher, "git", return_value=" M Dockerfile"):
            with self.assertRaisesRegex(ValueError, "uncommitted"):
                publisher.check_source(allow_unmerged=True)


if __name__ == "__main__":
    unittest.main()
