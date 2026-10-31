import pymupdf
d = pymupdf.open("ds/74LS161.pdf"); pg=d[4]; h=pg.rect.height; w=pg.rect.width
pix = pg.get_pixmap(dpi=260, clip=pymupdf.Rect(0,h*0.05,w,h*0.75)); pix.save("crops/t_74LS161_p5.png"); print(pix.width,pix.height)
