/* Expected records come only from the unchanged VICE timer, with no RTL
 * model linked into this generator. */
#include <stdio.h>
#include <stdint.h>
void cia_oracle_reset(void), cia_oracle_cycle(unsigned,unsigned,int);
unsigned cia_oracle_count(void), cia_oracle_latch(void), cia_oracle_started(void), cia_oracle_underflow(void);
static unsigned phi2;
static uint32_t random_state=0x6526c1a;
static unsigned random_word(void) {
    random_state ^= random_state<<13;
    random_state ^= random_state>>17;
    random_state ^= random_state<<5;
    return random_state;
}
static void emit(unsigned command,unsigned data,unsigned pulse) {
    unsigned previous_mode=phi2;
    if(command==4) { cia_oracle_reset(); previous_mode=0; phi2=0; }
    else {
        cia_oracle_cycle(command,data,pulse);
        if(command==3) phi2=!(data&0x20);
    }
    printf("%u %u %u %u %u %u %u %u\n",command,data,pulse,previous_mode,
        cia_oracle_count(),cia_oracle_latch(),cia_oracle_started(),cia_oracle_underflow());
}
int main(void) {
    for(unsigned load=0;load<256;++load) {
        emit(4,0,0); emit(1,load,0); emit(2,0,0); emit(3,(load&1)?0x19:0x11,0);
        for(unsigned i=0;i<load+8;++i) emit(0,0,0);
        emit(3,0,0); for(unsigned i=0;i<4;++i) emit(0,0,0);
    }
    emit(4,0,0);
    for(unsigned i=0;i<50000;++i) {
        unsigned choice=random_word()%8, command=choice<3?choice+1:0;
        unsigned data=random_word()&255;
        if(command==2 && (random_word()&1)) data=0;
        emit(command,data,!phi2 && (random_word()&1));
    }
    return 0;
}
