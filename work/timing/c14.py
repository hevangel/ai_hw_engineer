import pymupdf
d = pymupdf.open("ds/74LS74.pdf"); pg=d[4]; h=pg.rect.height; w=pg.rect.width
pix = pg.get_pixmap(dpi=280, clip=pymupdf.Rect(0,h*0.72,w,h*0.98)); pix.save("crops/t_74LS74_p5.png"); print(pix.width,pix.height)
