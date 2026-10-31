const $=id=>document.getElementById(id);
let current=null, trap=false, busy=false, ttyShown='';
const hex=(n,w=2)=>Number(n).toString(16).toUpperCase().padStart(w,'0');

// The 1974 PCC *STARS* listing, adapted to SCELBAL's dialect (see
// spec/reference/shooting_stars.bas — this string must stay in sync).
const STARS_PROGRAM =
`100 PRINT "WELCOME TO MY GALAXY. I'M IN CHARGE OF THE STARS HERE."
110 PRINT "PLAY MY GAME *STARS* AND GET SOME STARS FOR YOURSELF!"
120 PRINT
130 PRINT "WHAT TO KNOW HOW TO PLAY? TYPE 1 TO SEE RULES, 0 TO PLAY.";
140 INPUT Z
150 IF Z = 0 GOTO 290
160 PRINT
170 PRINT "I WILL THINK OF A WHOLE NUMBER FROM 1 TO 100."
180 PRINT "TRY TO GUESS MY NUMBER. AFTER YOU GUESS, I"
190 PRINT "WILL TYPE ONE OR MORE STARS (*). THE CLOSER"
200 PRINT "YOU ARE TO MY NUMBER, THE MORE STARS WILL I TYPE."
210 PRINT "ONE STAR (*) MEANS YOU ARE FAR AWAY FROM MY"
220 PRINT "NUMBER. SEVEN STARS (*******) MEANS YOU ARE VERY,"
230 PRINT "VERY, VERY CLOSE TO MY NUMBER!!!"
290 X = INT(100 * RND(0)) + 1
300 PRINT
310 PRINT "OK, STARSEEKER, I AM THINKING OF A NUMBER. START GUESSING."
320 N = 1
330 PRINT
340 PRINT "WHAT IS YOUR GUESS";
350 INPUT G
360 IF G = X GOTO 560
370 D = ABS(G - X)
380 IF D > 63 GOTO 500
390 IF D > 31 GOTO 490
400 IF D > 15 GOTO 480
410 IF D > 7 GOTO 470
420 IF D > 3 GOTO 460
430 IF D > 1 GOTO 450
440 PRINT " *";
450 PRINT " *";
460 PRINT " *";
470 PRINT " *";
480 PRINT " *";
490 PRINT " *";
500 PRINT " *";
510 PRINT
520 N = N + 1
530 GOTO 330
560 FOR K = 1 TO 18
570 PRINT " **";
580 NEXT K
590 PRINT "!!!"
600 PRINT "THAT'S IT!!! YOU GUESSED MY COSMIC NUMBER IN"; N; "GUESSES."
610 PRINT
620 PRINT "WANT TO PLAY AGAIN? TYPE 1 FOR YES, 0 FOR NO.";
630 INPUT Z
640 IF Z > 0 GOTO 290
650 PRINT "OK, GOODBYE FOR NOW. PLAY WITH ME AGAIN SOMESOON."
660 END
`;

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

function render(s){
  current=s;
  $('pc').textContent=hex(s.pc,4);$('a').textContent=hex(s.a);
  $('flags').textContent=s.flags.toString(2).padStart(4,'0');
  $('instructions').textContent=s.instructions.toLocaleString();
  $('cycleCount').textContent=s.cycles.toLocaleString();
  $('pending').textContent=s.pendingInput;
  $('addressValue').textContent=hex(s.address,4);$('dataValue').textContent=hex(s.data);
  $('statusText').textContent=s.halted?'STOPPED':s.running?'RUN':'WAIT';
  $('statusLamp').className='status-lamp '+(s.running?'on':'wait');
  for(const [id,value] of [['addressLamps',s.address],['dataLamps',s.data]])
    for(const el of $(id).querySelectorAll('.led'))el.classList.toggle('on',!!(value&(1<<Number(el.parentElement.textContent))));
  for(const el of $('cycles').children)el.classList.toggle('active',!!s[el.dataset.key]);
  $('memory').replaceChildren(...s.memory.map(v=>{const e=document.createElement('span');e.textContent=hex(v);return e}));
  $('auto').classList.toggle('selected',s.running);
  $('trap').textContent=s.trapEnabled?'TRAP ON':'TRAP OFF';$('trap').classList.toggle('selected',s.trapEnabled);
  renderTty(s.tty||'');
}
function renderTty(t){
  if(t===ttyShown)return;
  const grown=t.length>ttyShown.length&&t.startsWith(ttyShown);
  ttyShown=t;
  if(grown){
    // Fast path: only the new bytes.
    let text='';
    for(let i=ttyShown?ttyShown.length:0;i<t.length;i+=2){
      text+=String.fromCharCode(parseInt(t.substr(i,2),16)&0x7f);
    }
    appendTty(text.replace(/[^\x20-\x7e\n]/g,'·'));
  }else{
    const text=[...t.matchAll(/../g)].map(p=>String.fromCharCode(parseInt(p[0],16)&0x7f)).join('');
    $('ttyOut').textContent=text.replace(/[^\x20-\x7e\n]/g,'·');
    $('ttyOut').scrollTop=$('ttyOut').scrollHeight;
  }
}
function appendTty(text){
  if(!text)return;
  const el=$('ttyOut');
  el.textContent+=text;
  while(el.textContent.length>8000)el.textContent=el.textContent.slice(1000);
  el.scrollTop=el.scrollHeight;
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
async function ttySendText(text){
  if(!text)return;
  try{const response=await fetch('/api/tty',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({text})});const s=await response.json();if(!response.ok)throw Error(s.error||response.status);render(s);$('error').textContent=''}
  catch(err){$('error').textContent=String(err)}
}
$('ttySend').onclick=()=>{const v=$('ttyIn').value;$('ttyIn').value='';ttySendText(v+'\r')};
$('ttyIn').addEventListener('keydown',e=>{if(e.key==='Enter'){const v=$('ttyIn').value;$('ttyIn').value='';ttySendText(v+'\r')}});
for(const b of document.querySelectorAll('.digit'))
  b.onclick=()=>ttySendText(b.dataset.d==='-'?'-':b.dataset.d);
$('loadStars').onclick=async()=>{
  // SCR first, then the listing; the machine consumes at its own pace.
  await ttySendText('SCR\r');
  setTimeout(()=>ttySendText(STARS_PROGRAM),1500);
};
$('runProgram').onclick=()=>ttySendText('RUN\r');
$('auto').onclick=()=>send('AUTO');$('pause').onclick=()=>send('PAUSE');$('init').onclick=()=>send('RESET');
$('step').onclick=()=>send(document.querySelector('input[name=stepMode]:checked').value==='cycle'?'CYCLE':'STEP');
$('trap').onclick=()=>{const addr=parseInt($('trapAddress').value,16);if(!Number.isInteger(addr)||addr<0||addr>0x3fff){$('error').textContent='Trap address must be 0000–3FFF';return}trap=!trap;send('TRAP',{enabled:trap,address:addr})};
poll();setInterval(poll,180);
