import pathlib
import plistlib
import shutil
import subprocess
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]


class ReleaseTagTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = pathlib.Path(self.directory.name)
        (self.root / "scripts").mkdir()
        (self.root / "Resources").mkdir()
        shutil.copyfile(ROOT / "scripts/check-release-tag.sh", self.root / "scripts/check-release-tag.sh")
        self.metadata()

    def metadata(self, version="1.0.0", build="1"):
        with (self.root / "Resources/Info.plist").open("wb") as stream:
            plistlib.dump({"CFBundleShortVersionString": version, "CFBundleVersion": build}, stream)

    def run_tag(self, *args):
        return subprocess.run(["bash", str(self.root / "scripts/check-release-tag.sh"), *args],
                              text=True, capture_output=True)

    def test_matching_tag_is_accepted(self):
        self.assertEqual(self.run_tag("v1.0.0").returncode, 0)

    def test_mismatch_is_rejected(self):
        result = self.run_tag("v1.0.1")
        self.assertEqual(result.returncode, 1)
        self.assertIn("does not match", result.stderr)

    def test_missing_and_extra_arguments_are_rejected(self):
        self.assertEqual(self.run_tag().returncode, 2)
        self.assertEqual(self.run_tag("v1.0.0", "extra").returncode, 2)

    def test_invalid_tags_are_rejected(self):
        for tag in ["1.0.0", "v1.0", "v1.0.0-beta.1", "v01.0.0", "v1.00.0",
                    "v1.0.01", "v1.0.0; echo unexpected", "main"]:
            with self.subTest(tag=tag):
                self.assertEqual(self.run_tag(tag).returncode, 2)

    def test_changed_metadata_is_used(self):
        self.metadata("2.7.9", "18")
        self.assertEqual(self.run_tag("v2.7.9").returncode, 0)
        self.assertEqual(self.run_tag("v1.0.0").returncode, 1)

    def test_zero_major_version_is_supported(self):
        self.metadata("0.1.0", "2")
        self.assertEqual(self.run_tag("v0.1.0").returncode, 0)

    def test_invalid_build_number_is_rejected(self):
        for build in ["0", "-1", "1.2", "01", ""]:
            with self.subTest(build=build):
                self.metadata(build=build)
                self.assertNotEqual(self.run_tag("v1.0.0").returncode, 0)


if __name__ == "__main__":
    unittest.main()
