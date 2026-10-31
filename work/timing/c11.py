import pymupdf
d = pymupdf.open("ds/74LS161.pdf"); pg=d[10]; h=pg.rect.height; w=pg.rect.width
pix = pg.get_pixmap(dpi=260, clip=pymupdf.Rect(0,h*0.02,w,h*0.95)); pix.save("crops/t_74LS161_p11.png"); print(pix.width,pix.height)
