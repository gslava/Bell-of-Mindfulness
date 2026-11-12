import os
import pathlib
import subprocess
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]


class GitIdentityGuardTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.env = {key: value for key, value in os.environ.items()
                    if not key.startswith(("GIT_AUTHOR_", "GIT_COMMITTER_"))}
        subprocess.run(["git", "init", "-q", self.directory.name], env=self.env, check=True)
        for key, value in [("user.name", "gslava"), ("user.email", "itic1gm@gmail.com")]:
            subprocess.run(["git", "-C", self.directory.name, "config", "--local", key, value],
                           env=self.env, check=True)

    def guard(self, **overrides):
        return subprocess.run(["sh", str(ROOT / ".githooks/prepare-commit-msg")],
                              cwd=self.directory.name, env={**self.env, **overrides},
                              capture_output=True, text=True)

    def test_owner_identity_is_accepted(self):
        self.assertEqual(self.guard().returncode, 0)

    def test_different_author_is_rejected(self):
        result = self.guard(GIT_AUTHOR_NAME="Other", GIT_AUTHOR_EMAIL="other@example.invalid")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("GIT_AUTHOR_IDENT", result.stderr)

    def test_different_committer_is_rejected(self):
        result = self.guard(GIT_COMMITTER_NAME="Other", GIT_COMMITTER_EMAIL="other@example.invalid")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("GIT_COMMITTER_IDENT", result.stderr)


if __name__ == "__main__":
    unittest.main()
