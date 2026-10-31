import pymupdf, sys
spec = [("74LS02",4),("74LS08",4),("74LS11",3)]
for part, pno in spec:
    d = pymupdf.open(f"ds/{part}.pdf")
    pg = d[pno-1]; h = pg.rect.height; w = pg.rect.width
    clip = pymupdf.Rect(0, h*0.42, w, h*0.98)
    pix = pg.get_pixmap(dpi=300, clip=clip)
    out = f"crops/ti_{part}_p{pno}.png"; pix.save(out); print(out, pix.width, pix.height)
