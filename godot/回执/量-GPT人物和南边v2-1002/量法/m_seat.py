import math, random, json, itertools
from PIL import Image
exec(open('m_people.py',encoding='utf-8').read().split("rows=[]")[0])   # 复用路径表
SC="/Users/kayra_ayu/Desktop/苏七镇奇缘/苏七镇奇缘-claude 总文件/godot/assets/layered/scene_roman_banquet_55/"
tab=Image.open(SC+'art_table.png').convert('RGBA')
c01=Image.open(G+'人物-C01-v1-20261002/chr_B55S-C01_v1.png').convert('RGBA')
cx0,cy0=130,140        # 占地中心（桌图左上角放 (40,40)）
SCX,SCY=cx0,cy0-18; RX,RY,A0=63.0,50.0,18.0
def seat(no):
    a=-math.pi/2+2*math.pi*(no-1)/10+math.radians(A0); return (SCX+math.cos(a)*RX, SCY+math.sin(a)*RY)
def face_base(sx,sy):
    dx,dy=cx0-sx,(cy0-18)-sy
    if abs(dx)>abs(dy)*1.2: return 8 if dx>0 else 4
    return 0 if dy>0 else 12
def crop_upper(sheet,base,keep=52):
    return sheet.crop((base*64,0,base*64+64,84)).crop((0,0,64,keep))
def seated(sheets,order,keep=52):
    """sheets: 十张精灵图；order 座位 1..10；返回合成图、每个座位的上半身（图、位置）"""
    parts=[]
    for no in range(1,11):
        sx,sy=seat(no); b=face_base(sx,sy)
        sp=crop_upper(sheets[no-1],b,keep)
        parts.append((no,sy,sp,(int(round(sx))-32,int(round(sy))-keep),b))
    return parts
def ext(sp,pos):
    a=sp.getchannel('A').point(lambda v:255 if v else 0); bb=a.getbbox()
    return (pos[0]+bb[0],pos[0]+bb[2]) if bb else (0,0)
def sil_overlap(p1,p2):
    a1=Image.new('L',(300,300),0); a1.paste(p1[2].getchannel('A').point(lambda v:255 if v else 0),p1[3])
    a2=Image.new('L',(300,300),0); a2.paste(p2[2].getchannel('A').point(lambda v:255 if v else 0),p2[3])
    from PIL import ImageChops
    return ImageChops.multiply(a1,a2).histogram()[255]
def metrics(parts):
    ov=[];sil=[]
    for i in range(10):
        a,b=parts[i],parts[(i+1)%10]
        e1,e2=ext(a[2],a[3]),ext(b[2],b[3])
        # 横向外框重叠（只在两个座位上下相差不大时算相邻的挤）
        o=min(e1[1],e2[1])-max(e1[0],e2[0]); ov.append(max(0,o)); sil.append(sil_overlap(a,b))
    return ov,sil
def compose(parts,tab_img=tab):
    cv=Image.new('RGBA',(260,260),(214,204,189,255))
    backs=[p for p in parts if p[1]<SCY-25]; fronts=[p for p in parts if p[1]>=SCY-25]
    for p in sorted(backs,key=lambda t:t[1]): cv.alpha_composite(p[2],p[3])
    cv.alpha_composite(tab_img,(40,40))
    for p in sorted(fronts,key=lambda t:t[1]): cv.alpha_composite(p[2],p[3])
    return cv
names=list(guests.keys())
sheets={n:Image.open(guests[n]).convert('RGBA') for n in names}
res={}
def run(label,ns,keep=52):
    parts=seated([sheets[n] if n in sheets else c01 for n in ns],list(range(1,11)),keep)
    ov,sil=metrics(parts)
    res[label]=dict(ns=ns,overlap=ov,sil=sil)
    print(label,'相邻横向外框重叠',ov,'最大',max(ov),'平均%.1f'%(sum(ov)/10),'；剪影重叠像素',sil,'最大',max(sil))
    return parts
# 1) 上次的 C01（十个座位都是 C01）当基线
base=run('C01×10(上次样品)',['C01']*10)
# 2) GUEST-01..10
p1=run('GUEST-01~10',names[:10])
# 3) 03..12（含两个小孩）
p2=run('GUEST-03~12(含小孩)',names[2:12])
# 4) 随机十个，试 20 次取最差
rng=random.Random(5); worst=None; allmax=[]
for t in range(20):
    ns=rng.sample(names[:10],10); parts=seated([sheets[n] for n in ns],list(range(1,11))); ov,sil=metrics(parts); allmax.append(max(ov))
    if worst is None or max(ov)>worst[0]: worst=(max(ov),ns,ov)
print('随机排 20 次（成人 10 位轮着坐）：每次最大重叠',allmax,'最差',worst[0],[n[-2:] for n in worst[1]])
res['random20']=allmax
# 5) 小孩坐大人椅子：只露 52 行的话，小孩（顶在第 31 行）能露多少
kid=sheets['LM-GUEST-11']; a=kid.crop((0,0,64,52)).getchannel('A').point(lambda v:255 if v else 0).getbbox(); print('小孩 11 号坐下（留上 52 行）露出的人：y %s、高 %d（站着 53 高，只露 %d%%）'%(a, a[3]-a[1], round((a[3]-a[1])/53*100)))
compose(p1).convert('RGB').resize((780,780),Image.NEAREST).save('out/seat_guest01_10_x3.png')
compose(p2).convert('RGB').resize((780,780),Image.NEAREST).save('out/seat_guest03_12_x3.png')
compose(base).convert('RGB').resize((780,780),Image.NEAREST).save('out/seat_c01_x3.png')
json.dump(res,open('out/seat_res.json','w'),ensure_ascii=False)

# ---- 「挤」的另一种量法：后面那位的头被前面的人盖掉多少（头 = 站姿帧顶上 28 行；小孩从 31 行起算）----
from PIL import ImageChops
def head_cover(parts, head_rows=28):
    out=[]
    order=sorted(parts,key=lambda t:(t[1],t[0]))   # y 小的在后面
    for idx,p in enumerate(order):
        sp=p[2]; a=sp.getchannel('A').point(lambda v:255 if v else 0); bb=a.getbbox()
        if not bb: out.append((p[0],0.0)); continue
        # 头：从这个人最上面一行往下 head_rows 行
        hm=Image.new('L',(300,300),0)
        top=bb[1]
        hm.paste(a.crop((0,top,64,min(top+head_rows,52))),(p[3][0],p[3][1]+top))
        n=hm.histogram()[255]
        occ=Image.new('L',(300,300),0)
        for q in order[idx+1:]:
            occ.paste(q[2].getchannel('A').point(lambda v:255 if v else 0),q[3],q[2].getchannel('A').point(lambda v:255 if v else 0))
        c=ImageChops.multiply(hm,occ).histogram()[255]
        out.append((p[0],c/n if n else 0.0))
    return out
print('--- 后面那位的头被前面的人盖掉的比例（头顶往下 28 行；0 = 一点没盖）')
for label,ns in (('C01×10(上次样品)',['C01']*10),('GUEST-01~10',names[:10]),('GUEST-03~12(含小孩)',names[2:12])):
    parts=seated([sheets[n] if n in sheets else c01 for n in ns],list(range(1,11)))
    hc=head_cover(parts)
    print(label,' '.join('%d号椅%.0f%%'%(no,c*100) for no,c in sorted(hc)),'；最多盖掉 %.0f%%，超过 30%% 的 %d 位'%(max(c for _,c in hc)*100,sum(1 for _,c in hc if c>0.3)))
    res[label+'_headcover']=hc
rng=random.Random(9); mx=[]; 
for t in range(20):
    ns=rng.sample(names[:10],10); parts=seated([sheets[n] for n in ns],list(range(1,11))); hc=head_cover(parts); mx.append(round(max(c for _,c in hc)*100))
print('成人随机排 20 次，每次最多盖掉的头（%）：',mx)
json.dump(res,open('out/seat_res.json','w'),ensure_ascii=False,default=list)
