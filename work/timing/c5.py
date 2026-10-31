import pymupdf, os
def crop(part, pno):
    txt = f"ocr2/{part}_p{pno}.txt"
    lines = open(txt, encoding="utf8").read().splitlines() if os.path.exists(txt) else []
    idx = next((i for i,l in enumerate(lines) if "witching" in l.lower()), None)
    d = pymupdf.open(f"ds/{part}.pdf"); pg = d[pno-1]; h = pg.rect.height; w = pg.rect.width
    if idx is not None and lines:
        frac = idx/len(lines); y0 = max(0,(frac-0.04)*h)
    else: y0 = h*0.40
    pix = pg.get_pixmap(dpi=260, clip=pymupdf.Rect(0,y0,w,h*0.97))
    out=f"crops/w_{part}_p{pno}.png"; pix.save(out); print(out,pix.width,pix.height)
for part,pno in [("74LS20",3),("74LS138",4),("74LS139",3)]:
    crop(part,pno)
