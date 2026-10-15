import {control,currentState} from './app.js';

const panel=document.getElementById('waveform_panel');
const frame=document.getElementById('surfer_frame');
const capture=document.getElementById('waveform_capture');
const refresh=document.getElementById('waveform_refresh');
const status=document.getElementById('waveform_status');
const preset=document.getElementById('waveform_signals');
const download=document.getElementById('waveform_download');
const prefix='TOP.ibm_pc.';
const signals={
  cpu:['clk','rst_n','retired','cpu.state','cpu.opcode','cpu_cs','ip','flags',
    'cpu_ax','cpu_cx','cpu_dx','cpu_bx','cpu_sp','cpu_bp','cpu_si','cpu_di','cpu_es','cpu_ss','cpu_ds',
    'bus_strobe','bus_addr','bus_write','queue_count'],
  bus:['clk','rst_n','retired','ip','cpu.bus_req_o','eu_ready','eu_fetch','eu_addr','eu_be',
    'bus.phase','bus_strobe','bus_addr','bus_data','bus_read_data','bus_write','bus_io',
    'bus_intack','inta_active','fetching','queue_count','locked','dma_hrq','hlda','dma_valid','dma_channel']
};
let loadedVersion=0,busy=false,failure='';

function loadWaveform(force=false){
  const state=currentState();
  if(!panel.open || !state?.captureVersion || (!force && loadedVersion===state.captureVersion))return;
  loadedVersion=state.captureVersion;
  failure='';
  // Each viewer load queues the same command-file bridge used by BUSICOM.
  // Clear the old iframe, so messages are applied to this capture only.
  const url=new URL('/surfer/',location.origin);
  url.searchParams.set('load_url',`${location.origin}/waveform.fst?capture=${loadedVersion}`);
  url.searchParams.set('view',preset.value);
  url.hash='dev'; // Keep this embedded viewer out of Surfer's PWA cache.
  frame.src=url.href;
}

frame.addEventListener('load',()=>{
  if(!frame.src.includes('load_url='))return;
  const source=frame.src;
  // The iframe is same-origin: wait for WASM startup instead of assuming a
  // fixed startup delay. Surfer queues its command file until waves are loaded.
  let attempts=0;
  const ready=setInterval(()=>{
    if(frame.src!==source){clearInterval(ready);return;}
    if(typeof frame.contentWindow?.inject_message==='function'){
      clearInterval(ready);
      const commands=signals[preset.value].map(name=>`variable_add ${prefix}${name}`).join('\n');
      const message=JSON.stringify({LoadCommandFromData:Array.from(new TextEncoder().encode(commands+'\ntoggle_side_panel\n'))});
      frame.contentWindow.postMessage({command:'InjectMessage',message},location.origin);
    }else if(++attempts>=150){
      clearInterval(ready);failure='Surfer did not start. Reload waveform to retry.';update();
    }
  },100);
});

function update(){
  const state=currentState();
  capture.disabled=busy || !state?.powered;
  refresh.disabled=busy || !state?.captureVersion;
  download.hidden=!state?.captureVersion;
  if(busy)return;
  if(failure){status.textContent=failure;return;}
  if(state?.captureVersion){
    status.textContent=`Capture ${state.captureVersion} · CPU clocks ${state.captureStart.toLocaleString()}–${(state.captureStart+state.captureCycles).toLocaleString()} · ${state.captureCycles.toLocaleString()} clocks`;
    loadWaveform();
  }else{
    status.textContent=state?.powered?'Ready to capture the current CPU.':'Power on the PC, then capture a CPU waveform.';
  }
}

capture.onclick=async()=>{
  busy=true;failure='';update();status.textContent='Recording CPU clocks…';
  try{
    const result=await control('CAPTURE',{cycles:Number(document.getElementById('waveform_cycles').value)});
    if(!result)throw Error('CPU capture failed; see the machine error message.');
  }catch(error){failure=error.message;}
  finally{busy=false;update();}
};
refresh.onclick=()=>loadWaveform(true);
preset.onchange=()=>loadWaveform(true);
panel.addEventListener('toggle',()=>{if(panel.open)update();});
setInterval(update,500);
update();
