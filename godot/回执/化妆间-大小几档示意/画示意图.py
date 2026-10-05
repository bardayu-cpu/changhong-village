# 化妆间 甲乙丙 示意图（总002）：GPT 精修缩 1 倍后拼；拉开的屋子用一段干净地板红毯往下接，只是示意
import json
from PIL import Image,ImageDraw,ImageFont
GPT="/Users/kayra_ayu/Desktop/苏七镇奇缘/游戏制作中-gpt 和 claude 合作/地图一-苏七镇/罗曼山庄/003-后厅/化妆间-精修-v1/"
TAB=GPT+"../化妆间-代码零件-v1/零件表.json"
CHR="/Users/kayra_ayu/Desktop/苏七镇奇缘/苏七镇奇缘-claude 总文件/godot/assets/characters/lm/"
parts=json.load(open(TAB,encoding="utf-8"))["零件"]
def s1(f):
    im=Image.open(f).convert("RGBA"); s=im.resize((im.width//4,im.height//4),Image.NEAREST)
    a=s.getchannel("A").point(lambda v:255 if v>=128 else 0); return s.convert("RGB"),a
imgs={p["名字"]:s1(GPT+p["名字"]+".png") for p in parts}
sheet=Image.new("RGB",(540,1400)); sheet.paste(imgs["base"][0],(0,0)); x=0;y=960
for p in parts[1:]:
    r,a=imgs[p["名字"]]; sheet.paste(r,(x,y),a); x+=r.width
    if x>440: x=0;y+=110
pal=sheet.quantize(colors=64,method=Image.Quantize.FASTOCTREE,dither=Image.Dither.NONE)
def q(name):
    r,a=imgs[name]; t=r.quantize(palette=pal,dither=Image.Dither.NONE).convert("RGBA"); t.putalpha(a); return t
Q={n:q(n) for n in imgs}
base=Q["base"]
CUTS=[190,272,372,472,575]   # 每排家具脚下往下一点，从这里插进空地
CLEAN=(300,400)              # 拿这一段干净地板+红毯往下接
def room(extra):
    if extra==0: H=960
    else: H=960+extra
    per=extra//len(CUTS) if extra else 0
    r=Image.new("RGBA",(540,H))
    # 底图：按切口分段，中间接干净段
    y0=0; out=0
    for c in CUTS+[960]:
        seg=base.crop((0,y0,540,c)); r.alpha_composite(seg,(0,out)); out+=c-y0; y0=c
        if c!=960 and per:
            k=0
            while k<per:
                h=min(CLEAN[1]-CLEAN[0],per-k)
                r.alpha_composite(base.crop((0,CLEAN[0],540,CLEAN[0]+h)),(0,out)); out+=h; k+=h
    def shift(yfoot): return sum(per for c in CUTS if yfoot>c)
    for p in sorted(parts[1:],key=lambda p:p["foot_y"]):
        f=p["foot_y"]//4
        r.alpha_composite(Q[p["名字"]],(p["x"]//4,p["y"]//4+shift(f)))
    return r,shift
def person(r,shift,code,fr,x,foot):
    sp=Image.open(CHR+f"chr_LM-GUEST-{code}.png").convert("RGBA")
    r.alpha_composite(sp.crop((fr*64,0,fr*64+64,84)),(x-32,foot+shift(foot)-84))
font=ImageFont.truetype("/System/Library/Fonts/Hiragino Sans GB.ttc",30)
small=ImageFont.truetype("/System/Library/Fonts/Hiragino Sans GB.ttc",24)
cols=[]
for name,extra,zoom,desc in [("现在",0,1,"一屏 · 人和东西原样"),("甲 拉开一屏半",480,1,"人和东西不变 · 过道放宽"),("乙 拉开两屏",960,1,"人和东西不变 · 过道更宽"),("丙 整间放大 2 倍",0,2,"人和东西一起放大")]:
    r,sh=room(extra)
    person(r,sh,"06",12,190,176); person(r,sh,"09",0,300,330); person(r,sh,"10",8,420,720)
    me_x,me_foot=190,176+sh(176)   # 「你」站在第二张化妆台前
    vw,vh=540//zoom,960//zoom
    vx=max(0,min(540-vw,me_x-vw//2)); vy=max(0,min(r.height-vh,me_foot-vh//2-60))
    phone=r.crop((vx,vy,vx+vw,vy+vh)).resize((540,960),Image.NEAREST)
    thumb_h=1920//2; sc=thumb_h/1920
    th=r.resize((int(540*sc),int(r.height*sc)),Image.NEAREST)
    cols.append((name,desc,th,phone,(vx*sc,vy*sc,(vx+vw)*sc,(vy+vh)*sc)))
CW=560; TOP=110; TH=1920//2+20
W=CW*4; H=TOP+TH+60+960+30
out=Image.new("RGB",(W,H),(32,27,24)); d=ImageDraw.Draw(out)
for i,(name,desc,th,phone,box) in enumerate(cols):
    x0=i*CW+10
    d.text((x0,14),name,font=font,fill=(250,242,228)); d.text((x0,58),desc,font=small,fill=(242,194,62))
    tx=x0+(540-th.width)//2
    out.paste(th.convert("RGB"),(tx,TOP))
    d.rectangle((tx+box[0],TOP+box[1],tx+box[2],TOP+box[3]),outline=(255,60,60),width=4)
    d.text((x0,TOP+TH+10),"↓ 手机上一屏看到的（红框那块）",font=small,fill=(250,242,228))
    out.paste(phone.convert("RGB"),(x0,TOP+TH+50))
d.text((10,H-28),"示意图：拉开的地方是拿现有地板红毯接长的，正式的会重画底图；红框 = 手机一屏",font=small,fill=(180,170,160))
out.save("/private/tmp/claude-501/-Users-kayra-ayu-Desktop------/5aea46f8-f31e-450e-ad1e-081a63e7916c/scratchpad/shrink/化妆间-甲乙丙示意.png")
print(out.size)
