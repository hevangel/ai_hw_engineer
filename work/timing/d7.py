import pypdf
r=pypdf.PdfReader("work/timing/pdf/apple_ii_redbook.pdf")
print("pages",len(r.pages))
hits=[]
for i,p in enumerate(r.pages):
    t=p.extract_text() or ""
    if "4116" in t or "2513" in t or "8T28" in t:
        hits.append(i+1)
print("hit pages:",hits[:40])
