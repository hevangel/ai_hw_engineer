import pymupdf, time
from rapidocr_onnxruntime import RapidOCR
ocr = RapidOCR()
d = pymupdf.open("ds/74LS02.pdf")
pg = d[4]
pix = pg.get_pixmap(dpi=300)
pix.save("page.png")
t0=time.time(); res, _ = ocr("page.png"); print("secs", round(time.time()-t0,1))
print("\n".join(r[1] for r in res)[:2000])
