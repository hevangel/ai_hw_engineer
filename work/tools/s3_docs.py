"""S3: remove the legacy functional top and its bring-up test from docs/scripts."""
from pathlib import Path

spec = Path("system/apple_ii/spec/spec.md")
text = spec.read_text()
start = text.find("\n## Integrated bring-up regression\n")
end = text.find("\n## Digital video acceptance contract\n")
assert 0 < start < end
text = text[:start] + text[end:]
spec.write_text(text, newline="\r\n")

run_all = Path("system/apple_ii/scripts/run_all.sh")
text = run_all.read_text()
old = "sh scripts/run_sim.sh\n"
assert text.count(old) == 1
text = text.replace(old, "")
run_all.write_text(text, newline="\r\n")
print("ok")
