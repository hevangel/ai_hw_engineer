import os, time
os.environ["OMP_NUM_THREADS"]="8"
import pymupdf
from rapidocr_onnxruntime import RapidOCR
ocr = RapidOCR()
d = pymupdf.open("ds/74LS32.pdf")
for i in [4,5]:
    pix = d[i].get_pixmap(dpi=200); pix.save("t.png")
    t0=time.time(); res,_=ocr("t.png"); print(i, round(time.time()-t0,1), "s", len(res or []))
