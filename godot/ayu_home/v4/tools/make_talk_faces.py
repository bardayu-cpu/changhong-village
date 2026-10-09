"""第七轮 村-1：对话框头像（组件库第 4 条）。阿鱼 10/5 定：对话头像用像素画，跟罗曼定稿一样——
缩图一律最近邻、硬边（不平滑、边上不留半透明），一次缩到头像格那么大（112×129，从头顶到胸口、脸在左右正中），游戏里按 1 倍贴。
现在先用 portraits.png 顶着也照这个缩法；GPT 交的像素立绘到了以后换来源再跑一次。用法：python3 godot/ayu_home/v4/tools/make_talk_faces.py"""
from pathlib import Path
from PIL import Image
A=Path(__file__).resolve().parents[1]/'assets'
src=Image.open(A/'portraits.png').convert('RGBA')
REG={"ayu":(90,55,370,535),"father":(580,18,385,572),"mother":(1048,50,413,550)}
FACE=(112,129)
for k,(x,y,w,h) in REG.items():
	im=src.crop((x,y,x+w,y+h));bb=im.getbbox();im=im.crop(bb)
	W=int(im.width*{"ayu":.62}.get(k,.80));H=int(W*FACE[1]/FACE[0]) # 阿鱼头小、身子长，裁窄一点才只到胸口
	# 脸在左右正中：按头顶那一截（上面 30%）的不透明范围找中线
	head=im.crop((0,0,im.width,int(im.height*.3))).getbbox()
	cx=(head[0]+head[2])//2
	x0=max(0,min(im.width-W,cx-W//2))
	face=im.crop((x0,0,x0+W,H)).resize(FACE,Image.NEAREST)
	a=face.getchannel('A').point(lambda v:255 if v>=128 else 0);face.putalpha(a) # 硬边：边上不留半透明
	face.save(A/'talk-faces'/(k+'.png'));print(k,im.size,'→',FACE)
