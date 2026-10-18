const $=id=>document.getElementById(id);
const canvas=$('display'),ctx=canvas.getContext('2d',{alpha:false});
const colors=['#000000','#0000aa','#00aa00','#00aaaa','#aa0000','#aa00aa','#aa5500','#aaaaaa','#555555','#5555ff','#55ff55','#55ffff','#ff5555','#ff55ff','#ffff55','#ffffff'];
let font=new Uint8Array(8192),state=null,powered=false,polling=false;
const pressed=new Set();
let audio=null,oscillator=null,gain=null;
function enableAudio(){if(!audio){audio=new AudioContext();oscillator=audio.createOscillator();gain=audio.createGain();oscillator.type='square';gain.gain.value=0;oscillator.connect(gain).connect(audio.destination);oscillator.start();}audio.resume();}
function speaker(s){if(!audio)return;const active=powered&&s.running&&$('sound').checked&&s.speakerHz>=20;gain.gain.setTargetAtTime(active?0.012:0,audio.currentTime,0.008);if(active)oscillator.frequency.setValueAtTime(Math.min(20000,s.speakerHz),audio.currentTime);}
const scan={Escape:1,Digit1:2,Digit2:3,Digit3:4,Digit4:5,Digit5:6,Digit6:7,Digit7:8,Digit8:9,Digit9:10,Digit0:11,Minus:12,Equal:13,Backspace:14,Tab:15,KeyQ:16,KeyW:17,KeyE:18,KeyR:19,KeyT:20,KeyY:21,KeyU:22,KeyI:23,KeyO:24,KeyP:25,BracketLeft:26,BracketRight:27,Enter:28,ControlLeft:29,ControlRight:29,KeyA:30,KeyS:31,KeyD:32,KeyF:33,KeyG:34,KeyH:35,KeyJ:36,KeyK:37,KeyL:38,Semicolon:39,Quote:40,Backquote:41,ShiftLeft:42,Backslash:43,KeyZ:44,KeyX:45,KeyC:46,KeyV:47,KeyB:48,KeyN:49,KeyM:50,Comma:51,Period:52,Slash:53,ShiftRight:54,NumpadMultiply:55,AltLeft:56,AltRight:56,Space:57,CapsLock:58,F1:59,F2:60,F3:61,F4:62,F5:63,F6:64,F7:65,F8:66,F9:67,F10:68,NumLock:69,ScrollLock:70,Home:71,Numpad7:71,ArrowUp:72,Numpad8:72,PageUp:73,Numpad9:73,NumpadSubtract:74,ArrowLeft:75,Numpad4:75,Numpad5:76,ArrowRight:77,Numpad6:77,NumpadAdd:78,End:79,Numpad1:79,ArrowDown:80,Numpad2:80,PageDown:81,Numpad3:81,Insert:82,Numpad0:82,Delete:83,NumpadDecimal:83};
async function request(url,body){const response=await fetch(url,body?{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)}:{});const result=await response.json();if(!response.ok)throw Error(result.error||response.statusText);return result;}
let pendingControl=Promise.resolve();
export function control(action,extra={}){pendingControl=pendingControl.then(async()=>{try{if(action==='RESET'||action==='OFF')clearHeld(false);const result=await request('/api/control',{action,...extra});update(result);$('error').hidden=true;return result;}catch(error){$('error').textContent=error.message;$('error').hidden=false;}});return pendingControl;}
export function currentState(){return state;}
function render(s){
 const ram=Uint8Array.from(s.vram.match(/../g),v=>parseInt(v,16)),image=ctx.createImageData(640,400),pixels=image.data;
 const put=(x,y,color)=>{const c=colors[color],p=(y*640+x)*4;pixels[p]=parseInt(c.slice(1,3),16);pixels[p+1]=parseInt(c.slice(3,5),16);pixels[p+2]=parseInt(c.slice(5,7),16);pixels[p+3]=255;};
 const start=((s.crtc[12]<<8)|s.crtc[13])&8191,cursor=((s.crtc[14]<<8)|s.crtc[15])&8191,blink=Math.floor(s.cycles/2386363)%2===0;
 if(!(s.mode&8)){ctx.fillStyle='#060b0b';ctx.fillRect(0,0,640,400);return;}
 if(!(s.mode&2)){
  const cols=s.mode&1?80:40,scale=cols===80?1:2;
  for(let row=0;row<25;row++)for(let col=0;col<cols;col++){
   const cell=(start+row*cols+col)&8191,ch=ram[(cell*2)&16383],attribute=ram[(cell*2+1)&16383],fg=attribute&15,bg=(attribute>>4)&(s.mode&32?7:15),hide=(s.mode&32)&&(attribute&128)&&!blink;
   for(let y=0;y<8;y++){let bits=hide?0:font[6144+ch*8+y];if(cell===cursor && !(s.crtc[10]&32) && blink && y>=(s.crtc[10]&31) && y<=(s.crtc[11]&31))bits=255;
    for(let x=0;x<8;x++)for(let dx=0;dx<scale;dx++)for(let dy=0;dy<2;dy++)put((col*8+x)*scale+dx,row*16+y*2+dy,bits&(128>>x)?fg:bg);
   }
  }
 }else{
  const hires=!!(s.mode&16),width=hires?640:320,background=s.palette&15,intense=s.palette&16?8:0,palette=s.mode&4?[3,4,7]:s.palette&32?[3,5,7]:[2,4,6];
  for(let y=0;y<200;y++)for(let x=0;x<width;x++){
   const offset=((y&1)*8192+(y>>1)*80+(hires?x>>3:x>>2)+(start*2))&16383,byte=ram[offset];let color;
   if(hires)color=byte&(128>>(x&7))?background:0;
   else{const value=(byte>>(6-2*(x&3)))&3;color=value?palette[value-1]+intense:background;}
   for(let dx=0;dx<(hires?1:2);dx++)for(let dy=0;dy<2;dy++)put(x*(hires?1:2)+dx,y*2+dy,color);
  }
 }
 ctx.putImageData(image,0,0);
}
function update(s){state=s;powered=!!s.powered;render(s);speaker(s);$('overlay').style.display=powered?'none':'flex';$('monitor-led').classList.toggle('on',powered);$('power').classList.toggle('on',powered);$('power').setAttribute('aria-label',powered?'Power off':'Power on');$('status').classList.toggle('active',powered&&s.running);$('status').lastChild.textContent=!powered?'POWER OFF':s.fault?'CPU STOPPED':s.running?'RUNNING · ORIGINAL FIRMWARE':'PAUSED';$('pause').textContent=s.running?'Pause':'Run';for(const id of ['pause','step','reset'])$(id).disabled=!powered;$('drive-a').classList.toggle('active',powered&&!!(s.dor&16));$('drive-b').classList.toggle('active',powered&&!!(s.dor&32));$('address').textContent=s.cs.toString(16).padStart(4,'0').toUpperCase()+':'+s.ip.toString(16).padStart(4,'0').toUpperCase();$('instructions').textContent=s.instructions.toLocaleString();$('dma').textContent=s.refresh.toLocaleString()+' / '+s.dma.toLocaleString();}
$('power').onclick=async()=>{const on=!powered;if(on)enableAudio();await control(on?'RESET':'OFF');if(on)await control('AUTO');};
$('pause').onclick=()=>{enableAudio();control(state?.running?'PAUSE':'AUTO');};$('step').onclick=()=>control('STEP');$('reset').onclick=async()=>{await control('RESET');await control('AUTO');};$('sound').onchange=()=>{enableAudio();if(state)speaker(state);};
$('details-toggle').onclick=()=>{$('details').hidden=!$('details').hidden;};
$('screen').onclick=()=>{$('screen').focus();$('keyboard-hint').textContent='Keyboard connected · Esc, Ctrl and function keys supported';};
document.addEventListener('keydown',e=>{if(!powered||document.activeElement!==$('screen')||!scan[e.code])return;e.preventDefault();if(pressed.has(e.code)&&!e.repeat)return;pressed.add(e.code);document.querySelector(`[data-code="${e.code}"]`)?.classList.add('pressed');control('KEY',{codes:[scan[e.code]]});});
document.addEventListener('keyup',e=>{if(!pressed.has(e.code))return;e.preventDefault();pressed.delete(e.code);document.querySelector(`[data-code="${e.code}"]`)?.classList.remove('pressed');control('KEY',{codes:[scan[e.code]|128]});});
function clearHeld(release){const codes=[...new Set([...pressed,...virtualMods])].map(code=>scan[code]|128);pressed.clear();virtualMods.clear();document.querySelectorAll('.key.pressed').forEach(key=>{key.classList.remove('pressed');key.setAttribute('aria-pressed','false');});if(release&&powered&&codes.length)control('KEY',{codes});}
window.addEventListener('blur',()=>clearHeld(true));
const rows=[['Esc','1','2','3','4','5','6','7','8','9','0','−','=','Backspace'],['Tab','Q','W','E','R','T','Y','U','I','O','P','[',']','Enter'],['Ctrl','A','S','D','F','G','H','J','K','L',';',"'",'`','\\'],['Shift','Z','X','C','V','B','N','M',',','.','/','Shift','*'],['Alt','Space','Caps']];
const labels={Esc:'Escape','−':'Minus','=':'Equal',Ctrl:'ControlLeft',Shift:'ShiftLeft',Alt:'AltLeft',Space:'Space',Caps:'CapsLock',Num:'NumLock','←':'ArrowLeft','→':'ArrowRight','↑':'ArrowUp','↓':'ArrowDown',Del:'Delete','[':'BracketLeft',']':'BracketRight',';':'Semicolon',"'":'Quote','`':'Backquote','\\':'Backslash',',':'Comma','.':'Period','/':'Slash'};
const virtualMods=new Set();
function keyButton(label,code){const button=document.createElement('button');button.className='key'+(['Tab','Ctrl','Shift','Alt','Caps','Num','Scroll','Esc','Enter','Backspace'].includes(label)?' dark wide':'')+(label==='Space'?' space':'');button.textContent=label==='Space'?'':label;button.setAttribute('aria-label',label);button.dataset.code=code;button.onclick=()=>{if(!powered)return;if(['ShiftLeft','ShiftRight','ControlLeft','AltLeft'].includes(code)){const held=virtualMods.has(code);if(held)virtualMods.delete(code);else virtualMods.add(code);button.classList.toggle('pressed',!held);button.setAttribute('aria-pressed',String(!held));control('KEY',{codes:[scan[code]|(held?128:0)]});}else{const codes=[scan[code],scan[code]|128];for(const mod of [...virtualMods])if(mod.startsWith('Shift')){codes.push(scan[mod]|128);virtualMods.delete(mod);const key=document.querySelector(`[data-code="${mod}"]`);key?.classList.remove('pressed');key?.setAttribute('aria-pressed','false');}control('KEY',{codes});}};return button;}
const functions=document.createElement('div');functions.className='function-bank';for(let i=1;i<=10;i++)functions.append(keyButton('F'+i,'F'+i));$('keyboard').append(functions);
const main=document.createElement('div');main.className='main-bank';for(const row of rows){const element=document.createElement('div');element.className='key-row';for(let i=0;i<row.length;i++){const label=row[i],code=label==='*'?'NumpadMultiply':label==='Shift'&&i>0?'ShiftRight':labels[label]||(/^[A-Z]$/.test(label)?'Key'+label:/^[0-9]$/.test(label)?'Digit'+label:label);element.append(keyButton(label,code));}main.append(element);}$('keyboard').append(main);
const numpad=document.createElement('div');numpad.className='number-bank';for(const label of ['Num','Scroll','−','7','8','9','4','5','6','1','2','3','0','.','+']){const code=label==='Num'?'NumLock':label==='Scroll'?'ScrollLock':label==='−'?'NumpadSubtract':label==='+'?'NumpadAdd':label==='.'?'NumpadDecimal':'Numpad'+label;numpad.append(keyButton(label,code));}$('keyboard').append(numpad);
async function poll(){if(polling)return;polling=true;try{update(await request('/api/state'));$('error').hidden=true;}catch(error){$('error').textContent=error.message;$('error').hidden=false;}finally{polling=false;setTimeout(poll,80);}}
font=new Uint8Array(await(await fetch('/api/font')).arrayBuffer());poll();
for(const [id,drive] of [['mount-a',0],['mount-b',1]])$(id).onchange=async()=>{const file=$(id).files[0];if(!file)return;try{if(![184320,368640].includes(file.size))throw Error('Use a 180 KB or 360 KB image.');const response=await fetch('/api/disk/'+drive,{method:'POST',body:file});const result=await response.json();if(!response.ok)throw Error(result.error);update(result);$('disk-hint').textContent=file.name+' mounted. Press Reset to boot, or Run to continue.';$('error').hidden=true;}catch(error){$('error').textContent=error.message;$('error').hidden=false;}$(id).value='';};

setInterval(()=>{if(state)$("fpu-state").textContent=`8087: ${state.fpuCommands.toLocaleString()} instructions · Disk: ${state.hdReads.toLocaleString()} bytes read / ${state.hdWrites.toLocaleString()} written`;},500);

$("eject-a").onclick=()=>control("EJECT",{drive:0});
