from pathlib import Path
from PIL import Image,ImageDraw
import json,random
R=Path(__file__).resolve().parents[1];A=R/'godot/ayu_home/v4/assets';V=A/'village';P=R/'godot/ayu_home/v3/assets';N=Image.Resampling.NEAREST
m=json.loads((A/'rooms.json').read_text());world=m['rooms']['village'];index=json.loads((V/'houses.json').read_text())
def cut(src,points,size,out):
 im=Image.open(src).convert('RGBA');mask=Image.new('L',im.size);ImageDraw.Draw(mask).polygon(points,fill=255);im.putalpha(mask);im=im.crop(mask.getbbox());im.resize(size,N).save(out)
garden=P/'garden.png'
cut(garden,[(849,163),(860,154),(877,139),(907,124),(944,133),(965,144),(982,173),(1001,190),(1009,232),(989,261),(966,275),(943,279),(944,304),(955,324),(898,325),(908,300),(902,279),(871,271),(843,252),(835,224),(838,193)],(150,168),V/'fruit_tree.png')
cut(garden,[(600,175),(619,158),(634,142),(662,137),(681,122),(717,132),(745,145),(771,159),(782,190),(790,223),(782,248),(756,271),(722,284),(715,304),(729,328),(666,328),(673,299),(661,279),(624,265),(605,244),(591,218)],(150,168),V/'apple_tree.png')
cut(garden,[(1103,192),(1130,162),(1154,143),(1183,128),(1218,146),(1251,168),(1268,199),(1279,232),(1260,260),(1225,280),(1210,309),(1225,329),(1160,329),(1173,294),(1158,275),(1127,267),(1109,242),(1097,212)],(150,168),V/'pear_tree.png')
cut(garden,[(333,102),(345,72),(365,63),(383,51),(406,72),(421,85),(435,118),(443,149),(415,169),(399,174),(403,217),(381,222),(383,175),(358,162),(334,136)],(125,175),V/'green_tree.png')
cut(garden,[(996,772),(1020,736),(1106,695),(1190,681),(1285,704),(1331,754),(1340,811),(1313,863),(1200,881),(1073,861),(1004,830)],(435,245),V/'pond.png')
for i,p in enumerate(world['props']):
 if p.get('plant_type'):
  p['file']='res://ayu_home/v4/assets/village/'+('green_tree.png' if p['plant_type']=='evergreen' else ['fruit_tree.png','apple_tree.png','pear_tree.png'][i%3])
world['props'].append(dict(id='public_pond',file='res://ayu_home/v4/assets/village/pond.png',pos=[1035,1000],foot=1210,front=False))
# Distinct one-storey architecture assembled from actual approved roof and wall pixels.
src=R/'素材来源/房屋 5.png'
cut(src,[(406,226),(454,172),(540,166),(540,123),(574,122),(575,165),(902,150),(928,283),(898,315),(900,471),(728,512),(538,512),(478,472),(433,461),(432,246)],(425,363),V/'tea_house_building.png')
cut(src,[(904,152),(1006,137),(1268,341),(1266,365),(1239,354),(1232,544),(1000,553),(925,510),(900,366),(892,300)],(410,440),V/'field_house_building.png')
# The original tiny background house gives the river-side household a compact vertical form.
cut(R/'素材来源/房屋 4.png',[(1314,49),(1338,5),(1499,3),(1525,37),(1515,57),(1516,159),(1496,177),(1330,173),(1324,67)],(390,334),V/'river_house_building.png')
for id,building in [('h8','tea_house_building.png'),('h4','field_house_building.png'),('h6','river_house_building.png')]:
 rec=next(x for x in index if x['id']==id);ww,hh=rec['bounds'][2:];canvas=Image.new('RGBA',(ww,hh));b=Image.open(V/building).convert('RGBA');x=(ww-b.width)//2;y=hh-b.height-35;canvas.alpha_composite(b,(x,y))
 # Simple covered working annexes are varied by function and footprint.
 if id=='h4':
  shed=Image.open(P/'exterior_shed.png').convert('RGBA').resize((210,195),N);canvas.alpha_composite(shed,(12,hh-210))
 elif id=='h8':
  bench=Image.open(P/'exterior_bench.png').convert('RGBA').resize((115,62),N);canvas.alpha_composite(bench,(ww-155,hh-100))
 for dx in [x-35,min(ww-55,x+b.width+5)]:
  pot=Image.open(P/'exterior_pot_window_left.png').convert('RGBA');canvas.alpha_composite(pot,(dx,hh-97))
 canvas.save(V/f'house_{id}.png')
# Village office uses another approved elevation; patch the incidental drawn person with a matching door.
im=Image.open(R/'素材来源/房屋 4.png').convert('RGBA');door=Image.open(R/'素材来源/房屋 6.png').crop((612,442,729,585)).convert('RGBA').resize((80,121),N);im.alpha_composite(door,(803,438));mask=Image.new('L',im.size);ImageDraw.Draw(mask).polygon([(55,853),(80,704),(121,547),(140,438),(177,407),(414,323),(419,144),(562,145),(565,107),(700,105),(863,57),(1021,104),(1099,209),(1093,310),(1284,371),(1316,443),(1383,667),(1390,846),(967,898),(718,896),(278,873)],fill=255);im.putalpha(mask);im.resize((745,545),N).save(V/'house_mayor.png')
(A/'village.json').write_text(json.dumps(world,ensure_ascii=False,indent=2));(A/'rooms.json').write_text(json.dumps(m,ensure_ascii=False,indent=2))
# Replace the schematic pond underneath the detailed rock-edged pond. Add soft pixel edges to paths.
im=Image.open(V/'ground.png').convert('RGBA');dr=ImageDraw.Draw(im);random.seed(91)
# Original rectangular water is fully covered except an intentional narrow leading channel.
for i in range(18000):
 x=random.randrange(im.width);y=random.randrange(im.height)
 c=im.getpixel((x,y))
 if c[:3] in [(209,182,134),(199,173,125)]:
  dr.rectangle((x,y,x+random.randrange(2,8),y+random.randrange(1,3)),fill=random.choice(['#c2a777','#d9bf8d','#ceb37f']))
im.save(V/'ground.png')
bg=im.copy()
for prop in sorted(world['props'],key=lambda x:x['foot']):
 path=prop['file'];src=R/'godot'/path.removeprefix('res://') if path.startswith('res://') else P/path;art=Image.open(src).convert('RGBA');bg.alpha_composite(art,tuple(prop['pos']))
bg.thumbnail((1150,1500),N);bg.save(R/'交付/完整村庄-1006/村庄总览-场景素材合成.png')
print('Crisp tree silhouettes; three distinct small-house footprints; public office and pond refined')
