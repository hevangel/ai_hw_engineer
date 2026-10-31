"""C2: add back-to-back NMI pairs to the transistor-oracle pin sweep."""
from pathlib import Path

p = Path("design/mos_6502_family/mos_6502/cycle/tb/pin_test.cpp")
t = p.read_text()

old = "    const unsigned scenarios=8+2*4*80;"
new = """    // 648 single-pulse scenarios plus 120 back-to-back NMI pairs: a second
    // falling edge swept across the first interrupt's vector entry, which is
    // where a pending flag can be cleared in the same clock it is set.
    const unsigned scenarios=8+2*4*80+120;"""
assert t.count(old) == 1
t = t.replace(old, new)

old = """            if(test>=8) {
                unsigned kind=((test-8)%320)/80, arrival=(test-8)%80;
                if(cycle>=arrival && cycle<arrival+3) {
                    if(kind==0) irq=0;
                    if(kind==1) nmi=0;
                    if(kind==2) irq=nmi=0;
                    if(kind==3) ready=0;
                }
            }"""
new = """            if(test>=8 && test<8+640) {
                unsigned kind=((test-8)%320)/80, arrival=(test-8)%80;
                if(cycle>=arrival && cycle<arrival+3) {
                    if(kind==0) irq=0;
                    if(kind==1) nmi=0;
                    if(kind==2) irq=nmi=0;
                    if(kind==3) ready=0;
                }
            } else if(test>=8+640) {
                unsigned index=test-(8+640);
                unsigned arrival=6+(index%20), gap=2+(index/20);
                if((cycle>=arrival && cycle<arrival+2) ||
                   (cycle>=arrival+gap && cycle<arrival+gap+2)) nmi=0;
            }"""
assert t.count(old) == 1
t = t.replace(old, new)

p.write_text(t, newline="\r\n")
print("ok")
