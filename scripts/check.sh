#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
BELL_RUN_UI=true
if [ "$#" -gt 1 ]; then echo "Usage: bash scripts/check.sh [--no-ui]" >&2; exit 2; fi
if [ "$#" -eq 1 ]; then
    if [ "$1" != '--no-ui' ]; then echo "Usage: bash scripts/check.sh [--no-ui]" >&2; exit 2; fi
    BELL_RUN_UI=false
fi
export CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/ModuleCache"
mkdir -p "$CLANG_MODULE_CACHE_PATH"
python3 -m unittest discover -s Tests/DistributionTests -p 'test_*.py'
swift test --disable-sandbox --cache-path "$PWD/.build/cache" --config-path "$PWD/.build/config" --security-path "$PWD/.build/security" --manifest-cache local
bash scripts/build-app.sh
'build/Bell of Mindfulness.app/Contents/MacOS/BellOfMindfulness' --self-check
if "$BELL_RUN_UI"; then
    'build/Bell of Mindfulness.app/Contents/MacOS/BellOfMindfulness' --smoke-test
fi
