"""Attach C4's alpha atlas using AtlasTexture regions; no source artwork edits."""
from pathlib import Path
import json, shutil
from plan_landscape import ROOT, ASSETS, VILLAGE, plan

layout=plan()
design=ROOT/'回执/第1轮/设计/村外铺景'
atlas=json.loads((design/'图集切片-v1.json').read_text())
items={x['key']:x for x in atlas['items']}
shutil.copyfile(design/atlas['source'],VILLAGE/'landscape-atlas-v1.png')
cfg=json.loads((ASSETS/'village.json').read_text())
cfg.setdefault('landscape_legacy_trees',[p for p in cfg['props'] if p['id'].startswith('wildtree')])
cfg['props']=[p for p in cfg['props'] if not p['id'].startswith(('land_','wildtree'))]
old=cfg.get('landscape_obstacles',[])
cfg['obstacles']=[r for r in cfg['obstacles'] if r not in old]
new_obstacles=[]

def add(key, rect, kind='deciduous', ground=True, tag=''):
    x,y,w,h=rect;r=items[key]['source_bbox_xyxy'];sw,sh=r[2]-r[0],r[3]-r[1]
    scale=min(w/sw,h/sh);width,height=sw*scale,sh*scale
    pos=[round(x+(w-width)/2),round(y+h-height)]
    prop={'id':'land_'+str(len(cfg['props']))+'_'+tag,'file':'res://ayu_home/v4/assets/village/landscape-atlas-v1.png','pos':pos,'foot':y+h-3,'scale':[scale,scale],'atlas_region':[r[0],r[1],sw,sh],'plant_type':kind,'ground':ground,'front':False}
    cfg['props'].append(prop)
    return prop

for f in layout['fields']:
    x,y,w,h=f['rect']
    # Only the internal crop row is reused. The plot perimeter and soil are continuous ground.
    rows=max(2,(h-26)//32)
    for row in range(rows):
        columns=int((w-30-(row%2)*12)/26.4);px=x+13+(row%2)*6
        while columns>0:
            count=min(6,columns);source_width=count*44;scale=.6;width=source_width*scale
            cfg['props'].append({'id':f"land_{f['id']}_row{row}_{px}",'file':'res://ayu_home/v4/assets/village/landscape-atlas-v1.png','pos':[px,y+14+row*32],'foot':y+h,'scale':[scale,scale],'atlas_region':[909,531,source_width,39],'plant_type':'deciduous','ground':True,'front':False})
            px+=width;columns-=count
for g in layout['gardens']:
    add(['flower_verge','shrub','vegetable_bed'][g['variant']],g['rect'],tag='garden_'+g['house'])
for i,p in enumerate(layout['plants']):
    if p['kind']=='tree':continue # The clean tree asset is a separate C4 deliverable.
    kind=p['kind'];r=p['rect'];add(kind,r,'evergreen' if kind=='bamboo' else 'deciduous',False,'plant_'+str(i))
    if kind=='bamboo':new_obstacles.append([r[0]+r[2]/2-12,r[1]+r[3]-13,24,10])
tree=json.loads((design/'干净树接口-v1.json').read_text())
shutil.copyfile(design/tree['source'],VILLAGE/'landscape-tree-v1.png')
for i,p in enumerate(layout['plants']):
    if p['kind']!='tree':continue
    x,y,w,h=p['rect'];r=tree['alpha_bbox_128'];sw,sh=r[2]-r[0],r[3]-r[1];scale=min(w/sw,h/sh)
    cfg['props'].append({'id':'land_tree_'+str(i),'file':'res://ayu_home/v4/assets/village/landscape-tree-v1.png','pos':[round(x+(w-sw*scale)/2),round(y+h-sh*scale)],'foot':y+h-4,'scale':[scale,scale],'atlas_region':[r[0],r[1],sw,sh],'plant_type':'deciduous','front':False})
    new_obstacles.append([x+w/2-13,y+h-16,26,13])
cfg['landscape_obstacles']=new_obstacles
cfg['obstacles']+=new_obstacles
(ASSETS/'village.json').write_text(json.dumps(cfg,ensure_ascii=False,indent=2)+'\n')
m=json.loads((ASSETS/'rooms.json').read_text());m['rooms']['village']=cfg
(ASSETS/'rooms.json').write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'new_props':sum(p['id'].startswith('land_') for p in cfg['props']),'root_collisions':len(new_obstacles),'new_trees':sum(p['kind']=='tree' for p in layout['plants']),'field_paths':len(layout['field_paths'])}))
