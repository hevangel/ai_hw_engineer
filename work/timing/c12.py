import pymupdf
d = pymupdf.open("ds/74LS161.pdf"); pg=d[9]; h=pg.rect.height; w=pg.rect.width
pix = pg.get_pixmap(dpi=250, clip=pymupdf.Rect(0,h*0.40,w,h*0.95)); pix.save("crops/t_74LS161_p10.png"); print(pix.width,pix.height)
