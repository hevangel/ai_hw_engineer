import pypdf,warnings,re
warnings.filterwarnings("ignore")
r=pypdf.PdfReader("work/timing/pdf/intel_2316e.pdf")
print("pages",len(r.pages))
for i,p in enumerate(r.pages):
    t=p.extract_text() or ""
    if re.search(r"tACC|Access Time|450", t):
        print("== PAGE",i+1,"==")
        print(t[:1200])
