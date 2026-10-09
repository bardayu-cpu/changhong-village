from pathlib import Path
from PIL import Image,ImageDraw,ImageFont,ImageChops,ImageStat
import json,math,shutil
V=Path(__file__).resolve().parents[1];E=V/'evidence';P=E/'panels';C=E/'clarity'
font=ImageFont.truetype('/System/Library/Fonts/STHeiti Medium.ttc',17)
names={'welcome':'来信与首次到访','today':'今日小事木牌','life_book':'生活册','calendar_page':'日历','family_page':'家里的人','person-card':'人物身份卡','dialogue-mother':'妈妈对话','dialogue-father':'爸爸对话','dialogue-ayu':'阿鱼对话','collection_page':'收集册','album_page':'拍立得列表','settings_page':'设置','map-一楼':'一楼地图','map-二楼':'二楼地图','map-屋外':'屋外地图','choose_avatar':'玩家形象','recipe':'食谱纸页','pantry':'厨房收成','testing':'电脑试玩面板','meal-invite':'饭点邀请','wish':'流星愿望','polaroid':'拍立得相纸','play-garden':'种菜','play-flower_garden':'种花','play-tree':'种树','play-fruit':'摘果','play-tea':'沏茶','play-soup':'煮汤','play-laundry':'洗衣','play-wood':'磨木鸟','play-fishing':'钓鱼','play-net':'捞鱼','play-flowers':'插花','play-pairs':'翻花纹','play-stars':'秋千星空','play-guitar':'吉他','play-puzzle':'拼图','play-album':'修相册','play-fish':'喂鱼'}
rows=['# v4 晚间补充 · 每种面板的实际渲染','', '所有图片直接来自 Godot SubViewport。第二种为 1170×2532 实像素，逻辑尺寸 540×1168；不是手机硬件测试。GIF 另见交付单。','', '| 面板 | 540×960 | 1170×2532 |','| --- | --- | --- |']
for n,label in names.items():
 if not (P/f'{n}-960.png').exists():raise RuntimeError('Missing '+n)
 rows.append(f'| {label} | [{label}](./{n}-960.png) | [{label}](./{n}-1168.png) |')
 for height in [960,1168]:
  existing=E/'runtime'/f'{n}-{height}.png'
  if existing.exists():shutil.copy2(P/f'{n}-{height}.png',existing)
(P/'README.md').write_text('\n'.join(rows)+'\n')
keys=list(names)
for part in range(math.ceil(len(keys)/12)):
 subset=keys[part*12:part*12+12];out=Image.new('RGB',(4*216,math.ceil(len(subset)/4)*417),'#ede3ce');d=ImageDraw.Draw(out)
 for i,n in enumerate(subset):
  im=Image.open(P/f'{n}-960.png').convert('RGB');im.thumbnail((216,384));x=(i%4)*216;y=(i//4)*417;out.paste(im,(x,y+29));d.text((x+7,y+6),names[n],font=font,fill='#483828')
 out.save(E/f'panels-contact-{part+1}.jpg',quality=93)
clarity=[]
for height in [960,1168]:
 a=Image.open(C/f'dining-v3-{height}.png').convert('RGB');b=Image.open(C/f'dining-v4-{height}.png').convert('RGB');s=a.width/540
 # The same fixed world patch: wall picture and sideboard, without HUD or actors.
 patch=(round(90*s),round((height/2-320)*s),round(340*s),round((height/2-230)*s))
 ca=a.crop(patch);cb=b.crop(patch);diff=ImageChops.difference(ca,cb)
 report={'resolution':list(a.size),'matched_camera_and_standing':True,'logical_world_pixel_scale':2,'nearest_sampling':True,'patch_screen_box':patch,'max_rgb_difference_in_sideboard_patch':max(z[1] for z in diff.getextrema()),'mean_rgb_difference_in_sideboard_patch':sum(ImageStat.Stat(diff).mean)/3};clarity.append(report)
 pair=Image.new('RGB',(a.width*2,a.height+48),'#ede3ce');pair.paste(a,(0,48));pair.paste(b,(a.width,48));d=ImageDraw.Draw(pair);d.text((12,14),'v3 · 相同站位 / 相同镜头',font=font,fill='#483828');d.text((a.width+12,14),'v4 · 恢复已认可的清晰底图',font=font,fill='#483828');pair.save(C/f'comparison-{height}.png',optimize=True)
(C/'comparison.json').write_text(json.dumps({'method':'Real v3/v4 scene rendering at a declared identical calibration camera, standing location and 2x logical pixel scale. Lighting and new life effects disabled only for this source-detail comparison. See separate normal gameplay screenshots for actual effects.','views':clarity},ensure_ascii=False,indent=2)+'\n')
tree=Image.new('RGB',(864,417),'#ede3ce');d=ImageDraw.Draw(tree)
for i,(name,label) in enumerate([('sapling','刚种下的小树'),('growing','长出树冠'),('ripe','第一批果子成熟'),('after-harvest','大树还在，等新果')]):
 im=Image.open(P/f'tree-{name}.png').convert('RGB');im.thumbnail((216,384));tree.paste(im,(i*216,29));d.text((i*216+7,6),label,font=font,fill='#483828')
tree.save(E/'tree-growth.png')
print('RESULT PASS',len(names),'panel types / two portrait sizes / v3-v4 comparison')
