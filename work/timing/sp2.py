import os, time
os.environ["OMP_NUM_THREADS"]="8"
import pymupdf
from rapidocr_onnxruntime import RapidOCR
ocr = RapidOCR()
d = pymupdf.open("ds/74LS32.pdf")
for dpi in [110, 150]:
    pix = d[5].get_pixmap(dpi=dpi); pix.save("t.png")
    t0=time.time(); res,_=ocr("t.png"); print(dpi, round(time.time()-t0,1), "s", len(res or []))
