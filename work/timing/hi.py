import os
os.environ["OMP_NUM_THREADS"]="8"
import pymupdf, re
from rapidocr_onnxruntime import RapidOCR
ocr = RapidOCR()
for part, pages in [("74LS86",[4,5,6]),("74LS161",[5,6,7])]:
    d = pymupdf.open(f"ds/{part}.pdf")
    for p in pages:
        pix = d[p-1].get_pixmap(dpi=250); pix.save("x.png")
        res,_ = ocr("x.png")
        txt = " ".join(r[1] for r in res) if res else ""
        hit = re.search(r"witching", txt, re.I)
        print(part, p, "len", len(txt), "hit", bool(hit), "|", txt[:80].replace("\n"," "))
