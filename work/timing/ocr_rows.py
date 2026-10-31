import pymupdf, sys
from rapidocr_onnxruntime import RapidOCR
ocr = RapidOCR()

def rows(path, dpi=250):
    d = pymupdf.open(path); out=[]
    for pi in range(2, min(d.page_count, 9)):
        pix = d[pi].get_pixmap(dpi=dpi); pix.save("tmp.png")
        res,_ = ocr("tmp.png")
        if not res: continue
        items = [(r[0][0][1], r[0][0][0], r[1]) for r in res]  # ytop, xleft, text
        items.sort()
        lines=[]; cur=[]; y0=None
        for y,x,t in items:
            if y0 is None or abs(y-y0) <= 12:
                cur.append((x,t)); y0 = y if y0 is None else y0
            else:
                lines.append(sorted(cur)); cur=[(x,t)]; y0=y
        if cur: lines.append(sorted(cur))
        out.append((pi+1, lines))
    return out

for pno, lines in rows(sys.argv[1]):
    txt = "\n".join("  ".join(t for _,t in ln) for ln in lines)
    if "witching" in txt or "WITCHING" in txt:
        print("=== page", pno, "===")
        for ln in lines:
            print(f"[{ln[0][0]:4.0f}] " + " | ".join(f"{t}" for _,t in ln))
