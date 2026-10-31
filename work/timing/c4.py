import pymupdf, sys, os
def crop(part, pno, tag=""):
    txt = f"ocr2/{part}_p{pno}.txt"
    lines = open(txt, encoding="utf8").read().splitlines() if os.path.exists(txt) else []
    idx = next((i for i,l in enumerate(lines) if "witching" in l.lower()), None)
    d = pymupdf.open(f"ds/{part}.pdf"); pg = d[pno-1]; h = pg.rect.height; w = pg.rect.width
    if idx is not None and lines:
        frac = idx/len(lines)
        y0 = max(0, (frac-0.06)*h); y1 = min(h, (frac+0.38)*h)
    else:
        y0, y1 = h*0.45, h*0.85
    pix = pg.get_pixmap(dpi=300, clip=pymupdf.Rect(0,y0,w,y1))
    out = f"crops/v_{part}_p{pno}.png"; pix.save(out); print(out, pix.width, pix.height, "idx", idx, "of", len(lines))
for part,pno in [("74LS20",3),("74LS138",4),("74LS139",3),("74LS151",4),("74LS153",5),("74LS166",5),("74LS174",4),("74LS194",6),("74LS251",6)]:
    crop(part,pno)
