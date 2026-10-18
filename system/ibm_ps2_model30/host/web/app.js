const $=id=>document.getElementById(id);
const canvas=$('display'),ctx=canvas.getContext('2d',{alpha:false});
const colors=['#000000','#0000aa','#00aa00','#00aaaa','#aa0000','#aa00aa','#aa5500','#aaaaaa','#555555','#5555ff','#55ff55','#55ffff','#ff5555','#ff55ff','#ffff55','#ffffff'];
let state=null,powered=false,polling=false;
const pressed=new Set();
let audio=null,oscillator=null,gain=null;
function enableAudio(){if(!audio){audio=new AudioContext();oscillator=audio.createOscillator();gain=audio.createGain();oscillator.type='square';gain.gain.value=0;oscillator.connect(gain).connect(audio.destination);oscillator.start();}audio.resume();}
function speaker(s){if(!audio)return;const active=powered&&s.running&&$('sound').checked&&s.speakerHz>=20;gain.gain.setTargetAtTime(active?0.012:0,audio.currentTime,0.008);if(active)oscillator.frequency.setValueAtTime(Math.min(20000,s.speakerHz),audio.currentTime);}
const scan={Escape:1,Digit1:2,Digit2:3,Digit3:4,Digit4:5,Digit5:6,Digit6:7,Digit7:8,Digit8:9,Digit9:10,Digit0:11,Minus:12,Equal:13,Backspace:14,Tab:15,KeyQ:16,KeyW:17,KeyE:18,KeyR:19,KeyT:20,KeyY:21,KeyU:22,KeyI:23,KeyO:24,KeyP:25,BracketLeft:26,BracketRight:27,Enter:28,ControlLeft:29,ControlRight:29,KeyA:30,KeyS:31,KeyD:32,KeyF:33,KeyG:34,KeyH:35,KeyJ:36,KeyK:37,KeyL:38,Semicolon:39,Quote:40,Backquote:41,ShiftLeft:42,Backslash:43,KeyZ:44,KeyX:45,KeyC:46,KeyV:47,KeyB:48,KeyN:49,KeyM:50,Comma:51,Period:52,Slash:53,ShiftRight:54,NumpadMultiply:55,AltLeft:56,AltRight:56,Space:57,CapsLock:58,F1:59,F2:60,F3:61,F4:62,F5:63,F6:64,F7:65,F8:66,F9:67,F10:68,NumLock:69,ScrollLock:70,Home:71,Numpad7:71,ArrowUp:72,Numpad8:72,PageUp:73,Numpad9:73,NumpadSubtract:74,ArrowLeft:75,Numpad4:75,Numpad5:76,ArrowRight:77,Numpad6:77,NumpadAdd:78,End:79,Numpad1:79,ArrowDown:80,Numpad2:80,PageDown:81,Numpad3:81,Insert:82,Numpad0:82,Delete:83,NumpadDecimal:83};
async function request(url,body){const response=await fetch(url,body?{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)}:{});const result=await response.json();if(!response.ok)throw Error(result.error||response.statusText);return result;}
let pendingControl=Promise.resolve();
export function control(action,extra={}){pendingControl=pendingControl.then(async()=>{try{if(action==='RESET'||action==='OFF')clearHeld(false);const result=await request('/api/control',{action,...extra});update(result);$('error').hidden=true;return result;}catch(error){$('error').textContent=error.message;$('error').hidden=false;}});return pendingControl;}
export function currentState(){return state;}
function unhex(text){const bytes=new Uint8Array(text.length/2);for(let i=0;i<bytes.length;i++)bytes[i]=parseInt(text.slice(i*2,i*2+2),16);return bytes;}
function render(s){
 const ram=unhex(s.vram),font=unhex(s.font),height=s.graphicsMode===2?480:400;
 if(canvas.height!==height)canvas.height=height;
 const image=ctx.createImageData(640,height),pixels=image.data;
 const put=(x,y,color)=>{const p=(y*640+x)*4;for(let c=0;c<3;c++){const v=s.dac[(color&255)*3+c]||0;pixels[p+c]=(v<<2)|(v>>4);}pixels[p+3]=255;};
 const start=((s.crtc[12]<<8)|s.crtc[13])&16383,cursor=((s.crtc[14]<<8)|s.crtc[15])&16383,blink=Math.floor(s.cycles/4000000)%2===0;
 if(!(s.mode&8)){ctx.fillStyle='#060b0b';ctx.fillRect(0,0,640,height);return;}
 if(s.graphicsMode===0){
  const cols=s.mode&1?80:40,scale=cols===80?1:2;
  for(let row=0;row<25;row++)for(let col=0;col<cols;col++){
   const cell=(start+row*cols+col)&16383,ch=ram[32768+((cell*2)&32767)],attribute=ram[32768+((cell*2+1)&32767)];
   const dual=!!(s.crtc[18]&16),page=dual?(attribute>>3)&1:(s.crtc[18]>>5)&1,fg=attribute&(dual?7:15),bg=(attribute>>4)&(s.mode&32?7:15),hide=(s.mode&32)&&(attribute&128)&&!blink;
   for(let y=0;y<16;y++){let bits=hide?0:font[page*4096+ch*16+y];if(cell===cursor&&!(s.crtc[10]&32)&&blink&&(y>>1)>=(s.crtc[10]&15)&&(y>>1)<=(s.crtc[11]&15))bits=255;
    for(let x=0;x<8;x++)for(let dx=0;dx<scale;dx++)put((col*8+x)*scale+dx,row*16+y,bits&(128>>x)?fg:bg);
   }
  }
 }else if(s.graphicsMode===3){
  for(let y=0;y<200;y++)for(let x=0;x<320;x++)for(let dx=0;dx<2;dx++)for(let dy=0;dy<2;dy++)put(x*2+dx,y*2+dy,ram[(start*2+y*320+x)&65535]);
 }else if(s.graphicsMode===2){
  const fg=s.mode&4?7:s.palette&15;
  for(let y=0;y<480;y++)for(let x=0;x<640;x++)put(x,y,ram[(start*2+y*80+(x>>3))&65535]&(128>>(x&7))?fg:0);
 }else{
  const hires=!!(s.mode&16),width=hires?640:320,background=s.palette&15,intense=s.palette&16?8:0,palette=s.palette&32?[3,5,7]:[2,4,6];
  for(let y=0;y<200;y++)for(let x=0;x<width;x++){
   const offset=32768+(((y&1)*8192+(y>>1)*80+(hires?x>>3:x>>2)+start*2)&32767),byte=ram[offset];let color;
   if(hires)color=byte&(128>>(x&7))?(s.mode&4?7:background):0;
   else{const value=(byte>>(6-2*(x&3)))&3;color=value?palette[value-1]+intense:background;}
   for(let dx=0;dx<(hires?1:2);dx++)for(let dy=0;dy<2;dy++)put(x*(hires?1:2)+dx,y*2+dy,color);
  }
 }
 ctx.putImageData(image,0,0);
}
function update(s){state=s;powered=!!s.powered;render(s);speaker(s);$('overlay').style.display=powered?'none':'flex';$('monitor-led').classList.toggle('on',powered);$('power').classList.toggle('on',powered);$('power').setAttribute('aria-label',powered?'Power off':'Power on');$('status').classList.toggle('active',powered&&s.running);$('status').lastChild.textContent=!powered?'POWER OFF':s.fault?'CPU STOPPED':s.running?'RUNNING · ORIGINAL FIRMWARE':'PAUSED';$('pause').textContent=s.running?'Pause':'Run';for(const id of ['pause','step','reset'])$(id).disabled=!powered;$('drive-a').classList.toggle('active',powered&&!!(s.dor&16));$('drive-b').classList.toggle('active',powered&&!!(s.dor&32));$('drive-c').classList.toggle('active',powered&&s.hardDiskBusy);$('floppy-a-label').textContent=(s.diskInserted&1)?'720 KB DISKETTE':'NO DISKETTE';$('eject-a').disabled=!(s.diskInserted&1);for(const id of ['floppy-b','mount-b-label','save-b'])$(id).hidden=!(s.floppyDrives&2);$('harddrive').hidden=!s.hardDiskPresent;$('address').textContent=s.cs.toString(16).padStart(4,'0').toUpperCase()+':'+s.ip.toString(16).padStart(4,'0').toUpperCase();$('instructions').textContent=s.instructions.toLocaleString();$('dma').textContent=s.refresh.toLocaleString()+' / '+s.dma.toLocaleString();}
$('power').onclick=async()=>{const on=!powered;if(on)enableAudio();await control(on?'RESET':'OFF');if(on)await control('AUTO');};
$('pause').onclick=()=>{enableAudio();control(state?.running?'PAUSE':'AUTO');};$('step').onclick=()=>control('STEP');$('reset').onclick=async()=>{await control('RESET');await control('AUTO');};$('sound').onchange=()=>{enableAudio();if(state)speaker(state);};
$('details-toggle').onclick=()=>{$('details').hidden=!$('details').hidden;};
$('screen').onclick=()=>{$('screen').focus();$('keyboard-hint').textContent='Keyboard connected · Esc, Ctrl and function keys supported';};
const extended=new Set(['ControlRight','AltRight','NumpadEnter','NumpadDivide','Home','End','PageUp','PageDown','Insert','Delete','ArrowUp','ArrowDown','ArrowLeft','ArrowRight']);
Object.assign(scan,{F11:87,F12:88,NumpadEnter:28,NumpadDivide:53,PrintScreen:55,Pause:69});
const set2={Escape:118,F1:5,F2:6,F3:4,F4:12,F5:3,F6:11,F7:131,F8:10,F9:1,F10:9,F11:120,F12:7,Backquote:14,Digit1:22,Digit2:30,Digit3:38,Digit4:37,Digit5:46,Digit6:54,Digit7:61,Digit8:62,Digit9:70,Digit0:69,Minus:78,Equal:85,Backspace:102,Tab:13,KeyQ:21,KeyW:29,KeyE:36,KeyR:45,KeyT:44,KeyY:53,KeyU:60,KeyI:67,KeyO:68,KeyP:77,BracketLeft:84,BracketRight:91,Backslash:93,CapsLock:88,KeyA:28,KeyS:27,KeyD:35,KeyF:43,KeyG:52,KeyH:51,KeyJ:59,KeyK:66,KeyL:75,Semicolon:76,Quote:82,Enter:90,ShiftLeft:18,KeyZ:26,KeyX:34,KeyC:33,KeyV:42,KeyB:50,KeyN:49,KeyM:58,Comma:65,Period:73,Slash:74,ShiftRight:89,ControlLeft:20,ControlRight:20,AltLeft:17,AltRight:17,Space:41,NumLock:119,ScrollLock:126,NumpadDivide:74,NumpadMultiply:124,NumpadSubtract:123,NumpadAdd:121,NumpadEnter:90,Numpad7:108,Numpad8:117,Numpad9:125,Numpad4:107,Numpad5:115,Numpad6:116,Numpad1:105,Numpad2:114,Numpad3:122,Numpad0:112,NumpadDecimal:113,Home:108,ArrowUp:117,PageUp:125,ArrowLeft:107,ArrowRight:116,End:105,ArrowDown:114,PageDown:122,Insert:112,Delete:113};
function keyBytes(code,release=false){
 const second=state?.scanSet!==1;
 if(code==='Pause')return release?[]:second?[225,20,119,225,240,20,240,119]:[225,29,69,225,157,197];
 if(code==='PrintScreen')return second?(release?[224,240,124,224,240,18]:[224,18,224,124]):(release?[224,183,224,170]:[224,42,224,55]);
 const value=second?set2[code]:scan[code];if(value===undefined)return[];
 return [...(extended.has(code)?[224]:[]),...(release&&second?[240]:[]),release&&!second?value|128:value];
}
function sendKey(code,release=false){const codes=keyBytes(code,release);if(codes.length)control('KEY',{codes});}
document.addEventListener('keydown',e=>{if(!powered||document.activeElement!==$('screen')||!scan[e.code])return;e.preventDefault();if(pressed.has(e.code)&&!e.repeat)return;pressed.add(e.code);document.querySelector(`[data-code="${e.code}"]`)?.classList.add('pressed');sendKey(e.code);});
document.addEventListener('keyup',e=>{if(!pressed.has(e.code))return;e.preventDefault();pressed.delete(e.code);document.querySelector(`[data-code="${e.code}"]`)?.classList.remove('pressed');sendKey(e.code,true);});
const virtualMods=new Set();
function clearHeld(release){const codes=[...new Set([...pressed,...virtualMods])].flatMap(code=>keyBytes(code,true));pressed.clear();virtualMods.clear();document.querySelectorAll('.key.pressed').forEach(key=>{key.classList.remove('pressed');key.setAttribute('aria-pressed','false');});if(release&&powered&&codes.length)control('KEY',{codes});}
window.addEventListener('blur',()=>clearHeld(true));
const labels={Esc:'Escape','−':'Minus','=':'Equal',Ctrl:'ControlLeft',Shift:'ShiftLeft',Alt:'AltLeft',Space:'Space',Caps:'CapsLock',Num:'NumLock','←':'ArrowLeft','→':'ArrowRight','↑':'ArrowUp','↓':'ArrowDown',Del:'Delete','[':'BracketLeft',']':'BracketRight',';':'Semicolon',"'":'Quote','`':'Backquote','\\':'Backslash',',':'Comma','.':'Period','/':'Slash'};
function keyButton(label,code){const button=document.createElement('button');button.className='key'+(['Tab','Ctrl','Shift','Alt','Caps','Num','Esc','Enter','Backspace'].includes(label)?' dark wide':'')+(label==='Space'?' space':'');button.textContent=label==='Space'?'':label;button.setAttribute('aria-label',label);button.dataset.code=code;button.onclick=()=>{if(!powered)return;if(/^(Shift|Control|Alt)/.test(code)){const held=virtualMods.has(code);if(held)virtualMods.delete(code);else virtualMods.add(code);button.classList.toggle('pressed',!held);button.setAttribute('aria-pressed',String(!held));sendKey(code,held);}else{const codes=[...keyBytes(code),...keyBytes(code,true)];for(const mod of [...virtualMods])if(mod.startsWith('Shift')){codes.push(...keyBytes(mod,true));virtualMods.delete(mod);const key=document.querySelector(`[data-code="${mod}"]`);key?.classList.remove('pressed');key?.setAttribute('aria-pressed','false');}if(codes.length)control('KEY',{codes});}};return button;}
const functions=document.createElement('div');functions.className='function-bank';functions.append(keyButton('Esc','Escape'));for(let i=1;i<=12;i++)functions.append(keyButton('F'+i,'F'+i));for(const [label,code]of [['Print','PrintScreen'],['Scroll','ScrollLock'],['Pause','Pause']])functions.append(keyButton(label,code));$('keyboard').append(functions);
const rows=[['`','1','2','3','4','5','6','7','8','9','0','−','=','Backspace'],['Tab','Q','W','E','R','T','Y','U','I','O','P','[',']','\\'],['Caps','A','S','D','F','G','H','J','K','L',';',"'",'Enter'],['Shift','Z','X','C','V','B','N','M',',','.','/','Shift'],['Ctrl','Alt','Space','Alt','Ctrl']];
const main=document.createElement('div');main.className='main-bank';for(const row of rows){const element=document.createElement('div');element.className='key-row';for(let i=0;i<row.length;i++){const label=row[i],code=(label==='Shift'&&i>0?'ShiftRight':label==='Ctrl'&&i>0?'ControlRight':label==='Alt'&&i>1?'AltRight':labels[label])||(/^[A-Z]$/.test(label)?'Key'+label:/^[0-9]$/.test(label)?'Digit'+label:label);element.append(keyButton(label,code));}main.append(element);}$('keyboard').append(main);
const navigation=document.createElement('div');navigation.className='navigation-bank';for(const [label,code]of [['Ins','Insert'],['Home','Home'],['PgUp','PageUp'],['Del','Delete'],['End','End'],['PgDn','PageDown'],['↑','ArrowUp'],['←','ArrowLeft'],['↓','ArrowDown'],['→','ArrowRight']])navigation.append(keyButton(label,code));$('keyboard').append(navigation);
const numpad=document.createElement('div');numpad.className='number-bank';for(const label of ['Num','/','*','−','7','8','9','+','4','5','6','1','2','3','Enter','0','.']){const code=label==='Num'?'NumLock':label==='−'?'NumpadSubtract':label==='+'?'NumpadAdd':label==='*'?'NumpadMultiply':label==='/'?'NumpadDivide':label==='Enter'?'NumpadEnter':label==='.'?'NumpadDecimal':'Numpad'+label;const key=keyButton(label,code);if(label==='+'||label==='Enter')key.classList.add('tall');if(label==='0')key.classList.add('zero');numpad.append(key);}$('keyboard').append(numpad);
async function poll(){if(polling)return;polling=true;try{update(await request('/api/state'));$('error').hidden=true;}catch(error){$('error').textContent=error.message;$('error').hidden=false;}finally{polling=false;setTimeout(poll,80);}}
poll();
for(const [id,drive] of [['mount-a',0],['mount-b',1]])$(id).onchange=async()=>{const file=$(id).files[0];if(!file)return;try{if(file.size!==737280)throw Error('Use a 720 KB double-sided image (737280 bytes).');const response=await fetch('/api/disk/'+drive,{method:'POST',body:file});const result=await response.json();if(!response.ok)throw Error(result.error);update(result);$('disk-hint').textContent=file.name+' mounted. Press Reset to boot, or Run to continue.';$('error').hidden=true;}catch(error){$('error').textContent=error.message;$('error').hidden=false;}$(id).value='';};

$('eject-a').onclick=async()=>{try{const result=await control('EJECT',{drive:0});if(!result)return;$('disk-hint').textContent='Drive A is empty. Reset to boot from the hard disk.';}catch(error){$('error').textContent=error.message;$('error').hidden=false;}};
$('mount-hdd').onchange=async()=>{const file=$('mount-hdd').files[0];if(!file)return;try{if(![21307392,21806800].includes(file.size))throw Error('Use a type-26 20 MB raw image or a complete .m30 bundle.');const response=await fetch('/api/disk/2',{method:'POST',body:file});const result=await response.json();if(!response.ok)throw Error(result.error);update(result);$('disk-hint').textContent=file.name+' mounted. Eject A and Reset to boot C.';$('error').hidden=true;}catch(error){$('error').textContent=error.message;$('error').hidden=false;}$('mount-hdd').value='';};
