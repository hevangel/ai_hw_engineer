import pypdf
r = pypdf.PdfReader("work/timing/pdf/TMS4116.pdf")
for i,p in enumerate(r.pages):
    t = p.extract_text() or ""
    print(i+1, len(t))
print("---P1---")
print((r.pages[0].extract_text() or "")[:1500])
