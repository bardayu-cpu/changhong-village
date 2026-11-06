import {writeFile,mkdir} from 'node:fs/promises';
const out='/Users/kayra_ayu/Documents/Codex/2026-11-05/w2-d2/outputs/claude-handoff-c71d6e1/evidence';
await mkdir(out,{recursive:true});
const version=await (await fetch('http://127.0.0.1:9448/json/version')).json();
const ws=new WebSocket(version.webSocketDebuggerUrl);
await new Promise((resolve,reject)=>{ws.onopen=resolve;ws.onerror=reject});
let id=0,session;const pending=new Map(),events=[];
ws.onmessage=e=>{const m=JSON.parse(e.data);if(m.id){const p=pending.get(m.id);pending.delete(m.id);m.error?p.reject(new Error(JSON.stringify(m.error))):p.resolve(m.result)}else if(m.sessionId===session)events.push(m)};
const send=(method,params={},s)=>new Promise((resolve,reject)=>{const n=++id;pending.set(n,{resolve,reject});ws.send(JSON.stringify({id:n,method,params,...(s?{sessionId:s}:{})}))});
const context=(await send('Target.createBrowserContext')).browserContextId;
try {
const target=(await send('Target.createTarget',{url:'about:blank',browserContextId:context})).targetId;
session=(await send('Target.attachToTarget',{targetId:target,flatten:true})).sessionId;
const page=(method,params={})=>send(method,params,session);
await page('Page.enable');await page('Runtime.enable');await page('Log.enable');
await page('Emulation.setDeviceMetricsOverride',{width:360,height:640,deviceScaleFactor:1,mobile:true});
await page('Page.navigate',{url:'http://127.0.0.1:8876/'});
let state;
for(let i=0;i<35;i++){
 await new Promise(r=>setTimeout(r,1000));
 state=(await page('Runtime.evaluate',{expression:"({title:document.title,statusVisible:!!document.getElementById('status')&&getComputedStyle(document.getElementById('status')).display!=='none',notice:document.getElementById('status-notice')?.innerText,canvas:[document.querySelector('canvas')?.width,document.querySelector('canvas')?.height]})",returnByValue:true})).result.value;
 if(i>5&&state?.statusVisible===false)break;
}
const img=await page('Page.captureScreenshot',{format:'png'});
await writeFile(out+'/web-chrome-360x640.png',Buffer.from(img.data,'base64'));
await page('Input.dispatchMouseEvent',{type:'mousePressed',x:180,y:95,button:'left',buttons:1,clickCount:1});
await page('Input.dispatchMouseEvent',{type:'mouseReleased',x:180,y:95,button:'left',buttons:0,clickCount:1});
await new Promise(r=>setTimeout(r,6000));
const next=await page('Page.captureScreenshot',{format:'png'});
await writeFile(out+'/web-chrome-after-open.png',Buffer.from(next.data,'base64'));
const errors=events.filter(x=>x.method==='Runtime.exceptionThrown'||(x.method==='Runtime.consoleAPICalled'&&x.params.type==='error'));
await writeFile(out+'/web-chrome-result.json',JSON.stringify({version:version.Browser,state,errors,events},null,2));
console.log(JSON.stringify({state,errorCount:errors.length,errors}));
if(state?.statusVisible!==false||errors.length)process.exitCode=1;
} finally {await send('Target.disposeBrowserContext',{browserContextId:context});ws.close()}

