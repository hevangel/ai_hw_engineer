from pathlib import Path

p = Path("system/apple_ii/scripts/generate_rev0.py")
t = p.read_text()

old = """    uniform = {'legacy': 5, 'zero': 0}.get(mode)"""
new = """    uniform = {'legacy': 5, 'zero': 0}.get(mode)
    # The 4116 carried a 20 ns placeholder in the original generated board.
    legacy_overrides = {'4116': 20} if mode == 'legacy' else {}"""
assert t.count(old) == 1
t = t.replace(old, new)

old = """        if key is None:
            delays[part] = uniform
            continue"""
new = """        if key is None:
            delays[part] = legacy_overrides.get(part, uniform)
            continue"""
assert t.count(old) == 1
t = t.replace(old, new)

p.write_text(t, newline="\r\n")
print("ok")
