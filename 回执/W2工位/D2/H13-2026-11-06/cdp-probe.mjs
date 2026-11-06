import {writeFile, mkdir} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
const root=path.dirname(fileURLToPath(import.meta.url));
const mode=process.argv[2]||'touch';
const run='chrome-'+mode+'-'+Date.now();
const out=path.join(root,run);await mkdir(out);
if(!['touch','mouse'].includes(mode))throw new Error('Mode must be touch or mouse');
const cdpOrigin=process.env.H11_CDP_ORIGIN||'http://127.0.0.1:9364';
const probeOrigin=process.env.H11_PROBE_ORIGIN||'http://127.0.0.1:8897';
for(const origin of [cdpOrigin,probeOrigin])if(new URL(origin).hostname!=='127.0.0.1')throw new Error('Only explicit local loopback origins are supported');
const version=await(await fetch(cdpOrigin+'/json/version')).json();
const ws=new WebSocket(version.webSocketDebuggerUrl);await new Promise((ok,no)=>{ws.onopen=ok;ws.onerror=no});
let seq=0;const pending=new Map(),protocol=[],consoleEvents=[];
ws.onmessage=e=>{const m=JSON.parse(e.data);if(m.id){const p=pending.get(m.id);pending.delete(m.id);m.error?p.reject(new Error(JSON.stringify(m.error))):p.resolve(m.result)}else if(m.sessionId===sessionId)consoleEvents.push(m)};
const send=(method,params={},sessionId)=>new Promise((resolve,reject)=>{const id=++seq;pending.set(id,{resolve,reject});protocol.push({at:new Date().toISOString(),method,params,sessionId});ws.send(JSON.stringify({id,method,params,...(sessionId?{sessionId}:{})}))});
const pause=ms=>new Promise(r=>setTimeout(r,ms));
let context,sessionId,checkpoints=[],checks=[];
try{
 context=(await send('Target.createBrowserContext')).browserContextId;
 const target=(await send('Target.createTarget',{url:'about:blank',browserContextId:context})).targetId;
 sessionId=(await send('Target.attachToTarget',{targetId:target,flatten:true})).sessionId;
 const page=(method,params={})=>send(method,params,sessionId);
 await page('Page.enable');await page('Runtime.enable');await page('Log.enable');
 await page('Emulation.setDeviceMetricsOverride',{width:360,height:640,deviceScaleFactor:3,mobile:true});
 const ua='Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1';
 await page('Emulation.setUserAgentOverride',{userAgent:ua});
 await page('Emulation.setTouchEmulationEnabled',{enabled:mode==='touch',maxTouchPoints:5});
 await page('Page.navigate',{url:probeOrigin+'/?run='+run});
 const evaluate=async expression=>(await page('Runtime.evaluate',{expression,returnByValue:true})).result.value;
 const snap=async label=>{const c=await evaluate('window.h11Snapshot('+JSON.stringify(label)+')');checkpoints.push(c);const img=await page('Page.captureScreenshot',{format:'png'});await writeFile(path.join(out,label+'.png'),Buffer.from(img.data,'base64'));console.log(label,JSON.stringify(c?.saved));return c};
 const touch=async(type,x,y)=>page('Input.dispatchTouchEvent',{type,touchPoints:type==='touchEnd'?[]:[{x,y,id:0,radiusX:1,radiusY:1,force:1}]});
 const mouse=async(type,x,y)=>page('Input.dispatchMouseEvent',{type,x,y,button:'left',buttons:type==='mouseReleased'?0:1,clickCount:1});
 const down=(x,y)=>mode==='touch'?touch('touchStart',x,y):mouse('mousePressed',x,y);
 const move=(x,y)=>mode==='touch'?touch('touchMove',x,y):mouse('mouseMoved',x,y);
 const up=(x,y)=>mode==='touch'?touch('touchEnd',x,y):mouse('mouseReleased',x,y);
 const tap=async(x,y)=>{await down(x,y);await pause(100);await up(x,y)};
 await pause(7000);await snap('00-new-title');
 if(checkpoints[0]?.saved?.stepId!=='prologue/closed')throw new Error('Fresh context did not show a normal new title');
 await tap(180,92);
 let saved;
 for(let i=0;i<90;i++){saved=await evaluate("JSON.parse(document.querySelector('iframe').contentWindow.localStorage.getItem('hongyuan_save.json')||'null')");if(saved?.stepId==='shanghai/board_car')break;await pause(500)}
 await snap('01-shanghai-before');
 if(saved?.stepId!=='shanghai/board_car')throw new Error('Normal new game did not reach board_car: '+JSON.stringify(saved));
 await down(64,558);await move(100,558);await pause(500);await up(100,558);await pause(500);await snap('02-joystick-after');
 await tap(263,445);await pause(2000);await snap('03-ground-after');
 await tap(263,382);await pause(1000);await snap('04-interact-after');
 await writeFile(path.join(out,'events.json'),JSON.stringify(await evaluate('window.h11Records'),null,2));
 const [title,before,stick,ground,interact]=checkpoints;
 checks=[
  {name:'normal new title',ok:title.saved.stepId==='prologue/closed'},
  {name:'joystick moves feet',ok:stick.saved.feet[0]-before.saved.feet[0]>1},
  {name:'ground reaches target without auto interaction',ok:ground.saved.stepId==='shanghai/board_car'&&Math.hypot(ground.saved.feet[0]-263,ground.saved.feet[1]-445)<1},
  {name:'manual icon enters driving',ok:interact.saved.stepId==='shanghai/drive'},
 ];
 if(checks.some(c=>!c.ok))throw new Error('Development input check failed: '+JSON.stringify(checks));
 console.log('Development checks:',JSON.stringify(checks));
}catch(e){console.error(e);process.exitCode=1}finally{
 await writeFile(path.join(out,'result.json'),JSON.stringify({run,mode,version,checkpoints,checks,protocol,consoleEvents},null,2));
 if(context)await send('Target.disposeBrowserContext',{browserContextId:context});ws.close();
 console.log('Evidence:',out);
}
