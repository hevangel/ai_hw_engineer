import pymupdf, sys, re, os, glob
for p in sorted(glob.glob("ds/74LS*.pdf")):
    d = pymupdf.open(p)
    print("#####", os.path.basename(p), "pages", d.page_count)
    for i, pg in enumerate(d):
        t = pg.get_text()
        low = t.lower()
        if "switching characteristics" in low:
            idx = low.find("switching characteristics")
            print(f"--- p{i+1} ---")
            print(t[max(0,idx-200):idx+1400].replace("\n"," | "))
