import pypdf
r=pypdf.PdfReader("work/timing/pdf/willegal_assembly.pdf")
print("pages",len(r.pages))
for i,p in enumerate(r.pages):
    t=p.extract_text() or ""
    if "4116" in t or "DRAM" in t or "RAM" in t:
        print("=== PAGE",i+1,"===")
        print(t[:2500])
