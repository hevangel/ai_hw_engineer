import pypdf,warnings
warnings.filterwarnings("ignore")
r=pypdf.PdfReader("work/timing/pdf/signetics_1977_memory.pdf")
for i in [250,251,252]:
    print(f"===== PAGE {i+1} =====")
    print((r.pages[i].extract_text() or "")[:1800])
