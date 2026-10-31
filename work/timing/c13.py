import pymupdf
d = pymupdf.open("x_74LS257.pdf")
for i,p in enumerate(d):
    if "AC CHARACTERISTICS" in p.get_text().upper():
        h=p.rect.height; w=p.rect.width
        pix=p.get_pixmap(dpi=280, clip=pymupdf.Rect(0,0,w,h*0.75)); pix.save(f"crops/sg_74LS257_p{i+1}.png"); print(i+1, pix.width, pix.height)
