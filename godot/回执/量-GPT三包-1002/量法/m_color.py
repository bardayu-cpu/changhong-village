from PIL import Image
import statistics as st
G="/Users/kayra_ayu/Desktop/苏七镇奇缘/游戏制作中-gpt 和 claude 合作/地图一-苏七镇/罗曼山庄/001-宴会厅/拆景/"
S=Image.open('out/gpt_stitch.png').convert('RGB'); px=S.load()
def floor_med(y0,y1,xr):
    vals=[]
    for y in range(y0,y1):
        for x in xr:
            c=px[x,y]
            if c[0]-c[2]<55 and c[0]>180 and c[1]>170:   # 地砖底色，不要花和线
                vals.append(c)
    return tuple(int(st.median(v[i] for v in vals)) for i in range(3)), len(vals)
def stat(y0,y1):
    out=[]
    for xr in (range(100,650),range(900,1440)):
        out.append(floor_med(y0,y1,xr))
    return out
print('北边 y 944~1024',stat(944,1024))
print('南边 y 1024~1104',stat(1024,1104))
print('北边 y 864~944',stat(864,944))
print('南边 y 1104~1184',stat(1104,1184))
# 接缝行差：缝上下两行平均差 vs 北边内部相邻行平均差
def rowdiff(ya,yb,xr):
    return sum(sum(abs(px[x,ya][k]-px[x,yb][k]) for k in range(3)) for x in xr)/len(xr)/3
xr=list(range(100,650))+list(range(900,1440))
print('缝 y1023|1024 行差',round(rowdiff(1023,1024,xr),2))
nat_n=[rowdiff(y,y+1,xr) for y in range(900,1020)]
nat_s=[rowdiff(y,y+1,xr) for y in range(1030,1150)]
print('北边内部相邻行平均差',round(sum(nat_n)/len(nat_n),2),'最大',round(max(nat_n),2),'；南边内部',round(sum(nat_s)/len(nat_s),2),'最大',round(max(nat_s),2))
# 瓦片
t=Image.open(G+'南边·照色块-v1-20261002/tex_B55S-W01_v3.png').convert('RGBA'); tp=t.load()
print('瓦片',t.size)
cols=[tp[x,y][:3] for y in range(52) for x in range(80)]
print('瓦片中位色',tuple(int(st.median(c[i] for c in cols)) for i in range(3)))
# 瓦片四边接得上：左右列差、上下行差
lr=sum(sum(abs(tp[0,y][k]-tp[79,y][k]) for k in range(3)) for y in range(52))/52/3
tb=sum(sum(abs(tp[x,0][k]-tp[x,51][k]) for k in range(3)) for x in range(80))/80/3
inner_lr=sum(sum(abs(tp[40,y][k]-tp[41,y][k]) for k in range(3)) for y in range(52))/52/3
inner_tb=sum(sum(abs(tp[x,25][k]-tp[x,26][k]) for k in range(3)) for x in range(80))/80/3
print('瓦片首尾列差 %.2f 内部相邻列差 %.2f；首尾行差 %.2f 内部相邻行差 %.2f'%(lr,inner_lr,tb,inner_tb))
t.resize((320,208),Image.NEAREST).save('out/tile_x4.png')
# 瓦片拼 4×3 看
big=Image.new('RGB',(320,156))
for i in range(4):
    for j in range(3): big.paste(t.convert('RGB'),(i*80,j*52))
big.resize((960,468),Image.NEAREST).save('out/tile_tiled.png')
# 北边背景里同一块区域对比：取 80×52 窗，在地砖区找花的位置
