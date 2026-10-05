# 娱乐室布局图 v2（庄Z4，10/6）：照 GPT 加宽拼装表的摆位画色块，第一排麻将往下挪 30 让开闲聊区、游戏区
import json
from PIL import Image,ImageDraw,ImageFont
SRC="/Users/kayra_ayu/Desktop/苏七镇奇缘/游戏制作中-gpt 和 claude 合作/地图一-苏七镇/罗曼山庄/003-后厅/娱乐室-v1/拼装表-加宽.json"
t=json.load(open(SRC,encoding="utf-8")); W,H=t["画布"]
inst=t["实例"]
row1=set()
for i in inst:
    if i["实例"].endswith("_table") and i["实例"].startswith("mahjong") and i["foot_y"]<500: row1.add(i["实例"][:-6])
for i in inst:
    if any(i["实例"].startswith(r+"_") for r in row1): i["y"]+=30; i["foot_y"]+=30
# 闲聊区、游戏区整体往上提 30（让开第一排两边的北椅）
for i in inst:
    k=i["零件"][:3]
    if k in ("Y05","Y06","Y08") or i["实例"].startswith("tv_"): i["y"]-=30; i["foot_y"]-=30
COL={"Y01":(40,120,80),"Y02":(150,90,50),"Y03":(70,70,140),"Y04":(150,60,40),"Y05":(170,50,50),"Y06":(60,60,70),"Y08":(200,140,60),"Y09":(120,80,50),"Y10":(130,80,50),"Y11":(70,140,70)}
NAME={"Y03":"炸金花","Y04":"贰柒拾","Y06":"电视","Y10":"长椅","Y09":"茶水台/柜"}
F=lambda n:ImageFont.truetype("/System/Library/Fonts/Hiragino Sans GB.ttc",n)
im=Image.new("RGB",(W,H),(222,180,120)); d=ImageDraw.Draw(im)
d.rectangle((0,0,W,150),fill=(236,222,196)); d.text((W//2-150,8),"北墙：木窗 · 挂画 · 灯笼",font=F(30),fill=(110,60,40))
d.rectangle((0,1380,W,H),fill=(120,80,50)); d.rectangle((490,1380,610,H),fill=(222,180,120)); d.text((530,1395),"门",font=F(30),fill=(60,30,20))
d.rectangle((0,0,20,H),fill=(120,80,50)); d.rectangle((W-20,0,W,H),fill=(120,80,50))
# 玩家那张的地毯
pt=[i for i in inst if i["实例"].startswith("mahjong") and i["实例"].endswith("_table") and 600<i["foot_y"]<800 and 450<i["x"]<600]
if pt:
    p=pt[0]; cx=p["x"]+p["w"]//2; d.rectangle((cx-130,p["y"]-80,cx+130,p["foot_y"]+70),fill=(176,52,40),outline=(225,175,70),width=4)
for i in sorted(inst,key=lambda i:i["foot_y"]):
    k=i["零件"][:3]; c=COL.get(k,(110,110,110))
    d.rectangle((i["x"],i["y"],i["x"]+i["w"],i["y"]+i["h"]),fill=c,outline=(35,20,10),width=2)
    if k in NAME and i["w"]>=40:
        tw=d.textlength(NAME[k],font=F(18)); d.text((i["x"]+(i["w"]-tw)/2,i["y"]+i["h"]//2-10),NAME[k],font=F(18),fill=(255,255,255))
for x,y,s in [(200,330,"沙发瓜子闲聊区"),(880,330,"电子游戏区")]:
    tw=d.textlength(s,font=F(22)); d.rectangle((x-tw/2-6,y-4,x+tw/2+6,y+28),fill=(30,20,15)); d.text((x-tw/2,y),s,font=F(22),fill=(250,242,228))
if pt:
    s="玩家坐这张（地毯上）"; tw=d.textlength(s,font=F(22)); d.rectangle((cx-tw/2-6,p["foot_y"]+76,cx+tw/2+6,p["foot_y"]+108),fill=(30,20,15)); d.text((cx-tw/2,p["foot_y"]+80),s,font=F(22),fill=(250,242,228))
# 人 84 的尺子
d.rectangle((720,1290,748,1374),fill=(250,240,220),outline=(35,20,10),width=2); d.text((754,1320),"人 84",font=F(18),fill=(35,20,10))
im.save("娱乐室-布局图-v2.jpg",quality=92)
json.dump({"说明":"娱乐室布局 v2：GPT 加宽拼装表摆位，第一排麻将整组 y+30，闲聊区、游戏区 y-30","画布":[W,H],"实例":inst},open("布局-v2.json","w",encoding="utf-8"),ensure_ascii=False,indent=1)
print(sorted(row1))
