"""Apply CRLF-safe textual replacements to a file (checked-in files use CRLF)."""
import sys
from pathlib import Path

path = Path(sys.argv[1])
old = Path(sys.argv[2]).read_text()
new = Path(sys.argv[3]).read_text()
text = path.read_text()
if text.count(old) != 1:
    raise SystemExit(f"expected exactly one match, found {text.count(old)}")
path.write_text(text.replace(old, new), newline="\r\n")
print(f"patched {path}")
