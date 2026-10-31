from pdfminer.high_level import extract_text
t = extract_text("alt_74LS195.pdf")
print(len(t)); print(t[:1500])
