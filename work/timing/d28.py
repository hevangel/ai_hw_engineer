import pypdf,warnings,re
warnings.filterwarnings("ignore")
r=pypdf.PdfReader("work/timing/pdf/ns_iface_1983.pdf")
print("pages",len(r.pages))
for i,p in enumerate(r.pages):
    t=p.extract_text() or ""
    if re.search(r"8T97|DS8T97|8T28", t):
        print("PAGE",i+1,len(t))
