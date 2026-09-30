const $=id=>document.getElementById(id);
let current=null, switchData=0, panelInput=0, substitution=false, trap=false, busy=false;
const hex=(n,w=2)=>Number(n).toString(16).toUpperCase().padStart(w,'0');

function bits(container,count,interactive,onChange){
  for(let bit=count-1;bit>=0;bit--){
    const cell=document.createElement('div');cell.className='bit';
    const item=document.createElement(interactive?'button':'span');
    item.className=interactive?'switch':'led';item.dataset.bit=bit;
    if(interactive){item.type='button';item.setAttribute('aria-label',`Bit ${bit}`);item.onclick=()=>onChange(bit)}
    cell.append(item,document.createTextNode(String(bit)));container.append(cell);
  }
}
bits($('addressLamps'),14,false);
bits($('dataLamps'),8,false);
bits($('dataSwitches'),8,true,bit=>{switchData^=1<<bit;renderSwitches();send('SUB',{enabled:substitution,value:switchData})});
bits($('inputSwitches'),8,true,bit=>{panelInput^=1<<bit;renderSwitches();send('INPUT',{value:panelInput})});

function renderSwitches(){
  for(const [id,value] of [['dataSwitches',switchData],['inputSwitches',panelInput]])
    for(const el of $(id).querySelectorAll('.switch')){
      const on=!!(value&(1<<Number(el.dataset.bit)));el.classList.toggle('on',on);el.setAttribute('aria-pressed',String(on));
    }
  $('switchValue').textContent=hex(switchData);$('inputValue').textContent=hex(panelInput);
}
function render(s){
  current=s;
  $('pc').textContent=hex(s.pc,4);$('a').textContent=hex(s.a);$('flags').textContent=s.flags.toString(2).padStart(4,'0');
  $('instructions').textContent=s.instructions.toLocaleString();
  $('addressValue').textContent=hex(s.address,4);$('dataValue').textContent=hex(s.data);
  $('outputPort').textContent=`PORT ${s.lastOutputPort}`;$('outputData').textContent=hex(s.lastOutputData);
  $('statusText').textContent=s.halted?'STOPPED':s.running?'RUN':'WAIT';
  $('statusLamp').className='status-lamp '+(s.running?'on':'wait');
  for(const [id,value] of [['addressLamps',s.address],['dataLamps',s.data]])
    for(const el of $(id).querySelectorAll('.led'))el.classList.toggle('on',!!(value&(1<<Number(el.parentElement.textContent))));
  for(const el of $('cycles').children)el.classList.toggle('active',!!s[el.dataset.key]);
  $('memory').replaceChildren(...s.memory.map(v=>{const e=document.createElement('span');e.textContent=hex(v);return e}));
  $('ram').replaceChildren(...s.ram.map(v=>{const e=document.createElement('span');e.textContent=hex(v);return e}));
  $('portGrid').replaceChildren(...s.outputs.map((v,i)=>{const e=document.createElement('span');e.textContent=hex(v);e.title=`Port ${i+8}`;e.className=i+8===s.lastOutputPort?'changed':'';return e}));
  $('auto').classList.toggle('selected',s.running);
  $('trap').textContent=s.trapEnabled?'TRAP ON':'TRAP OFF';$('trap').classList.toggle('selected',s.trapEnabled);
  $('sub').textContent=s.substitution?'SUB ON':'SUB OFF';$('sub').classList.toggle('selected',s.substitution);
}
async function send(action,extra={}){
  if(busy)return;busy=true;
  try{const response=await fetch('/api/control',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({action,...extra})});const s=await response.json();if(!response.ok)throw Error(s.error||response.status);render(s);$('error').textContent=''}
  catch(err){$('error').textContent=String(err)}finally{busy=false}
}
async function poll(){
  if(busy)return;
  try{const response=await fetch('/api/state');const s=await response.json();if(!response.ok)throw Error(s.error||response.status);render(s);$('error').textContent=''}
  catch(err){$('error').textContent=String(err)}
}
$('auto').onclick=()=>send('AUTO');$('pause').onclick=()=>send('PAUSE');$('init').onclick=()=>send('RESET');
$('step').onclick=()=>send(document.querySelector('input[name=stepMode]:checked').value==='cycle'?'CYCLE':'STEP');
$('trap').onclick=()=>{const addr=parseInt($('trapAddress').value,16);if(!Number.isInteger(addr)||addr<0||addr>0x3fff){$('error').textContent='Trap address must be 0000–3FFF';return}trap=!trap;send('TRAP',{enabled:trap,address:addr})};
$('sub').onclick=()=>{substitution=!substitution;send('SUB',{enabled:substitution,value:switchData})};
renderSwitches();poll();setInterval(poll,180);
