"""Independent IBM codec vectors: public-domain Greaseweazle functions + stdlib CRC.

Source excerpt retained in references/greaseweazle_ibm.py, not derived from RTL.
"""
import ast
import binascii
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "references/greaseweazle_ibm.py").read_text()
tree = ast.parse(source)
selected = [node for node in tree.body if isinstance(node, ast.FunctionDef)
            and node.name in {"sync", "fm_encode", "mfm_encode", "encode"}]
table = []
for value in range(256):
    # The public-domain upstream doubler table, evaluated independently of the RTL.
    spread = sum(((value >> bit) & 1) << (bit * 2) for bit in range(8))
    table.append(spread)
namespace = {"struct": struct, "encode_list": table}
exec(compile(ast.Module(body=selected, type_ignores=[]), "greaseweazle", "exec"), namespace)
rows = []
for density in range(2):
    for previous in range(2):
        for value in range(256):
            doubled = namespace["encode"](bytes([previous, value]))
            encoded = namespace["mfm_encode" if density else "fm_encode"](doubled)[-2:]
            word = int.from_bytes(encoded, "big")
            rows.append(f"{density:x}{previous:x}{value:02x}{word:04x}\n")
(ROOT / "references/codec_vectors.hex").write_text("".join(rows))
for data in (b"123456789", b"\xa1\xa1\xa1\xfe\x03\x00\x01\x02"):
    answer = binascii.crc_hqx(data, 0xffff)
    assert binascii.crc_hqx(data + answer.to_bytes(2, "big"), 0xffff) == 0
    print(data.hex(), f"{answer:04x}")
