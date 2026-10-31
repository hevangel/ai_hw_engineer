import pymupdf
d = pymupdf.open("ds/74LS86.pdf"); pg=d[3]; h=pg.rect.height; w=pg.rect.width
pix = pg.get_pixmap(dpi=260, clip=pymupdf.Rect(0,h*0.45,w,h*0.95)); pix.save("crops/t_74LS86_p4.png"); print(pix.width,pix.height)
