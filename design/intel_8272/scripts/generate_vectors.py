"""Independent IBM codec vectors: public-domain Greaseweazle functions + stdlib CRC.

Source excerpt retained in references/greaseweazle_ibm.py, not derived from RTL.
"""
import ast
import binascii
import importlib.util
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
# Materialize the four selected reference functions as a self-contained
# module under work/ and import it through importlib (no exec of dynamic
# source). The excerpt stays byte-identical to the vendored reference.
module_source = ("import struct\n\n"
                 "encode_list = " + repr(table) + "\n\n"
                 + "\n\n".join(ast.get_source_segment(source, node)
                               for node in selected) + "\n")
module_path = ROOT / "work" / "greaseweazle_codec_sel.py"
module_path.parent.mkdir(parents=True, exist_ok=True)
module_path.write_text(module_source)
spec = importlib.util.spec_from_file_location("greaseweazle_codec_sel", module_path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
rows = []
for density in range(2):
    for previous in range(2):
        for value in range(256):
            doubled = module.encode(bytes([previous, value]))
            encoded = getattr(module, "mfm_encode" if density else "fm_encode")(doubled)[-2:]
            word = int.from_bytes(encoded, "big")
            rows.append(f"{density:x}{previous:x}{value:02x}{word:04x}\n")
(ROOT / "references/codec_vectors.hex").write_text("".join(rows))
