import pypdf,sys
p="work/timing/pdf/MK4116-2_3.pdf"
r=pypdf.PdfReader(p)
print("pages:",len(r.pages))
for i,pg in enumerate(r.pages):
    t=pg.extract_text() or ""
    print(i+1,len(t))
