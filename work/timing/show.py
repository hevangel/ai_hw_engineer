import json
d=json.load(open("ls_logic.json"))
for k,v in d["parts"].items():
    print(f"{k} typ={v['tpd_typ_ns']} max={v['tpd_max_ns']} {v['parameter']:<9} p{v['page']:<2} {v['document'][:30]}")
print("unresolved", d["unresolved"])
print("bytes", len(open("ls_logic.json","rb").read()))
