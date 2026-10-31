import pypdf,warnings
warnings.filterwarnings("ignore")
r=pypdf.PdfReader("work/timing/pdf/ns_interface_1979.pdf")
for i in [150,151,152,308]:
    print(f"===== PDF PAGE {i+1} =====")
    print((r.pages[i].extract_text() or "")[:3500])
