import pymupdf
for part,pno in [("74LS02",4),("74LS11",3)]:
    d = pymupdf.open(f"ds/{part}.pdf"); pg=d[pno-1]; h=pg.rect.height; w=pg.rect.width
    pix = pg.get_pixmap(dpi=300, clip=pymupdf.Rect(0,h*0.50,w,h*0.78)); out=f"crops/ti_{part}_p{pno}.png"; pix.save(out); print(out,pix.width,pix.height)
