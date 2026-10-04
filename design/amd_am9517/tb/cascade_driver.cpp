#include "Vtb_cascade.h"
#include "verilated.h"
#include <cstdint>
#include <cstdio>
#include <cstdlib>
static uint64_t checks=0,transfers=0,cases=0;
static void check(bool ok,const char* why){++checks;if(!ok){std::fprintf(stderr,"FAIL cascade case %llu: %s\n",(unsigned long long)cases,why);std::exit(1);}}
static void tick(Vtb_cascade& d){d.clk_i=0;d.eval();d.clk_i=1;d.eval();}
static uint8_t access(Vtb_cascade& d,unsigned chip,unsigned offset,bool write,uint8_t value=0){d.clk_i=0;d.host_chip_i=chip;d.host_address_i=offset;d.host_write_i=write;d.host_data_i=value;d.host_select_i=1;d.eval();uint8_t r=d.host_data_o;if(!write)check(d.host_oe_o,"cascade host read drives");d.clk_i=1;d.eval();d.host_select_i=0;tick(d);return r;}
static void word(Vtb_cascade& d,unsigned chip,unsigned offset,uint16_t value){access(d,chip,12,true);access(d,chip,offset,true,uint8_t(value));access(d,chip,offset,true,uint8_t(value>>8));}
int main(int argc,char** argv){Verilated::commandArgs(argc,argv);Vtb_cascade d;
 for(unsigned variant=0;variant<32;++variant){++cases;d.host_select_i=0;d.parent_request_i=0;d.child_request_i=0;d.child_ready_i=1;d.reset_i=1;tick(d);d.reset_i=0;tick(d);unsigned lengths[2][4]{},seen[2][4]{};uint16_t bases[2][4]{};
  for(unsigned chip=0;chip<2;++chip)for(unsigned ch=0;ch<4;++ch){lengths[chip][ch]=1+(variant+ch+chip)%8;bases[chip][ch]=uint16_t(0x10fc+chip*0x2000+ch*0x100);word(d,chip,ch*2,bases[chip][ch]);word(d,chip,ch*2+1,uint16_t(lengths[chip][ch]-1));access(d,chip,11,true,uint8_t(chip==0&&ch==1?0xc1:0x88|ch));}access(d,0,15,true,0);access(d,1,15,true,0);
  d.parent_request_i=7;d.child_request_i=15;uint8_t latch[2]{};unsigned expected=0;for(unsigned ch=0;ch<4;++ch){expected+=lengths[1][ch];if(ch!=1)expected+=lengths[0][ch];}unsigned count=0;
  for(unsigned cycle=0;cycle<4000;++cycle){d.clk_i=0;d.child_ready_i=(cycle%7)!=2&&(cycle%7)!=3;d.eval();check(d.aen_o!=3&&d.valid_o!=3,"cascade has one bus owner/commit");unsigned old_adstb=d.adstb_o,old_data=d.device_data_o;
   for(unsigned chip=0;chip<2;++chip)if(d.valid_o&(1u<<chip)){unsigned ch=(d.channel_o>>(chip*2))&3;check(!(chip==0&&ch==1),"cascade channel never transfers itself");check(seen[chip][ch]<lengths[chip][ch],"exact per-channel transfer count");uint16_t a=uint16_t(d.address_o>>(chip*16));check(a==uint16_t(bases[chip][ch]+seen[chip][ch]),"independent seven-channel address sequence");check(((d.strobes_o>>(chip*4))&15)==6,"read-transfer strobes");check(uint16_t((uint16_t(latch[chip])<<8)|(a&255))==a,"native external high-address latch matches full address");check(bool(!(d.eop_n_o&(1u<<chip)))==(seen[chip][ch]==lengths[chip][ch]-1),"terminal only at channel end");++seen[chip][ch];++count;++transfers;}
   d.clk_i=1;d.eval();for(unsigned chip=0;chip<2;++chip)if((old_adstb&(1u<<chip))&&!(d.adstb_o&(1u<<chip)))latch[chip]=uint8_t(old_data>>(chip*8));
   if(count==expected&&d.hrq_o==0)break;
  }
  check(count==expected,"all seven channels complete");for(unsigned chip=0;chip<2;++chip)for(unsigned ch=0;ch<4;++ch)check(seen[chip][ch]==((chip==0&&ch==1)?0:lengths[chip][ch]),"exact hierarchy completion count");d.parent_request_i=0;d.child_request_i=0;tick(d);tick(d);
  access(d,0,12,true);check(access(d,0,2,false)==uint8_t(bases[0][1])&&access(d,0,2,false)==uint8_t(bases[0][1]>>8),"cascade parent address unchanged");access(d,0,12,true);check(access(d,0,3,false)==uint8_t(lengths[0][1]-1)&&access(d,0,3,false)==0,"cascade parent count unchanged");
 }
 d.final();std::printf("TEST PASSED: actual two-Am9517 seven-channel cascade %llu cases, %llu transfers, %llu checks\n",(unsigned long long)cases,(unsigned long long)transfers,(unsigned long long)checks);
}
