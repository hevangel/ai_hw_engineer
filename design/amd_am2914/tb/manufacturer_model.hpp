// Generic interpreter of the independently transcribed manufacturer actions.
// Native input/phase contract and source provenance: references/README.md.
#include "manufacturer_actions.hpp"
struct Inputs {
 unsigned op=0,m=0,s=0,p=255,ie=1,lb=1,ge=0,gar=0,id=1;
};
struct Pins {
 unsigned m,s,v,mo,so,vo,irq,gs,gas,rd,pd,sv;
};
struct Manufacturer {
 unsigned mask=0,status=0,group=0,enabled=1,held=0,vce=0,sv=1,pending=0,pulse=0,sample=0;
 static unsigned field(unsigned a,unsigned shift,unsigned bits){return(a>>shift)&((1u<<bits)-1);}
 static unsigned priority(unsigned request){unsigned code=0;while(request>>1){++code;request>>=1;}return code;}
 unsigned action(const Inputs&i)const{return i.ie?0:actions[i.op];}
 unsigned clear(const Inputs&i)const{
  switch(field(action(i),CLEAR_SHIFT,3)){
   case 1:return 255;case 2:return i.m;case 3:return mask;case 4:return vce?(1u<<held):0;default:return 0;
  }
 }
 Pins pins(const Inputs&i)const{
  unsigned request=pending&(~mask&255),v=priority(request),pass=request!=0 && v>=status;
  unsigned eligible=pass && i.id,a=action(i),read=field(a,VECTOR_SHIFT,2)==2;
  return{mask,status,v,field(a,M_OUTPUT_SHIFT,1),field(a,S_OUTPUT_SHIFT,1)&&!group,
         read&&eligible,eligible&&enabled,group,!(read&&eligible&&v==7),
         i.id && group && !pass,!group || pass,sv};
 }
 void phase(const Inputs&i,bool high){
  unsigned resets=(i.lb?255:0)|(high?0:clear(i));
  pulse=((~i.p)&255)|(pulse&~resets);
  if(!high)sample=pulse&~clear(i)&255;
 }
 void edge(const Inputs&i){
  unsigned a=action(i);Pins old=pins(i);
  switch(field(a,MASK_SHIFT,3)){
   case 1:mask=0;break;case 2:mask=255;break;case 3:mask&=~i.m;break;
   case 4:mask|=i.m;break;case 5:mask=i.m;break;default:break;
  }
  switch(field(a,STATUS_SHIFT,2)){
   case 1:status=0;break;case 2:status=i.ge?0:i.s;break;
   case 3:status=old.vo?((old.v+1)&7):0;break;default:break;
  }
  switch(field(a,GROUP_SHIFT,2)){
   case 1:group=i.gar;break;case 2:group=i.ge;break;
   // Functional description's no-interrupt rule uses pre-edge unmasked state.
   case 3:group=(!i.id)||(!old.gas)||(i.gar && (pending&(~(old.m)&255))==0);break;
   default:break;
  }
  switch(field(a,IRQ_SHIFT,2)){case 1:enabled=1;break;case 2:enabled=0;break;default:break;}
  switch(field(a,VECTOR_SHIFT,2)){
   case 1:held=0;vce=0;break;case 2:held=old.v;vce=old.vo;break;default:break;
  }
  switch(field(a,OVERFLOW_SHIFT,2)){case 1:sv=1;break;case 2:if(!old.gas)sv=0;break;default:break;}
  pending=sample;
 }
};
