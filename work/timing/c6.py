import pymupdf
spec = [("20",4),("32",4),("51",5),("86",5),("138",4),("139",3),("151",4),("153",5),("161",7),("166",6),("174",5),("194",7),("251",6),("257",4),("259",4),("283",4)]
for p,pno in spec:
    part = "74LS"+p
    d = pymupdf.open(f"ds/{part}.pdf"); pg=d[pno-1]; h=pg.rect.height; w=pg.rect.width
    pix = pg.get_pixmap(dpi=250, clip=pymupdf.Rect(0,h*0.10,w,h*0.92))
    out=f"crops/t_{part}_p{pno}.png"; pix.save(out)
    print(out, pix.width, pix.height)
d = pymupdf.open("cand/74LS195_74LS195.pdf"); pg=d[3]; h=pg.rect.height; w=pg.rect.width
pix = pg.get_pixmap(dpi=250, clip=pymupdf.Rect(0,h*0.05,w,h*0.75)); pix.save("crops/on_74LS195_p4.png"); print("on195", pix.width, pix.height)
