import pypdf,warnings,re
warnings.filterwarnings("ignore")
r=pypdf.PdfReader("work/timing/pdf/ns_ttl_1976.pdf")
t=r.pages[23].extract_text() or ""
for m in re.finditer(r"8T(97|28|2\d)", t):
    print("...",t[max(0,m.start()-60):m.end()+80].replace("\n"," "),"...")
print("LEN",len(t))
