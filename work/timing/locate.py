import pymupdf, glob, os, json
from rapidocr_onnxruntime import RapidOCR
ocr = RapidOCR()
out = {}
files = [f for f in sorted(glob.glob("ds/74LS*.pdf")) if os.path.basename(f) != "74LS195.pdf"]
for f in files:
    part = os.path.basename(f).replace(".pdf","")
    d = pymupdf.open(f); hits=[]
    for i in range(2, min(d.page_count, 10)):
        pix = d[i].get_pixmap(dpi=150); pix.save("tmp2.png")
        try:
            res,_ = ocr("tmp2.png")
        except Exception:
            res = []
        txt = " ".join(r[1] for r in res) if res else ""
        low = txt.lower()
        if "switching characteristics" in low or ("switching" in low and "characteristics" in low):
            hits.append(i+1)
    out[part] = hits
    print(part, hits, flush=True)
json.dump(out, open("pages.json","w"), indent=1)
print("DONE")
