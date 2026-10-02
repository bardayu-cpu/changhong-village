from PIL import Image
G="/Users/kayra_ayu/Desktop/苏七镇奇缘/游戏制作中-gpt 和 claude 合作/地图一-苏七镇/罗曼山庄/001-宴会厅/拆景/彩带-v1-20261002/"
prev=Image.open(G+'预览-红绸挂灯柱-1比1.png').convert('RGB'); base=Image.open('out/silk_base.png').convert('RGB')
sheet=Image.open(G+'blk_B55S-P06_v1.png').convert('RGBA')
print('sheet',sheet.size,'frames',[sheet.crop((k*160,0,k*160+160,56)).getchannel('A').point(lambda a:255 if a else 0).getbbox() for k in range(3)])
print('alpha',sorted(set(sheet.getchannel('A').getdata())))
pp=prev.load(); bp=base.load()
# 预览和底图差在哪（找红绸像素）
diff=[(x,y) for y in range(300) for x in range(400) if sum(abs(pp[x,y][k]-bp[x,y][k]) for k in range(3))>30]
xs=[p[0] for p in diff]; ys=[p[1] for p in diff]
print('预览里和底图不同的像素数',len(diff))
# 分成两簇（第 1、2 排）
for lo,hi in ((0,150),(150,300)):
    d=[p for p in diff if lo<=p[1]<hi]
    if d: print('排',lo,'bbox',min(p[0] for p in d),min(p[1] for p in d),max(p[0] for p in d),max(p[1] for p in d),len(d))
# 模板匹配：每一格在预览里的位置
def match(frame,y_lo,y_hi):
    fa=frame.load(); pts=[(i,j,fa[i,j][:3]) for j in range(0,56,1) for i in range(0,160,1) if fa[i,j][3]==255]
    best=None
    for y0 in range(y_lo,y_hi):
        for x0 in range(100,160):
            hit=0
            for i,j,c in pts[::3]:
                if pp[x0+i,y0+j][:3]==c: hit+=1
            if best is None or hit>best[0]: best=(hit,x0,y0)
    return best,len(pts[::3])
for k in range(3):
    fr=sheet.crop((k*160,0,k*160+160,56))
    print('格',k,match(fr,40,75))
