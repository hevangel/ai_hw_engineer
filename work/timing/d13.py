import pypdf,warnings
warnings.filterwarnings("ignore")
r=pypdf.PdfReader("work/timing/pdf/ns_interface_1979.pdf")
print("pages",len(r.pages))
for i,p in enumerate(r.pages):
    t=p.extract_text() or ""
    if "8T28" in t or "8T97" in t:
        print("PAGE",i+1,"len",len(t))
