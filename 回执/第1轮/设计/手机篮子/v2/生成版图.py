from pathlib import Path
import json,base64,re
D=Path(__file__).resolve().parent
P=D.parents[4]/'godot'
# Source images and font are read only. This emits native SVG UI artwork and a standalone layout.
def uri(p,mime='image/png'):
 return 'data:'+mime+';base64,'+base64.b64encode(p.read_bytes()).decode()
font=uri(P/'assets/fonts/fusion-pixel-12px-proportional-zh_hans.otf.woff2','font/woff2')
# Blocks use a 32x32 logical pixel canvas, with hard integer edges. No downloaded artwork.
icons={}
def put(k,blocks):icons[k]={'canvas':[32,32],'blocks':blocks,'kind':'C4 native pixel vector'}
put('radish',[[13,3,3,9,'526b35'],[7,3,7,4,'8baa50'],[16,1,7,4,'8baa50'],[9,10,14,12,'704b32'],[11,10,10,13,'f2d9b0'],[13,23,6,4,'dfb880'],[15,27,2,3,'f2d9b0'],[12,13,3,6,'fff0cf']])
put('pepper',[[16,2,3,9,'526b35'],[12,6,9,4,'789a41'],[10,9,12,6,'74342c'],[10,11,10,10,'d65c3c'],[12,21,6,6,'d65c3c'],[16,27,3,3,'d65c3c'],[12,12,3,6,'ef9270']])
put('grain',[[14,5,3,24,'78643b'],[7,8,8,4,'c48e3e'],[16,5,8,4,'edca6c'],[7,14,8,4,'edca6c'],[16,11,8,4,'c48e3e'],[8,20,7,4,'c48e3e'],[16,17,7,4,'edca6c'],[11,4,7,4,'edca6c']])
put('stone',[[7,8,18,17,'52473f'],[4,14,24,9,'52473f'],[9,9,14,4,'bcb9aa'],[7,13,18,8,'93968b'],[9,21,14,3,'6f776f']])
put('bamboo',[[5,9,5,20,'48572c'],[7,4,5,24,'87a754'],[15,7,6,23,'6b8d42'],[23,2,5,24,'8baa50'],[7,10,5,2,'d9c781'],[7,20,5,2,'d9c781'],[15,14,6,2,'d9c781'],[23,10,5,2,'d9c781'],[23,21,5,2,'d9c781']])
put('tool',[[6,5,21,5,'433f37'],[8,6,16,3,'abb1a0'],[17,10,4,18,'6d442c'],[18,11,2,16,'bc9057']])
put('parcel',[[7,3,18,6,'7f5535'],[7,9,18,18,'d2af72'],[4,13,24,11,'bd9158'],[4,13,24,3,'e4c98e'],[14,8,4,19,'704f34'],[10,5,12,3,'f1d19b'],[8,24,16,3,'8f653e']])
put('flour',[[7,5,18,5,'c1a774'],[6,10,20,18,'70513c'],[8,10,16,17,'e6cea0'],[10,14,12,8,'fff1d4'],[14,15,4,6,'b5965c']])
put('honey',[[10,3,12,5,'9e302c'],[10,8,12,3,'eac685'],[7,11,18,17,'674d33'],[9,12,14,14,'d9a338'],[11,14,3,8,'ffe39c'],[16,16,7,7,'e8c774']])
put('egg',[[12,4,8,3,'b79a68'],[9,7,14,5,'b79a68'],[7,12,18,13,'b79a68'],[9,25,14,3,'b79a68'],[10,8,12,16,'f2dfb9'],[9,13,14,11,'f2dfb9'],[11,9,4,9,'fff2d7']])
put('fish',[[6,11,19,10,'406761'],[4,14,23,5,'406761'],[0,10,5,12,'658f7a'],[6,12,18,6,'9ab7a0'],[20,13,2,2,'2d352d'],[10,10,9,2,'c6d1a9'],[11,21,6,3,'658f7a']])
put('meal',[[3,12,26,12,'65482f'],[5,14,22,12,'dcba7b'],[3,12,26,3,'fff0d1'],[7,8,8,5,'f2d9b0'],[16,7,9,5,'d65c3c'],[12,9,7,4,'789a41'],[7,17,18,3,'eadbc0']])
put('porridge',[[3,10,26,4,'fff0d1'],[5,14,22,12,'b78a54'],[8,23,16,5,'65482f'],[5,11,22,3,'e5c88f'],[11,6,2,3,'d8cda6'],[20,3,2,4,'d8cda6']])
for key in ['radish','pepper','grain']:
 put(key+'_seed',[[6,4,20,24,'725235'],[8,6,16,20,'d9b675'],[8,6,16,4,'f1d8a3'],[11,13,10,10,'eee0b5']]+[[int(b[0]*.35)+10,int(b[1]*.35)+12,max(1,int(b[2]*.35)),max(1,int(b[3]*.35)),b[4]] for b in icons[key]['blocks']])
icons['fruit']={'kind':'reuse','source':'res://ayu_home/v4/assets/floor1-redraw/botanical-6.png','data':uri(P/'ayu_home/v4/assets/floor1-redraw/botanical-6.png')}
# Reuse all 12 current furniture silhouettes; nine are existing PNGs and three use current blocks.
furn={'chair':('竹椅',{'bamboo':2}), 'table':('小木桌',{'bamboo':3,'stone':1}), 'planter':('花架',{'bamboo':2,'stone':2}), 'grain_crate':('谷粮小箱',{'bamboo':3}), 'tea_stool':('矮茶凳',{'bamboo':2,'stone':1}), 'bamboo_screen':('竹屏风',{'bamboo':5}), 'honey_rack':('蜂蜜小架',{'bamboo':4,'stone':1}), 'clay_pot':('陶花盆',{'stone':3}), 'hanging_lamp':('暖灯架',{'bamboo':3,'stone':2}), 'wash_basin':('石洗盆',{'stone':4,'bamboo':1}), 'picnic_mat':('野餐席',{'bamboo':4}), 'notice_easel':('留言画架',{'bamboo':5,'stone':2})}
for key in list(furn)[3:]:
 icons[key]={'kind':'reuse','source':'res://ayu_home/v4/assets/craft/'+key+'.png','data':uri(P/('ayu_home/v4/assets/craft/'+key+'.png'))}
blocks={'chair':[[10,4,28,27,'5a3d2b'],[14,7,20,18,'b18147'],[10,28,5,16,'71472e'],[33,28,5,16,'71472e'],[8,24,32,10,'b8874b'],[10,24,28,4,'d4aa65']], 'table':[[5,14,38,20,'4e3428'],[8,31,6,13,'71472e'],[34,31,6,13,'71472e'],[7,12,34,18,'b8874b'],[9,14,30,4,'d4aa65'],[9,23,30,2,'976137']], 'planter':[[13,28,24,17,'774635'],[10,26,29,6,'b87853'],[16,32,18,11,'a96345'],[21,12,5,18,'4c6936'],[10,15,15,8,'648d41'],[25,8,13,9,'82a451'],[17,5,9,13,'92b456'],[8,12,7,6,'f1c858'],[29,5,7,7,'d98290']]}
for k,v in blocks.items():icons[k]={'canvas':[48,48],'blocks':v,'kind':'reuse current furniture_draw.gd blocks'}
manifest={k:{a:b for a,b in v.items() if a!='data'} for k,v in icons.items()}
(D/'物品图标接口.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
for k,v in icons.items():
 if 'blocks' in v:
  n=v['canvas'][0];svg=f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {n} {n}" shape-rendering="crispEdges">'+''.join(f'<rect x="{b[0]}" y="{b[1]}" width="{b[2]}" height="{b[3]}" fill="#{b[4]}"/>' for b in v['blocks'])+'</svg>'
  v['data']='data:image/svg+xml;base64,'+base64.b64encode(svg.encode()).decode()
  (D/(k+'.svg')).write_text(svg)
items=[['radish','楼卜',18],['pepper','海椒',8],['grain','谷子',12],['radish_seed','楼卜种',3],['pepper_seed','海椒种',2],['grain_seed','谷种',4],['stone','石头',9],['bamboo','竹材',14],['tool','旧锄头',1],['parcel','动物包',3],['meal','海椒拌楼卜',2],['flour','谷粉',4],['porridge','谷香粥',1],['honey','蜂蜜',2],['fish','鲜鱼',1],['egg','鸡蛋',2],['fruit','时令果',3]]
(D/'设计样例数据.json').write_text(json.dumps({'notice':'Only design fixtures. Not live inventory or gameplay evidence.','items':items,'furniture':furn},ensure_ascii=False,indent=2))
html=r'''<!doctype html><html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>裳泓村 · 手机篮子设计 v2</title><style>
@font-face{font-family:pixel;src:url(FONTDATA)}*{box-sizing:border-box}body{margin:0;background:#160c05;color:#faf2e4;font:24px/1.2 pixel}button{font:inherit;color:inherit;cursor:pointer;border:0}button:focus-visible{outline:3px solid #f2c23e;outline-offset:1px}button:disabled{color:#bf8044;cursor:default}.frame{background:#311e15;border:2px solid #160c05;box-shadow:inset 0 0 0 2px #bf8044;clip-path:polygon(0 6px,6px 6px,6px 0,calc(100% - 6px) 0,calc(100% - 6px) 6px,100% 6px,100% calc(100% - 6px),calc(100% - 6px) calc(100% - 6px),calc(100% - 6px) 100%,6px 100%,6px calc(100% - 6px),0 calc(100% - 6px))}.active{box-shadow:inset 0 0 0 3px #f2c23e}.primary{background:#cb1c1c;border:3px solid #3e0303;box-shadow:inset 0 0 0 2px #f8a870,inset 0 -7px #a4191a;color:#faf2e4}.primary:disabled{background:#311e15;border-color:#160c05;box-shadow:inset 0 0 0 2px #bf8044}button{min-height:48px;padding:8px 14px}button{line-height:24px}.app{height:100dvh;width:100%;max-width:540px;margin:auto;padding:28px 16px 26px;display:flex;flex-direction:column;gap:6px;background:#311e15}.top{display:flex;align-items:center;gap:8px;min-height:48px}.top h1{font-size:36px;font-weight:normal;margin:0;flex:1;white-space:nowrap}.wallet{color:#f2c23e;white-space:nowrap}.nav,.tabs{display:grid;grid-template-columns:repeat(3,1fr);gap:8px}.summary{height:28px;display:flex;align-items:center;justify-content:space-between}.scroll{flex:1;min-height:0;overflow-y:auto;overflow-x:hidden;scrollbar-gutter:stable;overscroll-behavior:contain;touch-action:pan-y;padding:2px 2px 6px}.scroll::-webkit-scrollbar{width:12px}.scroll::-webkit-scrollbar-thumb{background:#bf8044;border:3px solid #311e15}.grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:8px;align-items:stretch}.slot{padding:6px 4px;min-height:120px;min-width:0;display:flex;flex-direction:column;align-items:center;gap:4px}.slot img{width:48px;height:48px;object-fit:contain;image-rendering:pixelated;flex:none}.name{width:100%;min-height:24px;max-height:48px;flex:none;overflow:hidden;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow-wrap:anywhere;text-align:center;line-height:24px}.badge{height:24px;flex:none;max-width:100%;white-space:nowrap;margin-top:auto;line-height:24px}.detail{flex:none;padding:8px;display:flex;flex-direction:column;gap:6px;max-height:264px}.selected{display:flex;align-items:center;gap:12px;min-height:48px}.selected img{height:48px;width:48px;object-fit:contain;image-rendering:pixelated;flex:none}.selectedcopy{min-width:0;flex:1;display:flex;flex-wrap:wrap;align-items:center;gap:4px 12px;line-height:24px}.fullname{color:#f2c23e;max-width:100%;max-height:72px;overflow-y:auto;overflow-wrap:anywhere;line-height:24px}.qty{line-height:24px}.explain{max-height:48px;min-height:24px;overflow-y:auto;white-space:pre-wrap;line-height:24px}.explain:empty{display:none}.actions{display:grid;grid-template-columns:1fr;gap:6px}.actions:empty{display:none}.empty{min-height:160px;text-align:center;padding:28px 10px;color:#f2c23e;white-space:pre-line}.locked .badge{color:#bf8044}.box-service .badge{color:#f2c23e}@media(max-width:419px){.grid{grid-template-columns:repeat(3,minmax(0,1fr))}.top h1 .wide{display:none}.top h1{font-size:36px}.top button{padding-left:10px;padding-right:10px}.wallet{font-size:24px}.detail{max-height:264px}}

</style><main class="app"><header class="top"><h1><span class="wide">随身</span>篮子</h1><span class="wallet">金币 186</span><button class="frame" id="back">返回</button></header><nav class="nav"><button class="frame">日常</button><button class="frame">地图</button><button class="frame active">篮子</button></nav><nav class="tabs"><button class="frame active" data-tab="items">物品</button><button class="frame" data-tab="seeds">换种子</button><button class="frame" data-tab="plans">图纸</button></nav><div class="summary"><span id="summary"></span><span>10月14日</span></div><section class="scroll"><div class="grid" id="grid"></div></section><section class="detail frame"><div class="selected" id="selected"></div><div class="explain" id="explain"></div><div class="actions" id="actions"></div></section></main><script>
const ART=ARTDATA,ITEMS=ITEMDATA,FURN=FURNDATA;const params=new URLSearchParams(location.search), mode=params.get('mode')||'items';let tab=['seeds','plans','box'].includes(mode)?(mode==='box'?'plans':mode):'items',selected=mode==='box'?'box':tab==='plans'?'honey_rack':tab==='seeds'?'pepper_seed':mode==='parcel'?'parcel':'radish';const names=Object.fromEntries(ITEMS.map(x=>[x[0],x[1]]));let inv=ITEMS.map(x=>[...x]);if(mode==='empty'){inv=[];selected=''}if(mode==='stress'){inv.find(x=>x[0]==='bamboo')[1]='庭院修缮用的整捆长节竹材';inv.find(x=>x[0]==='bamboo')[2]=999999;selected='bamboo'}if(mode==='missing'){tab='plans';selected='honey_rack';inv.find(x=>x[0]==='bamboo')[2]=1;inv.find(x=>x[0]==='stone')[2]=0}if(mode==='locked') {tab='plans';selected='notice_easel'}
function pic(k){return `<img alt="" src="${ART[k].data}">`}
function count(k){return inv.find(x=>x[0]===k)?.[2]||0}
function draw(){
 document.querySelectorAll('[data-tab]').forEach(b=>b.classList.toggle('active',b.dataset.tab===tab));
 let data=tab==='items'?inv:tab==='seeds'?ITEMS.filter(x=>x[0].endsWith('_seed')).map(x=>[x[0],x[1],count(x[0])]):[['box','金币盲盒','30金币'],...Object.entries(FURN).map(([k,v],i)=>[k,v[0],i<7?'已学会':'未获得'])];
 document.getElementById('summary').textContent=tab==='plans'?'12张图纸与盲盒':tab==='seeds'?'每包3金币':`${data.length}种物品`;
 document.getElementById('grid').innerHTML=data.length?data.map(([k,n,q])=>`<button class="slot frame ${selected===k?'active':''} ${q==='未获得'?'locked':''} ${k==='box'?'box-service':''}" data-id="${k}">${pic(k==='box'?'parcel':k)}<span class="name">${n}</span><span class="badge">${typeof q==='number'?'×'+(q>9999?'9999+':q):q}</span></button>`).join(''):'<div class="empty" style="grid-column:1/-1">篮子还是空的\n收下动物带回的东西，\n或去田里收成熟的菜。</div>';
 document.querySelectorAll('[data-id]').forEach(b=>b.onclick=()=>{selected=b.dataset.id;draw()});
 let isBox=selected==='box',name=isBox?'金币盲盒':tab==='plans'?FURN[selected]?.[0]:inv.find(x=>x[0]===selected)?.[1]||names[selected];
 let qty=isBox?'30金币':tab==='plans'?(Object.keys(FURN).indexOf(selected)<7?'已学会':'未获得'):count(selected)+'件';
 document.getElementById('selected').innerHTML=selected?`${pic(isBox?'parcel':selected)}<div class="selectedcopy"><div class="fullname">${name}${tab==='plans'&&!isBox?'图纸':''}</div><div class="qty">${qty}</div></div>`:'<div class="fullname">暂无选中物品</div>';
 let explanation='',main='',enabled=true;
 if(isBox){explanation='25%出旧锄头，其余出图纸。连续3次没工具，下一次保底；已有图纸换3根竹材。';main='买盲盒 · 30金币'}
 else if(tab==='plans'){explanation='需要：'+Object.entries(FURN[selected][1]).map(([k,q])=>`${names[k]} ${count(k)}/${q}`).join(' · ');enabled=Object.keys(FURN).indexOf(selected)<7&&Object.entries(FURN[selected][1]).every(([k,q])=>count(k)>=q);main=`制作${name}`;if(!enabled)explanation=(Object.keys(FURN).indexOf(selected)>=7?'先取得这张图纸。\n':'材料还不够。\n')+explanation;}
 else if(tab==='seeds'){explanation='放入篮子后，到田边播种。';main='换一包'+names[selected]+' · 3金币'}
 else if(selected==='parcel'){explanation='25%出旧锄头，其余出图纸。连续3次没工具，下一次保底；已有图纸换3根竹材。';main='打开动物包';enabled=count('parcel')>0}
 else if(selected){explanation=['bamboo','stone','tool'].includes(selected)?'用于开地或家具制作。':selected.endsWith('_seed')?'到田边选择种子播种。':'在订单或对应场所使用。'}
 document.getElementById('explain').textContent=explanation;
 document.getElementById('actions').innerHTML=main?`<button class="primary" ${enabled?'':'disabled'}>${main}</button>`:'';
 document.querySelectorAll('#actions button').forEach(b=>b.onclick=()=>{document.getElementById('explain').textContent='设计预览：由C2绑定既有操作。'});
}

document.querySelectorAll('[data-tab]').forEach(b=>b.onclick=()=>{tab=b.dataset.tab;selected=tab==='items'?(inv[0]?.[0]||''):tab==='seeds'?'radish_seed':'chair';document.querySelector('.scroll').scrollTop=0;draw()});document.getElementById('back').onclick=()=>document.getElementById('explain').textContent='设计预览：返回游戏沿用原关闭操作。';draw();
</script></html>'''
html=html.replace('FONTDATA',font).replace('ARTDATA',json.dumps(icons,ensure_ascii=False)).replace('ITEMDATA',json.dumps(items,ensure_ascii=False)).replace('FURNDATA',json.dumps(furn,ensure_ascii=False))
(D/'手机篮子-可点版图.html').write_text(html)
print('Native inventory artwork and design HTML emitted; existing font/fruit/furniture reused.')
