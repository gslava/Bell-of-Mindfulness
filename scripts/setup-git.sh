#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
git config --local user.name gslava
git config --local user.email itic1gm@gmail.com
git config --local user.useConfigOnly true
git config --local core.hooksPath .githooks
chmod +x .githooks/prepare-commit-msg
bash .githooks/prepare-commit-msg
echo "Configured author and committer: gslava <itic1gm@gmail.com>."
