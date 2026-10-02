import random, statistics as st, math
from PIL import Image
G="/Users/kayra_ayu/Desktop/苏七镇奇缘/游戏制作中-gpt 和 claude 合作/地图一-苏七镇/罗曼山庄/001-宴会厅/拆景/彩带-v1-20261002/"
FLOOR=(214,204,189); CARPET=(179,32,42)
def dist(a,b): return math.sqrt(sum((a[i]-b[i])**2 for i in range(3)))
sheets={'FX01 花瓣':('fx_B55S-FX01_v1.png',(12,12),4,4),'FX02 彩纸':('fx_B55S-FX02_v1.png',(10,10),4,6),'FX03 卷彩带':('fx_B55S-FX03_v1.png',(16,32),4,3)}
for name,(f,(cw,ch),cols,rows) in sheets.items():
    im=Image.open(f"{G}{f}").convert('RGBA'); print(name,im.size,'期望',(cw*cols,ch*rows),'alpha',sorted(set(im.getchannel('A').getdata())))
    for r in range(rows):
        fills=[];bbs=[];main=None
        for c in range(cols):
            cell=im.crop((c*cw,r*ch,c*cw+cw,r*ch+ch)); a=cell.getchannel('A')
            n=sum(1 for v in a.getdata() if v); bb=a.point(lambda v:255 if v else 0).getbbox()
            fills.append(round(n/(cw*ch),2)); bbs.append(bb)
        cell=im.crop((0,r*ch,cw,r*ch+ch)); px=[p[:3] for p in cell.getdata() if p[3]]
        # 主色：出现最多的颜色（描边是暗的，取亮度中位以上那批的中位色）
        lum=sorted(px,key=lambda p:0.3*p[0]+0.59*p[1]+0.11*p[2]); body=lum[len(lum)//3:]
        col=tuple(int(st.median(p[i] for p in body)) for i in range(3))
        edge=lum[0]
        print('  行',r,'主色',col,'最深描边色',edge,'每格填充率',fills,'帧0外框',bbs[0],'离地砖%.0f 离红毯%.0f'%(dist(col,FLOOR),dist(col,CARPET)))
# 手机屏上撒一把（用 GPT 真图，镜头缩放 0.9375）
phone=Image.open('out/phone_mid.png').convert('RGBA'); s=0.9375; rng=random.Random(11)
def cell(f,cw,ch,c,r):
    im=Image.open(G+f).convert('RGBA'); return im.crop((c*cw,r*ch,c*cw+cw,r*ch+ch))
pieces=[]
for r in range(4):
    for _ in range(5): pieces.append(('fx_B55S-FX01_v1.png',12,12,r))
for r in range(6):
    for _ in range(3): pieces.append(('fx_B55S-FX02_v1.png',10,10,r))
for r in range(3):
    for _ in range(2): pieces.append(('fx_B55S-FX03_v1.png',16,32,r))
rng.shuffle(pieces)
for f,cw,ch,r in pieces:
    im=cell(f,cw,ch,rng.randrange(4),r)
    im=im.resize((max(1,round(cw*s)),max(1,round(ch*s))),Image.NEAREST)
    phone.alpha_composite(im,(rng.randrange(10,500),rng.randrange(120,800)))
phone.convert('RGB').save('out/fx_phone_real.png')
phone.convert('RGB').crop((100,200,440,560)).resize((1020,1080),Image.NEAREST).save('out/fx_phone_real_zoom.png')
