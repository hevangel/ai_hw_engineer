// File transport for the single DPI-calling testbench process. No CPU/ROM emulation.
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#ifdef __cplusplus
extern "C" {
#endif
static FILE *keys;
static uint8_t frame[38400];
static unsigned sample,frames,cycles,key,held,age,cooldown,wave_left,wave_count,resets;
static FILE *wave;
static void fail(const char *what){perror(what);exit(1);}
int panel_cycle(int address,int write_en,int pc,int visible,int main_byte,int aux_byte,int graphics,int line,int font,int aux_font,int col80){
    ++cycles;
    // Prioritize reset before consuming any new queued key.
    FILE*request=fopen("work/reset","r");
    if(request){fclose(request);remove("work/reset");held=0;sample=0;cooldown=8;++resets;return 256;}
    if(!keys){keys=fopen("work/keys","rb");if(!keys)fail("keys");}
    if(held){++age;if(age>=5&&((!write_en&&address==0xc010)||(write_en&&address>=0xc010&&address<=0xc01f))){held=0;cooldown=(key==13)?20000:8;}}
    else if(cooldown)--cooldown;
    else if(address==0xc000&&!write_en){clearerr(keys);int c=fgetc(keys);if(c!=EOF){key=(unsigned)c;held=1;age=0;}}
    if(visible){unsigned i=sample*5;frame[i]=(uint8_t)main_byte;frame[i+1]=(uint8_t)aux_byte;frame[i+2]=(uint8_t)graphics;frame[i+3]=(uint8_t)(line|(font<<3));frame[i+4]=(uint8_t)(col80|(aux_font<<1));
        if(++sample==7680){sample=0;++frames;FILE*f=fopen("work/frame.tmp","wb");if(!f)fail("frame");if(fwrite(frame,1,sizeof(frame),f)!=sizeof(frame))fail("frame write");fclose(f);if(rename("work/frame.tmp","work/frame.bin"))fail("frame rename");
            f=fopen("work/state.tmp","w");if(!f)fail("state");fprintf(f,"{\"cycles\":%u,\"frames\":%u,\"pc\":%d,\"resets\":%u,\"fault\":0}",cycles,frames,pc,resets);fclose(f);if(rename("work/state.tmp","work/state.json"))fail("state rename");}}
    if(!wave_left && cycles%1024==0){FILE*f=fopen("work/capture","r");if(f){fclose(f);remove("work/capture");wave=fopen("work/wave.tmp","w");if(!wave)fail("wave");fputs("[",wave);wave_left=140;wave_count=0;}}
    unsigned result=key|(held?128:0);
    return (int)result;
}
void panel_wave(int phi0,int q3,int pras,int pcas,int ldps,int address,int we,int data){
    if(!wave_left)return;
    fprintf(wave,"%s[%d,%d,%d,%d,%d,%d,%d,%d]",wave_count++?",":"",phi0,q3,pras,pcas,ldps,address,we,data);
    if(!--wave_left){fputs("]",wave);fclose(wave);if(rename("work/wave.tmp","work/wave.json"))fail("wave rename");}
}

#ifdef __cplusplus
}
#endif
