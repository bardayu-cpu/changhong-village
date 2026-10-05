# 家具放大几档对比（总002）：从 GPT 4 倍原图直接缩到目标大小（最近邻），颗粒仍是 1 个画布像素；人不动
import json
from PIL import Image,ImageDraw,ImageFont
G="/Users/kayra_ayu/Desktop/苏七镇奇缘/游戏制作中-gpt 和 claude 合作/地图一-苏七镇/罗曼山庄/003-后厅/化妆间-精修-v1/"
CHR="/Users/kayra_ayu/Desktop/苏七镇奇缘/苏七镇奇缘-claude 总文件/godot/assets/characters/lm/"
def part(n,k):
    im=Image.open(G+n+".png").convert("RGBA"); w,h=round(im.width*k/4),round(im.height*k/4)
    s=im.resize((w,h),Image.NEAREST); s.putalpha(s.getchannel("A").point(lambda v:255 if v>=128 else 0)); return s
base=Image.open(G+"base.png").convert("RGBA").resize((540,960),Image.NEAREST)
floor=base.crop((20,300,200,400))  # 一块木地板
def man(code,fr):
    sp=Image.open(CHR+f"chr_LM-GUEST-{code}.png").convert("RGBA"); return sp.crop((fr*64,0,fr*64+64,84))
font=ImageFont.truetype("/System/Library/Fonts/Hiragino Sans GB.ttc",15)
panels=[]
for k,name in [(1.0,"现在 1 倍"),(1.25,"家具放大 1.25 倍"),(1.5,"家具放大 1.5 倍")]:
    W,H=int(270*k)+110,int(122*k)+28
    pn=Image.new("RGBA",(W,H))
    for x in range(0,W,180):
        for y in range(0,H,100): pn.alpha_composite(floor,(x,y))
    foot=H-12
    items=[("rack_w1",4),("dresser_2",4+round(150*k)+6)]
    rack=part("rack_w1",k); pn.alpha_composite(rack,(4,foot-rack.height))
    p=man("09",0); pn.alpha_composite(p,(4+rack.width//2-10,foot+6-84)) if False else None
    dr=part("dresser_2",k); dx=4+rack.width+8; pn.alpha_composite(dr,(dx,foot-60-dr.height))
    st=part("stool_2",k); pn.alpha_composite(st,(dx+dr.width//2-st.width//2,foot-60-st.height+round(15*k)))
    pn.alpha_composite(man("06",12),(dx+dr.width//2-32,foot-60+round(15*k)+4-84))
    pn.alpha_composite(man("09",0),(dx+dr.width+6,foot-84))
    pn.alpha_composite(man("10",0),(4+rack.width-40,foot+2-84))
    big=pn.resize((W*2,H*2),Image.NEAREST)
    d=ImageDraw.Draw(big); d.rectangle((0,0,230,26),fill=(32,27,24)); d.text((6,4),name,font=ImageFont.truetype("/System/Library/Fonts/Hiragino Sans GB.ttc",20),fill=(250,242,228))
    panels.append(big)
out=Image.new("RGB",(sum(p.width for p in panels)+20,max(p.height for p in panels)),(32,27,24)); x=0
for p in panels: out.paste(p.convert("RGB"),(x,out.height-p.height)); x+=p.width+10
out.save("/private/tmp/claude-501/-Users-kayra-ayu-Desktop------/5aea46f8-f31e-450e-ad1e-081a63e7916c/scratchpad/shrink/家具放大对比.png"); print(out.size)
