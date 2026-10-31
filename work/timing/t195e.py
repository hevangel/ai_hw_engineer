from pdfminer.high_level import extract_text
t = extract_text("alt_74LS195.pdf", page_numbers=[3])
print(t)
