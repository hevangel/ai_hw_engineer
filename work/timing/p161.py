import os
os.environ["OMP_NUM_THREADS"]="8"
import pymupdf, re
from rapidocr_onnxruntime import RapidOCR
ocr = RapidOCR()
d = pymupdf.open("ds/74LS161.pdf")
for p in range(10, 16):
    pix = d[p-1].get_pixmap(dpi=200); pix.save("y.png")
    res,_ = ocr("y.png"); txt = " ".join(r[1] for r in res) if res else ""
    head = txt[:70].replace("\n"," ")
    print(p, len(txt), "SW" if re.search("witching", txt, re.I) else "-", "15pF" if "15 pF" in txt or "15pF" in txt else "-", "|", head)
