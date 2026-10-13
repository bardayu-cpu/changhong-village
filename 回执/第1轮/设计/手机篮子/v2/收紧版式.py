# -*- coding: utf-8 -*-
# One-time transformation record, already applied. Do not rerun.
# Final render source is 生成版图.py; C2 uses only C2篮子接入-v2.json.
from pathlib import Path
p=Path(__file__).with_name('生成版图.py')
s=p.read_text()
s=s.replace('手机篮子设计 v1','手机篮子设计 v2')
# Keep the existing skins, font, icons. Change only layout and presentation grouping.
a=s.index('.app{');b=s.index('\n</style>',a)
s=s[:a]+'''button{line-height:24px}.app{height:100dvh;width:100%;max-width:540px;margin:auto;padding:28px 16px 26px;display:flex;flex-direction:column;gap:6px;background:#311e15}.top{display:flex;align-items:center;gap:8px;min-height:48px}.top h1{font-size:36px;font-weight:normal;margin:0;flex:1;white-space:nowrap}.wallet{color:#f2c23e;white-space:nowrap}.nav,.tabs{display:grid;grid-template-columns:repeat(3,1fr);gap:8px}.summary{height:28px;display:flex;align-items:center;justify-content:space-between}.scroll{flex:1;min-height:0;overflow-y:auto;overflow-x:hidden;scrollbar-gutter:stable;overscroll-behavior:contain;touch-action:pan-y;padding:2px 2px 6px}.scroll::-webkit-scrollbar{width:12px}.scroll::-webkit-scrollbar-thumb{background:#bf8044;border:3px solid #311e15}.grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:8px;align-items:stretch}.slot{padding:6px 4px;min-height:120px;min-width:0;display:flex;flex-direction:column;align-items:center;gap:4px}.slot img{width:48px;height:48px;object-fit:contain;image-rendering:pixelated;flex:none}.name{width:100%;min-height:24px;max-height:48px;flex:none;overflow:hidden;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow-wrap:anywhere;text-align:center;line-height:24px}.badge{height:24px;flex:none;max-width:100%;white-space:nowrap;margin-top:auto;line-height:24px}.detail{flex:none;padding:8px;display:flex;flex-direction:column;gap:6px;max-height:264px}.selected{display:flex;align-items:center;gap:12px;min-height:48px}.selected img{height:48px;width:48px;object-fit:contain;image-rendering:pixelated;flex:none}.selectedcopy{min-width:0;flex:1;display:flex;flex-wrap:wrap;align-items:center;gap:4px 12px;line-height:24px}.fullname{color:#f2c23e;max-width:100%;max-height:72px;overflow-y:auto;overflow-wrap:anywhere;line-height:24px}.qty{line-height:24px}.explain{max-height:58px;min-height:24px;overflow-y:auto;white-space:pre-wrap;line-height:24px}.explain:empty{display:none}.actions{display:grid;grid-template-columns:1fr;gap:6px}.actions:empty{display:none}.empty{min-height:160px;text-align:center;padding:28px 10px;color:#f2c23e;white-space:pre-line}.locked .badge{color:#bf8044}.box-service .badge{color:#f2c23e}@media(max-width:419px){.grid{grid-template-columns:repeat(3,minmax(0,1fr))}.top h1 .wide{display:none}.top h1{font-size:36px}.top button{padding-left:10px;padding-right:10px}.wallet{font-size:24px}.detail{max-height:264px}}
''' +s[b:]
a=s.index('<main class="app">');b=s.index('<script>',a)
s=s[:a]+'''<main class="app"><header class="top"><h1><span class="wide">随身</span>篮子</h1><span class="wallet">金币 186</span><button class="frame" id="back">返回</button></header><nav class="nav"><button class="frame">日常</button><button class="frame">地图</button><button class="frame active">篮子</button></nav><nav class="tabs"><button class="frame active" data-tab="items">物品</button><button class="frame" data-tab="seeds">换种子</button><button class="frame" data-tab="plans">图纸</button></nav><div class="summary"><span id="summary"></span><span>10月14日</span></div><section class="scroll"><div class="grid" id="grid"></div></section><section class="detail frame"><div class="selected" id="selected"></div><div class="explain" id="explain"></div><div class="actions" id="actions"></div></section></main>''' +s[b:]
s=s.replace("['seeds','plans'].includes(mode)?mode:'items'","['seeds','plans','box'].includes(mode)?(mode==='box'?'plans':mode):'items'")
s=s.replace("selected=tab==='plans'?'honey_rack'","selected=mode==='box'?'box':tab==='plans'?'honey_rack'")
a=s.index('function draw(){');b=s.index('\ndocument.querySelectorAll(\'[data-tab]\')',a)
s=s[:a]+'''function draw(){
 document.querySelectorAll('[data-tab]').forEach(b=>b.classList.toggle('active',b.dataset.tab===tab));
 let data=tab==='items'?inv:tab==='seeds'?ITEMS.filter(x=>x[0].endsWith('_seed')).map(x=>[x[0],x[1],count(x[0])]):[['box','金币盲盒','30金币'],...Object.entries(FURN).map(([k,v],i)=>[k,v[0],i<7?'已学会':'未获得'])];
 document.getElementById('summary').textContent=tab==='plans'?'12张图纸与盲盒':tab==='seeds'?'每包3金币':`${data.length}种物品`;
 document.getElementById('grid').innerHTML=data.length?data.map(([k,n,q])=>`<button class="slot frame ${selected===k?'active':''} ${q==='未获得'?'locked':''} ${k==='box'?'box-service':''}" data-id="${k}">${pic(k==='box'?'parcel':k)}<span class="name">${n}</span><span class="badge">${typeof q==='number'?'×'+(q>9999?'9999+':q):q}</span></button>`).join(''):'<div class="empty" style="grid-column:1/-1">篮子还是空的\\n收下动物带回的东西，\\n或去田里收成熟的菜。</div>';
 document.querySelectorAll('[data-id]').forEach(b=>b.onclick=()=>{selected=b.dataset.id;draw()});
 let isBox=selected==='box',name=isBox?'金币盲盒':tab==='plans'?FURN[selected]?.[0]:inv.find(x=>x[0]===selected)?.[1]||names[selected];
 let qty=isBox?'30金币':tab==='plans'?(Object.keys(FURN).indexOf(selected)<7?'已学会':'未获得'):count(selected)+'件';
 document.getElementById('selected').innerHTML=selected?`${pic(isBox?'parcel':selected)}<div class="selectedcopy"><div class="fullname">${name}${tab==='plans'&&!isBox?'图纸':''}</div><div class="qty">${qty}</div></div>`:'<div class="fullname">暂无选中物品</div>';
 let explanation='',main='',enabled=true;
 if(isBox){explanation='25%出旧锄头，其余出图纸。连续3次没工具，下一次保底；已有图纸换3根竹材。';main='买盲盒 · 30金币'}
 else if(tab==='plans'){explanation='需要：'+Object.entries(FURN[selected][1]).map(([k,q])=>`${names[k]} ${count(k)}/${q}`).join(' · ');enabled=Object.keys(FURN).indexOf(selected)<7&&Object.entries(FURN[selected][1]).every(([k,q])=>count(k)>=q);main=`制作${name}`;if(!enabled)explanation+=Object.keys(FURN).indexOf(selected)>=7?'\\n先取得这张图纸。':'\\n材料还不够。'}
 else if(tab==='seeds'){explanation='放入篮子后，到田边播种。';main='换一包'+names[selected]+' · 3金币'}
 else if(selected==='parcel'){explanation='25%出旧锄头，其余出图纸。连续3次没工具，下一次保底；已有图纸换3根竹材。';main='打开动物包';enabled=count('parcel')>0}
 else if(selected){explanation=['bamboo','stone','tool'].includes(selected)?'用于开地或家具制作。':selected.endsWith('_seed')?'到田边选择种子播种。':'在订单或对应场所使用。'}
 document.getElementById('explain').textContent=explanation;
 document.getElementById('actions').innerHTML=main?`<button class="primary" ${enabled?'':'disabled'}>${main}</button>`:'';
 document.querySelectorAll('#actions button').forEach(b=>b.onclick=()=>{document.getElementById('explain').textContent='设计预览：由C2绑定既有操作。'});
}
''' +s[b:]
s=s.replace("document.querySelector('.notice').textContent='设计预览：返回游戏沿用原关闭操作。'","document.getElementById('explain').textContent='设计预览：返回游戏沿用原关闭操作。'")
p.write_text(s)
# The same fixtures/checks, plus the relocated existing box operation.
p=Path(__file__).with_name('检查版图.cjs');s=p.read_text().replace("[540,960,'parcel']","[540,960,'box'],[540,960,'parcel']")
s=s.replace("'prototype selection and keyboard focus'","'v2 prototype selection and keyboard focus'")
s=s.replace("C4 standalone design layout, not production runtime or N6 validation","C4 v2 standalone design layout, not production runtime or N6 validation")
p.write_text(s)
