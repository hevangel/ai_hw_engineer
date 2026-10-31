import pypdf, warnings
warnings.filterwarnings("ignore")
r=pypdf.PdfReader("work/timing/pdf/apple_ii_redbook.pdf")
for i in [149,158]:
    print(f"===== PAGE {i+1} =====")
    print((r.pages[i].extract_text() or "")[:4000])
