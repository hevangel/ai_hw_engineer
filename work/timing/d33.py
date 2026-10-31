import pypdf,warnings
warnings.filterwarnings("ignore")
r=pypdf.PdfReader("work/timing/pdf/ns_ttl_1976.pdf")
for i in [343,365]:
    print(f"===== PAGE {i+1} =====")
    print((r.pages[i].extract_text() or "")[:2600])
