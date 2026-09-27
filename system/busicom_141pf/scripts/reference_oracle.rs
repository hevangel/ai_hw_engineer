// Headless adapter for the unmodified external chips crate; no CPU implementation here.
// Wiring and drum tables: V. Ilmer busicom dea0745b10032ebf632f0431b26728717920e17f.
// The external crates stay outside this repository; see check_reference.py.
use chips::{mcs4::{Board, shifter4003::Shifter}, shifter::Direction};
use arbitrary_int::u4;
fn main() {
    let args: Vec<String> = std::env::args().collect();
    let mut b = Board::new(std::fs::read(&args[1]).unwrap(), 2);
    let schedule = std::fs::read_to_string(&args[2]).unwrap();
    let mut shifts = [Shifter::new(), Shifter::new(), Shifter::new()];
    let mut spin = 0usize;
    let mut previous = 0;
    let mut red = false;
    let mut row = vec![" ";18];
    let digits = ["0","1","2","3","4","5","6","7","8","9",".",".","-"];
    let sa = ["◇","+","-","×","÷","M+","M-","^","=","√","%","C","R"];
    let sb = ["#","*","Ⅰ","Ⅱ","Ⅲ","M+","M-","T","K","E","Ex","C","M"];
    for line in schedule.lines() {
        if line.starts_with("#EXAMPLE") {
            b=Board::new(std::fs::read(&args[1]).unwrap(),2);
            shifts=[Shifter::new(),Shifter::new(),Shifter::new()];spin=0;previous=0;red=false;row.fill(" ");
        }
        if line.starts_with('#') { println!("{}",line); if line.starts_with("#STEP") { println!("LAMPS|{}",b.rams[1].ports.value()); } continue; }
        let v:Vec<usize> = line.split_whitespace().map(|s|s.parse().unwrap()).collect();
        let (precision, rounding, key, duration) = (v[0],v[1],v[2],v[3]);
        for tick in 0..duration {
            let current = if tick<64 {key} else {0};
            for _ in 0..1481 {
                b.run_cycle();
                let p=b.roms[0].ports.value();
                shifts[0].read_write_serial(Direction::Left,p&2==0,p&1==0);
                let out=shifts[1].read_write_serial(Direction::Left,p&2==2,p&4==0);
                shifts[2].read_write_serial(Direction::Left,out,p&4==0);
                let scan=shifts[0].read_parallel() as usize;
                let keys=if current>=129 && scan == 1<<((current-129)/4) {1<<((current-129)%4)} else {0};
                let input=if scan==256 {precision} else if scan==512 {rounding} else {keys};
                b.roms[1].ports=u4::new(input as u8);
                let p=b.rams[0].ports.value();
                if previous&8==0 && p&8!=0 {
                    if row.iter().any(|s|*s!=" ") {println!("ROW|{}|{}|{}|{}",row[..15].join("").trim(),row[16],row[17],red);}
                    row.fill(" "); red=false;
                }
                if previous&2==0 && p&2!=0 {
                    let pos=(spin/2+12)%13;
                    let bits=shifts[1].read_parallel() as u32 | ((shifts[2].read_parallel() as u32)<<10);
                    for i in 0..15 {if bits&(1<<(i+3))!=0 {row[i]=digits[pos];}}
                    if bits&1!=0 {row[16]=sa[pos];} if bits&2!=0 {row[17]=sb[pos];}
                }
                if p&1!=0 {red=true;} previous=p;
            }
            b.cpu.set_test_flag(spin%2==0);
            if spin%2==0 {
                let mut p=b.roms[2].ports.value();
                if spin==26 {p|=1; spin=0;} else {p&=14;}
                b.roms[2].ports=u4::new(p);
            }
            spin+=1;
        }
    }
}
