package net.maisikoleni.am2900me.logic;

import java.io.*;
import java.util.Random;
import net.maisikoleni.am2900me.logic.microinstr.*;

/** Adapter only: immutable Am2900ME supplies data/state/shift expectations.
 * Figure 8 supplies status, independently of the RTL; differences are counted.
 */
public class Oracle {
  static PrintWriter out;
  static long cases, statusDifferences;
  static int bit(int value,int index) { return (value>>>index)&1; }
  static int nz(int value) { return value==0 ? 0 : 1; }
  static int[] flags(int r,int s,int fn,int cn) {
    int x=r, y=s;
    if(fn==1 || fn==5 || fn==6) x^=15;
    if(fn==2) y^=15;
    int p=x|y, g=x&y;
    int sum=x+y+cn, low=(x&7)+(y&7)+cn;
    int pn=p==15 ? 0 : 1;
    int gn=(x+y)>=16 ? 0 : 1;
    int carry=bit(sum,4), overflow=bit(sum,4)^bit(low,3);
    if(fn==3 || fn==6) {
      pn=0; gn=p==15 ? 1:0; carry=(p==15 ? 0:1)|cn; overflow=carry;
    } else if(fn==4 || fn==5) {
      pn=0; gn=g==0 ? 1:0; carry=(g==0 && cn==0) ? 1:0; overflow=carry;
    } else if(fn==7) {
      pn=nz(g);
      gn=bit(g,3)|(bit(p,3)&bit(g,2))|(bit(p,3)&bit(p,2)&bit(g,1))|
         (bit(p,3)&bit(p,2)&bit(p,1)&bit(p,0));
      carry=1-(bit(g,3)|(bit(p,3)&bit(g,2))|(bit(p,3)&bit(p,2)&bit(g,1))|
        (bit(p,3)&bit(p,2)&bit(p,1)&bit(p,0)&(bit(g,0)|(1-cn))));
      // Figure 8 note: complemented P and G, two independent chain lengths.
      int[] c={cn,0,0,0,0};
      for(int i=0;i<4;i++) c[i+1]=(1-bit(p,i))|((1-bit(g,i))&c[i]);
      overflow=c[3]^c[4];
    }
    return new int[]{pn,gn,carry,overflow};
  }
  static int pattern(int seed,int addr) { return ((seed>>>((addr&7)*4))+addr*3)&15; }
  static void emit(int word,int addrA,int addrB,int a,int b,int q,int d,int cn,int shift,int oe,int seed) {
    Am2901 ref=new Am2901();
    for(int i=0;i<16;i++) ref.setRegisters4bit(i,pattern(seed,i));
    ref.setRegisters4bit(addrA,a); ref.setRegisters4bit(addrB,addrA==addrB ? a:b); ref.setQ(q);
    var in=ref.input;
    in.mi_src=Am2901_Src.values()[word&7]; in.mi_func=Am2901_Func.values()[(word>>3)&7];
    in.mi_dest=Am2901_Dest.values()[word>>6];
    in.regA_addr=addrA; in.regB_addr=addrB; in.D=d; in.Cn=cn; in._OE=oe;
    in.RAM0=bit(shift,0); in.RAM3=bit(shift,1); in.Q0=bit(shift,2); in.Q3=bit(shift,3);
    int actualA=ref.getRegisters4bit(addrA), actualB=ref.getRegisters4bit(addrB);
    int r=switch(word&7) {case 0,1 -> actualA; case 5,6,7 -> d; default -> 0;};
    int s=switch(word&7) {case 0,2,6 -> q; case 1,3 -> actualB; case 4,5 -> actualA; default -> 0;};
    var result=ref.processStep1(); int[] fs=flags(r,s,(word>>3)&7,cn);
    if(result._P!=fs[0] || result._G!=fs[1] || result.Cn4!=fs[2] || result.OVR!=fs[3]) statusDifferences++;
    int packedFlags=fs[0]|(fs[1]<<1)|(fs[2]<<2)|(fs[3]<<3)|(result.F3<<4)|(result.F0<<5);
    int shifts=0, enables=0;
    int[] pins={result.RAM0,result.RAM3,result.Q0,result.Q3};
    for(int i=0;i<4;i++) if(pins[i]>=0) {enables|=1<<i; shifts|=pins[i]<<i;}
    int y=result.Y<0 ? 0:result.Y, yo=result.Y<0 ? 0:1;
    ref.processStep2(); long memory=0;
    for(int i=0;i<16;i++) memory|=((long)ref.getRegisters4bit(i))<<(i*4);
    out.printf("%x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %x %016x%n",
        word,addrA,addrB,d,cn,oe,shift,actualA,actualB,q,seed,y,yo,packedFlags,shifts,enables,ref.getQ(),word>>6,memory);
    cases++;
  }
  public static void main(String[] args) throws Exception {
    out=new PrintWriter(new BufferedWriter(new FileWriter(args[0])));
    // All 8 sources x 8 functions x 16 R x 16 S x 2 carries.
    for(int src=0;src<8;src++) for(int fn=0;fn<8;fn++) for(int r=0;r<16;r++) for(int s=0;s<16;s++) for(int cn=0;cn<2;cn++) {
      int a=s,b=s,q=s,d=r;
      if(src==0 || src==1) a=r;
      emit(64|(fn<<3)|src,0,1,a,b,q,d,cn,0,0,0x76543210);
    }
    Random random=new Random(0x29011975);
    for(int word=0;word<512;word++) for(int variant=0;variant<128;variant++)
      emit(word,random.nextInt(16),random.nextInt(16),random.nextInt(16),random.nextInt(16),
        random.nextInt(16),random.nextInt(16),variant&1,(variant>>1)&15,(variant>>5)&1,random.nextInt());
    out.close();
    System.out.printf("ORACLE: %d cases; %d immutable-emulator status disagreements, manufacturer Figure 8 used for status%n",cases,statusDifferences);
  }
}
