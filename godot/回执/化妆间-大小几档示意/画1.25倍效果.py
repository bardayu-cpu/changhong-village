# 化妆间家具 1.25 倍效果（庄Z4）：底图和 60 件都从 GPT 4 倍原图直接缩到 ×0.3125（最近邻），整间 64 色，透明二值；人不动（84 高）
import json
from PIL import Image,ImageDraw,ImageFont
G="/Users/kayra_ayu/Desktop/苏七镇奇缘/游戏制作中-gpt 和 claude 合作/地图一-苏七镇/罗曼山庄/003-后厅/化妆间-精修-v1/"
CHR="/Users/kayra_ayu/Desktop/苏七镇奇缘/苏七镇奇缘-claude 总文件/godot/assets/characters/lm/"
parts=json.load(open(G+"../化妆间-代码零件-v1/零件表.json",encoding="utf-8"))["零件"]
K=1.25/4
def sh(n):
    im=Image.open(G+n+".png").convert("RGBA"); s=im.resize((round(im.width*K),round(im.height*K)),Image.NEAREST)
    a=s.getchannel("A").point(lambda v:255 if v>=128 else 0); return s.convert("RGB"),a
raw={p["名字"]:sh(p["名字"]) for p in parts}
W,H=raw["base"][0].size
sheet=Image.new("RGB",(W,H+700)); sheet.paste(raw["base"][0],(0,0)); x=0;y=H
for p in parts[1:]:
    r,a=raw[p["名字"]]; sheet.paste(r,(x,y),a); x+=r.width
    if x>W-150: x=0;y+=140
pal=sheet.quantize(colors=64,method=Image.Quantize.FASTOCTREE,dither=Image.Dither.NONE)
def q(n):
    r,a=raw[n]; t=r.quantize(palette=pal,dither=Image.Dither.NONE).convert("RGBA"); t.putalpha(a); return t
room=q("base")
for p in sorted(parts[1:],key=lambda p:p["foot_y"]):
    room.alpha_composite(q(p["名字"]),(round(p["x"]*K),round(p["y"]*K)))
def man(code,fr,x,foot):
    sp=Image.open(CHR+f"chr_LM-GUEST-{code}.png").convert("RGBA"); room.alpha_composite(sp.crop((fr*64,0,fr*64+64,84)),(x-32,foot-84))
f=lambda v:round(v*1.25)
man("06",12,f(228),f(160)); man("05",12,f(320),f(160)); man("09",0,f(290),f(330)); man("10",8,f(420),f(720)); man("03",0,f(120),f(300))
room.save("/private/tmp/claude-501/-Users-kayra-ayu-Desktop------/5aea46f8-f31e-450e-ad1e-081a63e7916c/scratchpad/shrink/room125.png")
# 手机一屏两张：上半（化妆台）、中段（首饰柜、衣架）
font=ImageFont.truetype("/System/Library/Fonts/Hiragino Sans GB.ttc",28)
views=[("手机一屏：化妆台这头",(W-540)//2,0),("手机一屏：往下走到衣架首饰柜",(W-540)//2,f(300)-300)]
th=room.resize((W*960//H,960),Image.NEAREST)
out=Image.new("RGB",(th.width+20+(540+20)*2,960+50),(32,27,24)); d=ImageDraw.Draw(out)
d.text((6,8),f"整间（{W}×{H}，比一屏宽、高）",font=font,fill=(250,242,228)); out.paste(th.convert("RGB"),(0,50))
s=960/H
for i,(name,vx,vy) in enumerate(views):
    vy=max(0,min(H-960,vy)); x0=th.width+20+i*560
    d.rectangle((vx*s,50+vy*s,(vx+540)*s,50+(vy+960)*s),outline=(255,60,60),width=3)
    d.text((x0,8),name,font=font,fill=(250,242,228)); out.paste(room.crop((vx,vy,vx+540,vy+960)).convert("RGB"),(x0,50))
out.save("/private/tmp/claude-501/-Users-kayra-ayu-Desktop------/5aea46f8-f31e-450e-ad1e-081a63e7916c/scratchpad/shrink/化妆间-1.25倍效果.png"); print(W,H,out.size)
