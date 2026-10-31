from pdfminer.high_level import extract_text
t = extract_text("alt_74LS195.pdf", page_numbers=[4,5,6])
print(t)
