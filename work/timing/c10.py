import pymupdf
d = pymupdf.open("ds/74LS161.pdf"); print("pages", d.page_count)
for i in [1]:
    pg=d[i]; h=pg.rect.height; w=pg.rect.width
    pix = pg.get_pixmap(dpi=240, clip=pymupdf.Rect(0,h*0.05,w,h*0.98)); pix.save(f"crops/t_74LS161_p{i+1}.png"); print(i+1, pix.width,pix.height)
