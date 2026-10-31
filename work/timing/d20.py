import pypdf,warnings
warnings.filterwarnings("ignore")
r=pypdf.PdfReader("work/timing/pdf/signetics_1977_memory.pdf")
t=r.pages[14].extract_text() or ""
print(t[:1800])
