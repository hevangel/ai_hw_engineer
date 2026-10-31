import pymupdf
for f in ["alt_74LS195.pdf","alt_74195.pdf"]:
    d = pymupdf.open(f)
    print("#####", f, "pages", d.page_count, "chars", sum(len(p.get_text()) for p in d))
    for i,pg in enumerate(d):
        t = pg.get_text()
        if "witching" in t:
            print("--- p",i+1,"---")
            print(t[:1600])
