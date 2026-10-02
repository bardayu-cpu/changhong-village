import sys, runpy, json, statistics as st
G="/Users/kayra_ayu/Desktop/苏七镇奇缘/游戏制作中-gpt 和 claude 合作/地图一-苏七镇/罗曼山庄/001-宴会厅/拆景/"
REPO="/Users/kayra_ayu/Desktop/苏七镇奇缘/苏七镇奇缘-claude 总文件/godot/"
sys.argv=['x','south','/tmp/unused']
mod=runpy.run_path(REPO+'tools/layout_55/export_block_for_gpt.py',run_name='lib')
from PIL import Image
south=Image.open(G+'南边·照色块-v2-20261002/base_B55S-BG02_v2.png').convert('RGB')
north=Image.open(G+'北边·照色块-v2-20261002/base_B55S-BG01_v2.png').convert('RGB')
parts,bgs,scene=mod['build_catalog']()
res=mod['measure_bg_south'](south,bgs)
for r in res: print(r['item'],r['edge'],'色块',r['expect'],'GPT',r['found'],'差',r['diff'],'强度',r['strength'],'' if r['clear'] else '看不清')
json.dump(res,open('out/south_probe_v2.json','w'),ensure_ascii=False)
edge_x=mod['edge_x']
def trace(img,xe,y0,y1,step=8,win=14):
    px=img.load(); out=[]
    for y in range(y0,y1-step,step):
        g,s=edge_x(px,range(y,y+step),xe,win); out.append((y,g,round(s,1)))
    return out
def summarize(name,tr,exp):
    xs=[g for y,g,s in tr if s>=12]
    print(name,'期望',exp,'行数',len(tr),'有效',len(xs),'min',min(xs),'max',max(xs),'中位',st.median(xs),'标准差',round(st.pstdev(xs),2))
    return xs
print('--- 墙直不直（逐 8 行找里边那条缝）')
summarize('南 西墙里边 x40（块内 y 0~1067）',trace(south,40,0,1067),40)
summarize('南 东墙里边 x1496',trace(south,1496,0,1067),1496)
summarize('北 西墙里边 x40（y 300~1024）',trace(north,40,300,1024),40)
summarize('北 东墙里边 x1496（y 300~1024）',trace(north,1496,300,1024),1496)
print('--- 红毯左右缘')
summarize('南 红毯左缘 696',trace(south,696,0,860),696)
summarize('南 红毯右缘 840',trace(south,840,0,860),840)
summarize('北 红毯左缘 696（y 360~1024）',trace(north,696,360,1024),696)
summarize('北 红毯右缘 840',trace(north,840,360,1024),840)
# 接缝处红毯边：北边最后 20 行 vs 南边最前 20 行
mx=[]
for img,y0,y1 in ((north,1004,1024),(south,0,20)):
    px=img.load()
    l=edge_x(px,range(y0,y1),696,14); r=edge_x(px,range(y0,y1),840,14); mx.append((l,r))
print('接缝处红毯边 北最后20行',mx[0],'南最前20行',mx[1])
print('--- 墙偏离 46/1490 超过 3 的行段（块内 y）')
for nm,xe,ref in (('西',40,46),('东',1496,1490)):
    tr=trace(south,xe,0,1067)
    print(nm,[(y,g,s) for y,g,s in tr if abs(g-ref)>3])
