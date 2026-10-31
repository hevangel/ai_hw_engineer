import pypdf,warnings,re
warnings.filterwarnings("ignore")
r=pypdf.PdfReader("work/timing/pdf/ns_ttl_1976.pdf")
print(r.pages[23].extract_text()[:1200])
print("---- search T28/T97 ----")
for i,p in enumerate(r.pages):
    t=p.extract_text() or ""
    if re.search(r"T28|T97", t):
        print("PAGE",i+1)
