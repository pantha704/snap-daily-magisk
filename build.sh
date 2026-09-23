#!/bin/sh
# Build the flashable zip. Run from the repo root.
set -e
VER=$(sed -n 's/^version=//p' module.prop)
OUT="snap-daily-${VER}.zip"
rm -f "$OUT"
if command -v zip >/dev/null 2>&1; then
  zip -r -X "$OUT" . -x '.git/*' -x "$OUT" -x 'build.sh' -x '*.zip' -x 'README.md' -x 'LICENSE' -x '.gitignore'
else
  python3 - "$OUT" <<'PY'
import sys, zipfile
from pathlib import Path
out = Path(sys.argv[1])
skip = {'.git', out.name, 'build.sh', 'README.md', 'LICENSE', '.gitignore'}
with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
    for p in sorted(Path('.').rglob('*')):
        if p.is_dir() or p.name in skip or p.parts[0] in skip:
            continue
        z.write(p, str(p))
PY
fi
echo "built $OUT"
