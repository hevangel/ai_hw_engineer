"""C64 keyboard matrix: key name -> (CIA1 PA column bit, CIA1 PB row bit).

Matrix from the C64 Programmer's Reference Guide keyboard-matrix table
(also KERNAL keyboard decode table at $EB81). The board input bit is
8 * column + row.
"""
MATRIX = [
    ["DEL", "RETURN", "RIGHT", "F7", "F1", "F5", "F3", "DOWN"],
    ["3", "W", "A", "4", "Z", "S", "E", "LSHIFT"],
    ["5", "R", "D", "6", "C", "F", "T", "X"],
    ["7", "Y", "G", "8", "B", "H", "U", "V"],
    ["9", "I", "J", "0", "M", "K", "O", "N"],
    ["+", "P", "L", "-", ".", ":", "@", ","],
    ["POUND", "*", ";", "HOME", "RSHIFT", "=", "UPARROW", "/"],
    ["1", "LEFTARROW", "CTRL", "2", "SPACE", "CBM", "Q", "STOP"],
]
KEYS = {name: 8 * column + row for column, names in enumerate(MATRIX)
        for row, name in enumerate(names)}
# Unshifted characters, and characters typed with a SHIFT key.
CHARS = {c: [c] for c in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789+-.:@,*;=/"}
CHARS.update({" ": ["SPACE"], "\n": ["RETURN"]})
SHIFTED = {"!": "1", '"': "2", "#": "3", "$": "4", "%": "5", "&": "6", "'": "7",
           "(": "8", ")": "9", "<": ",", ">": ".", "?": "/", "[": ":", "]": ";"}
CHARS.update({c: ["LSHIFT", base] for c, base in SHIFTED.items()})


def mask(names):
    value = 0
    for name in names:
        value |= 1 << KEYS[name]
    return value


def chord(char):
    """Key names to hold for one typed character (upper-case PETSCII)."""
    names = CHARS.get(char.upper())
    if names is None:
        raise ValueError(f"no C64 key for {char!r}")
    return names
