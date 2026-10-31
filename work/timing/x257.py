import pymupdf, glob
for f in glob.glob("x_*.pdf"):
    try:
        d=pymupdf.open(f); t="".join(p.get_text() for p in d)
        print(f, d.page_count, len(t), "| tPLH", "tPLH" in t)
        i=t.find("tPLH")
        if i>0: print(t[max(0,i-500):i+700].replace("\n"," ~ ")[:1200])
    except Exception as e: print(f, "ERR", e)
