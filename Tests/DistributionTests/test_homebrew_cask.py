import copy
import json
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts/generate-homebrew-cask.py"


class HomebrewCaskTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.manifest = Path(self.directory.name) / "release.json"
        self.output = Path(self.directory.name) / "Casks/bell-of-mindfulness.rb"
        self.release = {
            "version": "2.3.4", "tag": "v2.3.4",
            "repository": "gslava/Bell-of-Mindfulness",
            "architectures": ["arm64", "x86_64"], "minimum_macos": "14.0",
            "downloads": {"zip": {
                "file": "Bell-of-Mindfulness-2.3.4-universal.zip",
                "sha256": "a" * 64,
                "url": "https://github.com/gslava/Bell-of-Mindfulness/releases/download/v2.3.4/Bell-of-Mindfulness-2.3.4-universal.zip",
            }},
        }

    def generate(self, release=None, *args):
        self.manifest.write_text(json.dumps(self.release if release is None else release))
        return subprocess.run(["python3", str(SCRIPT), str(self.manifest),
                               "--output", str(self.output), *args], capture_output=True, text=True)

    def test_generates_versioned_archive_with_checksum(self):
        self.assertEqual(self.generate().returncode, 0)
        content = self.output.read_text()
        self.assertIn('version "2.3.4"', content)
        self.assertIn(f'sha256 "{"a" * 64}"', content)
        self.assertIn('/v#{version}/Bell-of-Mindfulness-#{version}-universal.zip', content)
        self.assertIn('app "Bell of Mindfulness.app"', content)
        self.assertIn('uninstall quit: "com.gslava.BellOfMindfulness"', content)
        self.assertNotIn("no_check", content)
        self.assertNotIn("zap", content)
        self.assertEqual(self.generate(None, "--check").returncode, 0)

    def test_check_rejects_tampered_cask_without_rewriting_it(self):
        self.generate()
        self.output.write_text("tampered")
        self.assertNotEqual(self.generate(None, "--check").returncode, 0)
        self.assertEqual(self.output.read_text(), "tampered")

    def test_invalid_manifest_does_not_replace_existing_cask(self):
        self.generate()
        original = self.output.read_text()
        invalid_changes = [
            ("version", '2.3.4"; unexpected'), ("tag", "v2.3.5"),
            ("repository", "other/repository"), ("minimum_macos", "13.0"),
            ("architectures", ["arm64"]),
        ]
        for key, value in invalid_changes:
            with self.subTest(key=key):
                release = copy.deepcopy(self.release)
                release[key] = value
                self.assertNotEqual(self.generate(release).returncode, 0)
                self.assertEqual(self.output.read_text(), original)

    def test_rejects_unverified_or_unexpected_downloads(self):
        for key, value in [("sha256", "no_check"), ("sha256", "g" * 64),
                           ("url", "https://example.invalid/app.zip"),
                           ("file", "../app.zip")]:
            with self.subTest(key=key, value=value):
                release = copy.deepcopy(self.release)
                release["downloads"]["zip"][key] = value
                self.assertNotEqual(self.generate(release).returncode, 0)
                self.assertFalse(self.output.exists())


if __name__ == "__main__":
    unittest.main()
