import pypdf,warnings,re
warnings.filterwarnings("ignore")
r=pypdf.PdfReader("work/timing/pdf/ns_ttl_1976.pdf")
for i,p in enumerate(r.pages):
    t=p.extract_text() or ""
    if "8097" in t:
        print("PAGE",i+1)
