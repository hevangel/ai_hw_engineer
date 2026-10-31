import pypdf,warnings
warnings.filterwarnings("ignore")
for f in ["work/timing/pdf/8T97.pdf","work/timing/pdf/8T28.pdf"]:
    r=pypdf.PdfReader(f)
    print("=====",f,"pages",len(r.pages))
    for i,p in enumerate(r.pages):
        t=p.extract_text() or ""
        print(i+1,len(t))
    print((r.pages[0].extract_text() or "")[:800])
