import pypdf,warnings
warnings.filterwarnings("ignore")
r=pypdf.PdfReader("work/timing/pdf/signetics_1977_memory.pdf")
print("pages",len(r.pages))
hits=[]
for i,p in enumerate(r.pages):
    t=p.extract_text() or ""
    if "2513" in t or "9316" in t:
        hits.append(i+1)
print("hits",hits[:60])
