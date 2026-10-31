import pymupdf
for f in ["ds/74LS02.pdf","ds/74LS138.pdf","ds/74LS194.pdf"]:
    d = pymupdf.open(f)
    print("#####", f)
    for i,pg in enumerate(d):
        t = pg.get_text()
        if "PARAMETER" in t.upper() and ("ns" in t):
            print(f"--- p{i+1} sample ---")
            print(repr(t[:600]))
            break
