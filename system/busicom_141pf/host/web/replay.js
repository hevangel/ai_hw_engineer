/* JSON replay uses the same physical-key HTTP API as the manual panel. */
"use strict";
(() => {
  const profile = document.getElementById("manual_profile");
  const profileNote = document.getElementById("manual_profile_note");
  const select = document.getElementById("manual_example");
  const run = document.getElementById("manual_run");
  const stop = document.getElementById("manual_stop");
  const download = document.getElementById("manual_download");
  const status = document.getElementById("manual_status");
  let doc, results = [], stopped = false, resultProfile = 'recovered-rom';
  profile.addEventListener("change", () => {
    profileNote.textContent = profile.value === "manual"
      ? "The manual scan differs from the original firmware in five examples. The 11-1 square-root value is an arithmetic typo; the other differences may reflect a manual or firmware revision."
      : "The recovered ROM is the original calculator program. It differs from five results in this manual scan. One is a clear arithmetic typo; the causes of the others are uncertain.";
  });
  const rows = new Map();
  const decode = cells => {
    let value = cells.slice(0,15).join("").trim();
    let symbol = (cells[16]+cells[17]).replaceAll(" ", "");
    const rounded = symbol.includes("^");
    symbol = symbol.replaceAll("^", "");
    symbol = ({"×":"*op","÷":"/","−":"-","◇":"ST","Ex":"EX","√":"SQRT"})[symbol] || symbol;
    if (/^\.{14,15}$/.test(value)) { value = null; symbol = "overflow"; }
    return {value, symbol, red:!!cells[18], rounded};
  };
  const equal = (a,b) => ["value","symbol","red","rounded"].every(k => a[k] === b[k]);
  async function request(path, body) {
    const r = await fetch(path, body === undefined ? {cache:"no-store",signal:AbortSignal.timeout(10000)} : {
      method:"POST", headers:{"Content-Type":"application/json"}, body:JSON.stringify(body),signal:AbortSignal.timeout(10000)
    });
    if (!r.ok) throw new Error(`${path}: HTTP ${r.status}`);
    const result = await r.json();
    if (body !== undefined && result.ok !== true) throw new Error(`${path} rejected`);
    return result;
  }
  async function idle() {
    const deadline = Date.now() + 300000;
    while (Date.now() < deadline) {
      const s = await request("/state.json");
      if (!Number.isInteger(s.paper_sequence)) throw new Error("Rebuild the panel bridge for replay support.");
      s.paper.forEach((cells,i) => {
        const r = decode(cells);
        if (r.value || r.symbol) rows.set(s.paper_sequence-6+i,r);
      });
      if (s.ready && !s.busy) return s;
      await new Promise(resolve => setTimeout(resolve,80));
    }
    throw new Error("4004 did not become idle within 300 seconds");
  }
  const lastId = () => Math.max(-1,...rows.keys());
  const since = id => [...rows].filter(([k])=>k>id).sort((a,b)=>a[0]-b[0]).map(([,r])=>r);
  async function press(key) {
    if (stopped) throw new Error("Stopped by user");
    const code = doc.key_codes[key];
    if (!Number.isInteger(code) || code<129 || code>160) throw new Error(`Invalid key: ${key}`);
    const button = document.querySelector(`#keyboard .key[code="${code}"]`);
    button?.classList.add("pressed");
    try { await request("/press",{code}); return await idle(); }
    finally { button?.classList.remove("pressed"); }
  }
  async function loadDocument() {
    run.disabled = true;
    download.disabled = true;
    status.textContent = "Loading included examples…";
    status.dataset.state = "loading";
    try {
      doc = await request("/manual-examples.json");
      if (doc.schema_version!==1 || !Array.isArray(doc.examples) || !doc.key_codes)
        throw new Error("Unsupported examples JSON");
      select.replaceChildren(new Option("All examples", ""));
      for (const e of doc.examples) select.add(new Option(`${e.id}: ${e.title}`,e.id));
      status.textContent = `${doc.examples.length} examples ready. Select one or run all.`;
      status.dataset.state = "ready";
      run.disabled = false;
    } catch (e) {
      status.textContent = `Could not load the included examples: ${e.message}. Refresh the page to retry.`;
      status.dataset.state = "error";
    }
  }
  stop.addEventListener("click",()=>{stopped=true;});
  run.addEventListener("click",async () => {
    window.manualReplayActive = true;
    setBusy(true);
    stopped=false; results=[]; rows.clear(); resultProfile=profile.value;
    download.disabled=true;
    run.disabled=select.disabled=profile.disabled=true; stop.disabled=false;
    status.dataset.state = "running";
    document.querySelectorAll('#digits,input[name="rounding"]').forEach(el=>el.disabled=true);
    try {
      for (const e of doc.examples.filter(e=>!select.value || e.id===select.value)) {
        status.textContent = `Running ${e.id}: ${e.title}`;
        let s=await idle();
        await request("/switches",e.switches);
        for (const key of e.setup_keys) s=await press(key);
        const start=lastId(), checkpoints=[];
        for (let i=0;i<e.steps.length;i++) {
          const step=e.steps[i], before=lastId(), errors=[];
          status.textContent=`Running ${e.id}, step ${i+1}/${e.steps.length}: ${(step.keys||[]).join(" ")}`;
          if (step.switches) await request("/switches",step.switches);
          for (const key of step.keys||[]) s=await press(key);
          const expected=step.expect_profiles?.[profile.value]||step.expect||{}, actual=since(before);
          if (expected.tape) {
            const suffix=actual.slice(-expected.tape.length);
            if (suffix.length!==expected.tape.length || !suffix.every((r,j)=>equal(r,expected.tape[j])))
              errors.push({expected_tape:expected.tape,actual_tape:actual});
          }
          for (const [lamp,value] of Object.entries(expected.lamps||{}))
            if (!!s.lamps[lamp]!==value) errors.push({lamp,expected:value,actual:s.lamps[lamp]});
          checkpoints.push({step:i+1,errors});
        }
        results.push({id:e.id,status:checkpoints.some(c=>c.errors.length)?"FAIL":"PASS",checkpoints,tape:since(start)});
      }
      const passed = results.filter(r => r.status === "PASS").length;
      status.textContent=`${passed}/${results.length} examples passed\n${results.map(r=>`${r.status} ${r.id}`).join("\n")}`;
      status.dataset.state = passed === results.length ? "pass" : "fail";
    } catch (e) {
      results.push({status:"ERROR",error:e.message});
      status.textContent=e.message;
      status.dataset.state = "error";
    }
    finally {
      window.manualReplayActive=false;
      run.disabled=select.disabled=profile.disabled=false; stop.disabled=true; download.disabled=false;
      document.querySelectorAll('#digits,input[name="rounding"]').forEach(el=>el.disabled=false);
    }
  });
  download.addEventListener("click",()=>{
    const blob=new Blob([JSON.stringify({source:doc.source,profile:resultProfile,results},null,2)],{type:"application/json"});
    const url=URL.createObjectURL(blob), a=document.createElement("a");
    a.href=url; a.download="manual-results.json"; a.click(); setTimeout(()=>URL.revokeObjectURL(url),1000);
  });
  loadDocument();
})();
