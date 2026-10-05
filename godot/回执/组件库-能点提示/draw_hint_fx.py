# 「这里能点」引导动效样子（总002，10/5）：像素硬边，颜色取组件库第二节第 1 条
# 出：fx_tap_sparkle.png（星光 4 帧）、fx_tap_ripple.png（地上波纹 4 帧）、fx_tap_twinkle.png（常驻小闪 3 帧），每帧一格横排；预览放大 6 倍
from PIL import Image
GOLD=(0xf2,0xc2,0x3e,255); CREAM=(0xfa,0xf2,0xe4,255); EDGE=(0x16,0x0c,0x05,255); BRASS=(0xbf,0x80,0x44,255)
def sheet(frames,w,h):
    im=Image.new("RGBA",(w*len(frames),h),(0,0,0,0))
    for i,f in enumerate(frames):
        for (x,y),c in f.items(): im.putpixel((i*w+x,y),c)
    return im
def outline(px,w,h):
    out=dict(px)
    for (x,y) in px:
        for dx,dy in ((1,0),(-1,0),(0,1),(0,-1)):
            q=(x+dx,y+dy)
            if q not in px and 0<=q[0]<w and 0<=q[1]<h: out.setdefault(q,EDGE)
    return out
def star(r,cx,cy,core):
    px={}
    for i in range(-r,r+1):
        c=CREAM if abs(i)<=core else GOLD
        px[(cx+i,cy)]=c; px[(cx,cy+i)]=c
    if r>=3:
        for dx,dy in ((1,1),(1,-1),(-1,1),(-1,-1)): px[(cx+dx,cy+dy)]=GOLD
    return px
# 星光 11×11：0 小点 → 1 小十字 → 2 大星 → 3 收回小十字
S=11;c=5
sp=[star(1,c,c,0),star(3,c,c,1),star(5,c,c,1),star(2,c,c,0)]
sp=[outline(f,S,S) for f in sp]
# 地上波纹：斜俯视，椭圆宽高 3:2；32×22，四帧外扩，最后一帧断开成点
import math
W,H=32,22
def ring(a,b,dashed=False):
    # 椭圆内的格子里，挨着外面的那一圈当边（干净的一格线）
    cx,cy=W/2-0.5,H/2-0.5
    inside=lambda x,y:((x-cx)/a)**2+((y-cy)/b)**2<=1
    px={}
    for y in range(H):
        for x in range(W):
            if not inside(x,y): continue
            if all(inside(x+dx,y+dy) for dx,dy in ((1,0),(-1,0),(0,1),(0,-1))): continue
            t=math.atan2((y-cy)/b,(x-cx)/a)
            if dashed and int((math.degrees(t)+360)//24)%2: continue
            px[(x,y)]=CREAM if y>cy else GOLD
    return px
rp=[ring(4.5,3),ring(8.5,5.5),ring(12.5,8.5),ring(15.5,10.5,True)]
rp=[outline(f,W,H) for f in rp]
# 常驻小闪 7×7：小点 → 小十字 → 小点
T=7
tw=[outline(star(0,3,3,0),T,T),outline(star(2,3,3,0),T,T),outline(star(1,3,3,0),T,T)]
for name,fr,w,h in [("fx_tap_sparkle",sp,S,S),("fx_tap_ripple",rp,W,H),("fx_tap_twinkle",tw,T,T)]:
    im=sheet(fr,w,h); im.save(name+".png")
# 预览：放在木地板色上，放大 6 倍
bg=(0xc8,0x8f,0x55,255)
pw=6; rows=[("fx_tap_sparkle",S,S,4),("fx_tap_ripple",W,H,4),("fx_tap_twinkle",T,T,3)]
Wt=max(w*n+6*n for _,w,h,n in rows)+6; Ht=sum(h+6 for _,w,h,n in rows)+6
pv=Image.new("RGBA",(Wt,Ht),bg); y=6
for name,w,h,n in rows:
    im=Image.open(name+".png")
    for i in range(n): pv.alpha_composite(im.crop((i*w,0,(i+1)*w,h)),(6+i*(w+6),y))
    y+=h+6
pv.resize((Wt*pw,Ht*pw),Image.NEAREST).save("预览-放大6倍.png")
