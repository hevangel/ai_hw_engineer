import pymupdf, glob, os
for f in ["cand/74LS74_74LS74.pdf","cand/74LS86_74LS86.pdf","cand/74LS32_74LS32.pdf","cand/74LS161_74LS161.pdf"]:
    if not os.path.exists(f): print("missing", f); continue
    d = pymupdf.open(f); t = "".join(p.get_text() for p in d)
    i = t.find("tPLH")
    print("#####", f)
    print(t[max(0,i-900):i+700].replace("\n"," ~ "))
    print()
