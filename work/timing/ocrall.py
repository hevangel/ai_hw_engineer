import pymupdf, glob, os, time
from rapidocr_onnxruntime import RapidOCR
ocr = RapidOCR()
os.makedirs("ocr", exist_ok=True)
files = [f for f in sorted(glob.glob("ds/74LS*.pdf")) if os.path.basename(f) not in ("74LS195.pdf","74LS00.pdf","74LS04.pdf")]
for f in files:
    part = os.path.basename(f).replace(".pdf","")
    d = pymupdf.open(f)
    n = min(d.page_count, 9)
    for i in range(2, n):
        out = f"ocr/{part}_p{i+1}.txt"
        if os.path.exists(out): continue
        pix = d[i].get_pixmap(dpi=200); pix.save("tmp.png")
        try:
            res, _ = ocr("tmp.png")
        except Exception as e:
            res = []
        txt = "\n".join(r[1] for r in res) if res else ""
        open(out,"w",encoding="utf8").write(txt)
    print("done", part, flush=True)
print("ALL DONE")
