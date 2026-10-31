import os
os.environ["OMP_NUM_THREADS"]="8"
import pymupdf, glob
from rapidocr_onnxruntime import RapidOCR
ocr = RapidOCR()
os.makedirs("ocr2", exist_ok=True)
skip = {"74LS00.pdf","74LS04.pdf","74LS195.pdf"}
for f in sorted(glob.glob("ds/74LS*.pdf")):
    part = os.path.basename(f).replace(".pdf","")
    if os.path.basename(f) in skip: continue
    d = pymupdf.open(f)
    for pi in range(2, min(d.page_count, 9)):
        out = f"ocr2/{part}_p{pi+1}.txt"
        if os.path.exists(out): continue
        pix = d[pi].get_pixmap(dpi=200); pix.save("tmp3.png")
        try: res,_ = ocr("tmp3.png")
        except Exception: res = []
        if not res:
            open(out,"w",encoding="utf8").write(""); continue
        items = sorted((r[0][0][1], r[0][0][0], r[1]) for r in res)
        lines=[]; cur=[]; y0=None
        for y,x,t in items:
            if y0 is None or abs(y-y0) <= 12:
                cur.append((x,t)); y0 = y if y0 is None else y0
            else:
                lines.append(sorted(cur)); cur=[(x,t)]; y0=y
        if cur: lines.append(sorted(cur))
        with open(out,"w",encoding="utf8") as fh:
            for ln in lines:
                fh.write(" | ".join(f"{x:.0f}:{t}" for x,t in ln) + "\n")
    print("done", part, flush=True)
print("ALL DONE")
