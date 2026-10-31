import pypdf,warnings
warnings.filterwarnings("ignore")
r=pypdf.PdfReader("work/timing/pdf/ns_iface_1983.pdf")
for i in [193,196,281,283,1019,1023,1024]:
    print(f"===== PAGE {i+1} =====")
    print((r.pages[i].extract_text() or "")[:1500])
