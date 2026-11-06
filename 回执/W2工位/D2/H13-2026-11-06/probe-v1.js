(() => {
  const frame = document.querySelector('#game');
  const run = new URLSearchParams(location.search).get('run') || 'manual';
  const records = []; let seq = 0, lastSave = '', bound = false;
  const env = () => {
    const w = frame.contentWindow, c = w.document.querySelector('canvas'), r = c?.getBoundingClientRect();
    return {ua:w.navigator.userAgent,dpr:w.devicePixelRatio,viewport:[w.innerWidth,w.innerHeight],maxTouchPoints:w.navigator.maxTouchPoints,touchProperty:'ontouchstart' in w,canvas:c?{width:c.width,height:c.height,rect:{x:r.x,y:r.y,width:r.width,height:r.height}}:null,hidden:w.document.hidden,hasFocus:w.document.hasFocus()};
  };
  const record = data => { const entry = {seq:++seq,at:new Date().toISOString(),...data}; records.push(entry); fetch('/evidence/'+encodeURIComponent(run),{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(entry),keepalive:true}).catch(()=>{}); };
  const saved = () => {try{return JSON.parse(frame.contentWindow.localStorage.getItem('hongyuan_save.json')||'null')}catch{return null}};
  window.h11Snapshot = label => { const value={kind:'checkpoint',label,env:env(),saved:saved()}; record(value);return value; };
  window.h11Records = records;
  frame.addEventListener('load',()=>{
    const w=frame.contentWindow;
    if(bound)return;bound=true;
    for(const type of ['pointerdown','pointermove','pointerup','pointercancel','mousedown','mousemove','mouseup','click','touchstart','touchmove','touchend','touchcancel','blur','focus','visibilitychange']) {
      w.addEventListener(type,e=>{
        if((type==='mousemove'||type==='pointermove')&&!e.buttons)return;
        const xy=e.changedTouches?.[0]||e;
        record({kind:'input',type:e.type,isTrusted:e.isTrusted,pointerType:e.pointerType||null,pointerId:e.pointerId??null,buttons:e.buttons??null,button:e.button??null,client:[xy.clientX??null,xy.clientY??null],touches:e.touches?.length??null,changed:[...(e.changedTouches||[])].map(t=>({id:t.identifier,x:t.clientX,y:t.clientY})),target:e.target.id||e.target.tagName||'window',env:env()});
      },{capture:true,passive:true});
    }
    w.addEventListener('error',e=>record({kind:'error',message:e.message,filename:e.filename,line:e.lineno}));
    record({kind:'loaded',env:env(),saved:saved()});
  });
  setInterval(()=>{
    if(!bound)return;
    const s=saved(), json=JSON.stringify(s);
    if(json!==lastSave){lastSave=json;record({kind:'save',saved:s});}
    document.querySelector('#summary').textContent=JSON.stringify({run,env:env(),step:s?.stepId,feet:s?.feet,events:seq},null,2);
  },200);
  document.querySelector('#snapshot').onclick=()=>window.h11Snapshot('manual');
})();
