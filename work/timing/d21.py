import pypdf,warnings
warnings.filterwarnings("ignore")
r=pypdf.PdfReader("work/timing/pdf/signetics_1977_memory.pdf")
hits=[]
for i,p in enumerate(r.pages):
    t=p.extract_text() or ""
    if "2616" in t: hits.append(i+1)
print(hits)
for i in hits[:12]:
    t=r.pages[i-1].extract_text() or ""
    print("=====",i,"=====")
    print(t[:900])
