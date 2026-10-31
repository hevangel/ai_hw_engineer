import os, re
os.environ["OMP_NUM_THREADS"]="8"
import pymupdf
from rapidocr_onnxruntime import RapidOCR
ocr = RapidOCR()
parts = ["74LS02","74LS20","74LS32","74LS51","74LS86","74LS138","74LS139","74LS151","74LS166","74LS194","74LS251","74LS259","74LS283"]
for p in parts:
    d = pymupdf.open(f"ds/{p}.pdf")
    pix = d[0].get_pixmap(dpi=250); pix.save("p1.png")
    res,_ = ocr("p1.png"); txt = " ".join(r[1] for r in res) if res else ""
    m = re.findall(r"SDLS\s?\d+[A-Z]?", txt, re.I)
    print(p, m[:3], "|", txt[:60])
print("--- fairchild 161")
d = pymupdf.open("fc161.pdf"); t = d[0].get_text()
print(t[:400].replace("\n"," / "))
print("--- signetics 257")
d = pymupdf.open("x_74LS257.pdf"); t = d[0].get_text()
print(t[:300].replace("\n"," / "))
