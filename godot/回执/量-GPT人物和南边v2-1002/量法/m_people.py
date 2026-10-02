import json, math, glob, os, random, statistics as st
from PIL import Image
G="/Users/kayra_ayu/Desktop/苏七镇奇缘/游戏制作中-gpt 和 claude 合作/地图一-苏七镇/罗曼山庄/001-宴会厅/拆景/"
guests={}
guests['LM-GUEST-01']=G+'人物-LM-GUEST-01-v2-20261002/chr_LM-GUEST-01_v2.png'
for n in range(2,13):
    guests['LM-GUEST-%02d'%n]=G+'人物-LM-GUEST-02至12-v1-20261002/LM-GUEST-%02d/chr_LM-GUEST-%02d_v1.png'%(n,n)
waiters={}
for n in range(1,31):
    d='人物-LM-WAITER-%02d至%02d-v1-20261002'%((n-1)//10*10+1,(n-1)//10*10+10)
    waiters['LM-WAITER-%02d'%n]=G+d+'/LM-WAITER-%02d/chr_LM-WAITER-%02d_v1.png'%(n,n)
def frame_bb(im,k,row=0):
    f=im.crop((k*64,row*84,k*64+64,row*84+84)); return f, f.getchannel('A').point(lambda a:255 if a else 0).getbbox()
rows=[]
def stats(name,path,row=0):
    im=Image.open(path).convert('RGBA')
    hs=[];ws=[];tops=[];bots=[]
    for k in range(16):
        f,bb=frame_bb(im,k,row)
        hs.append(bb[3]-bb[1]); ws.append(bb[2]-bb[0]); tops.append(bb[1]); bots.append(bb[3])
    side=[ws[k] for k in list(range(4,12))]
    return dict(name=name,h_min=min(hs),h_max=max(hs),top=min(tops),bot=max(bots),w_first=ws[0],w_down=max(ws[0:4]),w_side=max(side),w_up=max(ws[12:16]),w_max=max(ws))
G_ST=[stats(n,p) for n,p in guests.items()]
W_ST=[stats(n,p,0) for n,p in waiters.items()]
print('== 宾客 站着高、宽（16 帧）')
for s in G_ST: print(s)
print('== 服务员（普通行）')
for s in W_ST: print(s['name'],'高',s['h_min'],s['h_max'],'顶',s['top'],'底',s['bot'],'第一格宽',s['w_first'],'朝下最宽',s['w_down'],'侧身最宽',s['w_side'],'朝上最宽',s['w_up'])
json.dump({'guests':G_ST,'waiters':W_ST},open('out/people_stats.json','w'),ensure_ascii=False)
