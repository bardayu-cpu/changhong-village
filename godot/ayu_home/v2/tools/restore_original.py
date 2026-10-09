#!/usr/bin/env python3
"""Lossless extraction/reassembly of the current approved Ayu house images.

No scene drawing, palette replacement, resampling or generative repainting.
Only opaque pixel masks and integer source coordinates. Concealed backing uses
cloned pixels from the same image, and its complete mask is saved for review.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageChops
import hashlib, json, shutil

V2=Path(__file__).resolve().parents[1]
GODOT=V2.parents[1]
REF=GODOT.parents[1]/'七缘地图2-裳泓村参考图/定稿形象图'
A=V2/'assets'; E=V2/'evidence/restoration'
if not REF.exists() and (V2/'reference_manifest.json').exists():
    REF=Path(json.loads((V2/'reference_manifest.json').read_text())['files'][0]['source']).parent
NAMES=['阿鱼家123.png','5-阿鱼家一楼平面图 2.png','5-阿鱼家二楼平面图 2.png']
def dump(path,data):path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def source_check():
    files=[]
    for name,slot in zip(NAMES,['exterior','floor1','floor2']):
        p=REF/name
        with Image.open(p) as im: size=list(im.size)
        files.append(dict(name=name,source=str(p),sha256=sha(p),size=size,usage={'exterior':'院子原画直接拆层','floor1':'客厅、餐厅原画直接裁切拆层','floor2':'原图已替换；二楼不在本次三处样板范围'}[slot]))
        shutil.copyfile(p,V2.parent/'assets'/f'{slot}.png')
    dump(V2/'reference_manifest.json',dict(changed_on='2026-10-04',instruction='每次开工和交付前重看定稿形象图；原图拆层，不重画',files=files))
    return files

class Scene:
    def __init__(self,name,src,crop,tile):
        self.name=name;self.src=src;self.crop=crop;self.ox,self.oy=crop[:2]
        self.original=src.crop(crop).convert('RGBA');self.floor=self.original.copy()
        self.mask=Image.new('L',self.original.size)
        self.tile=src.crop(tile).convert('RGBA');self.used=set()
        self.j=dict(size=list(self.original.size),source_crop=list(crop),props=[],obstacles=[],hotspots=[],windows=[],lamps=[],anchors={},walk_polygons=[])
    def point(self,p):return [p[0]-self.ox,p[1]-self.oy]
    def rect(self,r):return self.point(r[:2])+list(r[2:])
    def part(self,id,poly,foot,front=False,sort=None):
        mask=Image.new('L',self.original.size);ImageDraw.Draw(mask).polygon([self.point(p) for p in poly],fill=255)
        box=mask.getbbox()
        if not box:return
        im=self.original.crop(box);im.putalpha(mask.crop(box))
        name=f'{self.name}_{id}.png';im.save(A/name,optimize=True);self.used.add(name)
        self.j['props'].append(dict(id=id,file=name,pos=list(box[:2]),foot=foot-self.oy,front=front,source_box=[box[0]+self.ox,box[1]+self.oy,box[2]+self.ox,box[3]+self.oy]))
        # Repeated original floor tile is confined to pixels permanently hidden by
        # these extracted opaque pixels. No cloned pixel replaces visible art.
        fill=Image.new('RGBA',self.original.size)
        for y in range(0,fill.height,self.tile.height):
            for x in range(0,fill.width,self.tile.width):fill.paste(self.tile,(x,y))
        self.floor.paste(fill,(0,0),mask)
        self.mask=ImageChops.lighter(self.mask,mask)
    def box(self,id,r,foot,front=False):
        x,y,w,h=r;self.part(id,[(x,y),(x+w-1,y),(x+w-1,y+h-1),(x,y+h-1)],foot,front)
    def obstacle(self,r):self.j['obstacles'].append(self.rect(r))
    def anchor(self,id,p):self.j['anchors'][id]=self.point(p)
    def hot(self,id,label,p,a):self.j['hotspots'].append(dict(id=id,label=label,pos=self.point(p),approach=self.point(a)))
    def finish(self,spawn,walk):
        self.j['spawn']=self.point(spawn);self.j['walk_rect']=self.rect(walk)
        self.floor.save(A/f'{self.name}_floor.png',optimize=True)
        dump(A/f'{self.name}.json',self.j)
        composite=self.floor.copy()
        for p in sorted(self.j['props'],key=lambda p:p['foot']):composite.alpha_composite(Image.open(A/p['file']),tuple(p['pos']))
        assert ImageChops.difference(self.original.convert('RGB'),composite.convert('RGB')).getbbox() is None, self.name
        assert self.floor.getchannel('A').getextrema()==(255,255)
        self.original.convert('RGB').save(E/f'{self.name}-source.png',optimize=True)
        composite.convert('RGB').save(E/f'{self.name}-reassembled.png',optimize=True)
        self.mask.save(E/f'{self.name}-hidden-fill-mask.png',optimize=True)
        # A literal map of all hidden fill. Visible outpainting is not required:
        # the camera is clipped to the source room and fills the phone viewport.
        marked=Image.blend(self.original.convert('RGB'),Image.new('RGB',self.original.size,'#fa6b46'),.35)
        review=self.original.convert('RGB');review.paste(marked,(0,0),self.mask)
        review.save(E/f'{self.name}-fill-marked.png',optimize=True)
        placement={'items':[],'files':{}}
        for p in self.j['props']:
            im=Image.open(A/p['file']);w,h=im.size
            placement['files'][p['file']]={'anchor':[0,0]}
            placement['items'].append(dict(id=p['id'],file=p['file'],foot=p['pos']))
        dump(E/f'{self.name}-placement.json',placement)
        dump(E/f'{self.name}-extraction.json',dict(source_crop=self.crop,props=len(self.j['props']),max_pixel_difference=0,opaque_floor=True,hidden_fill_pixels=sum(self.mask.histogram()[1:]),visible_pixels_changed=0,external_outpainting=False))
        self.used.add(f'{self.name}_floor.png')
        return self.used

def exterior(src):
    s=Scene('exterior',src,(0,0,1448,1086),(697,673,817,740))
    s.part('neighbour_house',[(1150,64),(1180,12),(1369,11),(1400,64),(1397,194),(1169,196)],198)
    s.part('rear_tree',[(588,75),(610,39),(687,19),(725,0),(847,0),(894,32),(924,83),(938,134),(872,182),(709,180),(634,168)],183)
    s.part('rear_tree_left',[(478,106),(497,59),(557,44),(599,71),(615,143),(600,181),(492,179)],182)
    s.part('rear_grove_right',[(974,127),(1029,115),(1111,147),(1127,227),(1153,271),(1113,308),(1080,374),(1006,396),(980,374)],397)
    s.box('flower_fence',[24,248,323,43],291)
    s.box('garden_fence',[16,430,186,46],476)
    for i,(x,y) in enumerate([(71,44),(129,42),(190,41),(247,41),(305,40),(365,44)]):s.box('beehive_'+str(i),[x,y,40,44],y+44)
    s.part('tool_corner',[(147,527),(180,522),(218,533),(232,548),(255,550),(258,588),(154,593)],593)
    # Keep every original pixel, including the small decorative figure in the
    # supplied doorway. It is part of the approved art, not a fabricated NPC.
    s.part('house',[(353,428),(354,328),(376,306),(375,178),(712,177),(715,147),(798,147),(801,181),(986,179),(1003,418),(980,600),(849,601),(849,624),(691,624),(689,596),(355,592)],592)
    s.part('garage',[(184,434),(326,395),(360,402),(356,567),(343,584),(234,599),(172,578)],593)
    s.part('car',[(246,615),(259,596),(302,586),(325,574),(382,570),(414,578),(453,575),(483,585),(494,605),(499,645),(487,655),(459,657),(442,676),(424,685),(402,680),(391,668),(318,661),(289,667),(270,659),(261,649),(248,646)],677)
    s.part('shed',[(982,392),(1093,403),(1175,452),(1184,567),(1169,575),(1163,638),(1116,637),(1095,612),(991,595)],625)
    s.part('left_tree',[(0,476),(74,471),(103,506),(147,558),(127,598),(150,656),(115,695),(83,702),(76,781),(17,780),(13,720),(0,708)],760)
    s.part('right_tree',[(1111,608),(1165,603),(1208,620),(1246,655),(1226,713),(1167,749),(1080,755),(1054,725),(1066,663)],748)
    s.part('left_wall',[(46,745),(66,697),(91,697),(86,746),(146,781),(278,811),(373,817),(492,811),(601,819),(601,788),(639,788),(644,937),(600,938),(590,918),(281,922),(47,806)],938)
    s.part('right_wall',[(844,791),(884,791),(884,817),(991,812),(1114,774),(1176,737),(1174,623),(1188,623),(1196,521),(1219,521),(1243,749),(1224,822),(1131,895),(891,923),(844,937)],938)
    s.part('left_border_flowers',[(143,622),(211,654),(254,700),(353,707),(452,715),(511,751),(572,723),(621,772),(603,815),(373,817),(239,784),(147,744),(131,683)],811)
    s.part('right_border_flowers',[(845,777),(909,737),(1024,674),(1136,645),(1158,681),(1197,712),(1167,769),(1100,799),(932,816),(887,814)],816)
    # Independent pots/door surroundings at the exact original coordinates.
    for id,poly,foot in [
        ('pot_garage',[(314,544),(332,529),(348,532),(359,558),(351,594),(327,599),(317,580)],599),
        ('pot_window_left',[(495,550),(513,535),(534,547),(538,573),(530,597),(510,602),(500,584)],602),
        ('pot_window_right',[(659,540),(677,528),(695,542),(699,566),(690,601),(669,603)],603),
        ('pot_door_left',[(712,532),(727,515),(748,529),(748,548),(738,584),(719,584)],584),
        ('pot_door_right',[(857,551),(874,537),(888,547),(899,570),(888,605),(869,607)],607),
        ('pot_shed',[(922,552),(940,539),(958,551),(963,573),(953,606),(932,603)],606),
        ('bench',[(1218,524),(1266,524),(1278,538),(1278,555),(1223,559)],559),
    ]:s.part(id,poly,foot)
    s.j['lamps']=[[817,494,180],[591,502,140]]
    s.j['walk_polygons']=[[[135,593],[692,593],[692,629],[852,629],[852,602],[1107,603],[1165,646],[1146,723],[1040,777],[902,810],[834,820],[815,936],[813,1009],[665,1009],[665,934],[643,821],[565,807],[449,769],[332,768],[238,724],[134,677]]]
    s.obstacle([248,610,245,67]);s.obstacle([1095,606,68,30]);s.obstacle([507,576,28,25]);s.obstacle([667,579,25,25]);s.obstacle([868,582,26,25]);s.obstacle([932,585,27,25])
    s.hot('door','敲门拜访',[782,541],[782,651]);s.hot('xiduo','和喜多打招呼',[949,728],[919,744]);s.hot('bench','坐在门前台阶',[780,615],[821,675]);s.hot('flowers','看看院里的花',[493,764],[528,737]);s.hot('gate','回到镇上',[739,970],[739,972])
    for id,p in {'dog':[953,738],'work':[1077,649],'bench':[788,625]}.items():s.anchor(id,p)
    s.j['dog_roam']=[889,654,172,116]
    s.j['camera_ahead']=170;s.j['phone_world_height']=720
    return s,s.finish([753,897],[120,594,1068,421])

def living(src):
    s=Scene('living',src,(555,330,1038,810),(842,582,921,661))
    s.box('north_wall',[558,330,479,76],403)
    s.box('aquarium',[668,349,98,54],402)
    s.box('landscape',[802,362,67,38],397)
    s.part('lamp',[(888,380),(903,376),(911,393),(905,402),(903,424),(911,428),(909,441),(887,441),(885,430),(893,425),(893,402),(884,399)],441)
    s.part('sofa_north',[(622,402),(674,409),(679,401),(815,402),(833,412),(836,433),(831,469),(816,477),(620,478),(608,467),(608,432)],471)
    s.part('sofa_west',[(605,433),(629,432),(649,452),(659,469),(658,525),(663,534),(666,581),(661,596),(611,597),(600,584),(600,479)],591)
    s.part('square_tea',[(688,487),(785,487),(791,498),(790,560),(780,564),(779,579),(774,580),(771,567),(704,568),(702,579),(696,579),(691,566),(686,557)],574)
    s.part('tv',[(979,469),(1006,476),(1008,631),(1019,641),(1016,656),(970,656),(970,497)],649)
    s.part('plant_northwest',[(581,388),(596,383),(608,400),(604,418),(600,437),(582,438),(576,416)],438)
    s.part('plant_northeast',[(978,394),(1005,384),(1019,405),(1016,429),(1007,450),(988,452),(979,432),(968,412)],451)
    s.part('plant',[(625,604),(645,601),(662,617),(660,638),(650,660),(629,663),(618,645),(615,623)],660)
    s.part('plant_tv',[(985,592),(1006,586),(1019,605),(1018,626),(1009,643),(989,642),(980,628)],643)
    # Window and entrance are kept as original standing foreground architecture.
    s.box('south_window',[611,672,225,110],782)
    s.part('doorframe',[(850,709),(895,672),(939,699),(951,746),(950,786),(862,785)],791)
    s.box('south_wall_left',[555,681,58,129],810)
    s.box('south_wall_middle',[834,681,23,129],810)
    s.box('south_wall_right',[950,681,88,129],810)
    s.j['windows']=[s.rect([644,699,139,54])]
    # Only the original glass interiors move slowly; mullions/curtains stay put.
    s.j['window_panes']=[]
    for i,r in enumerate([[663,702,35,44],[715,702,35,44]]):
        name=f'living_view_{i}.png';x,y,w,h=r
        src.crop((x,y,x+w,y+h)).save(A/name,optimize=True);s.used.add(name)
        s.j['window_panes'].append(dict(file=name,pos=s.point([x,y])))
    for p in s.j['props']:
        if p['id']=='plant':p['front']=True
    s.j['lamps']=[s.point([899,390])+[170],s.point([975,719])+[100]]
    # Floor plan has an aquarium behind the sofa; access is at its open right end.
    for r in [[606,451,226,22],[603,474,61,119],[688,539,104,39],[973,494,40,161],[622,641,32,21],[886,424,24,17]]:s.obstacle(r)
    s.hot('fish','喂一撮鱼食',[717,376],[857,415]);s.hot('tv','开关电视',[994,526],[935,549]);s.hot('sofa','坐一会儿',[708,441],[835,507]);s.hot('album','翻开相册',[750,531],[821,577]);s.hot('lamp','开关落地灯',[898,395],[926,447]);s.hot('dining','去餐厅',[646,371],[861,399]);s.hot('exit','回到院子',[901,740],[902,667])
    for id,p in {'ayu_seat':[780,466],'father_seat':[635,516],'mother_seat':[637,578],'guest_seat':[696,466],'fish':[856,415],'clean':[865,613],'qiuqiu':[719,654],'luoluo':[710,455],'tiantian':[627,580],'qiuqiu_evening':[815,649],'luoluo_evening':[696,457],'tiantian_evening':[677,650]}.items():s.anchor(id,p)
    s.j['fish_rect']=s.rect([683,360,66,33]);s.j['tv_rect']=s.rect([982,481,15,98]);s.j['camera_ahead']=80
    return s,s.finish([902,661],[579,398,435,274])

def dining(src):
    s=Scene('dining',src,(390,16,706,406),(623,182,668,260))
    s.box('north_wall',[390,16,316,83],99)
    s.box('sideboard',[477,69,138,58],126)
    s.part('plant',[(638,57),(656,50),(675,66),(674,86),(666,116),(646,119),(636,98),(629,82)],119)
    s.part('chair_spare',[(528,136),(558,132),(563,141),(561,176),(552,192),(530,187)],184)
    s.part('chair_father',[(477,160),(490,151),(499,180),(489,215),(478,215),(470,198)],213)
    s.part('chair_mother',[(595,155),(607,165),(614,192),(611,218),(597,223),(588,201)],222)
    s.part('chair_sw',[(472,202),(485,208),(497,238),(488,258),(478,259),(470,243),(465,215)],257)
    s.part('chair_se',[(607,202),(624,200),(622,243),(608,261),(594,255),(591,238)],259)
    s.part('chair_ayu',[(512,239),(574,239),(584,255),(580,287),(558,287),(555,265),(541,262),(534,285),(511,283),(508,259)],284)
    # The table is a mask of the exact original ellipse and legs, not a redraw.
    s.part('round_table',[(516,163),(539,158),(564,163),(585,174),(602,191),(610,211),(607,228),(595,243),(578,254),(571,275),(562,273),(561,258),(534,258),(528,275),(519,272),(519,252),(499,245),(482,225),(478,207),(484,188),(498,173)],260)
    s.box('kitchen_door',[378,99,36,87],191)
    s.box('south_door',[619,335,56,70],405)
    s.box('south_wall',[465,331,155,24],355)
    s.j['lamps']=[s.point([549,164])+[220],s.point([479,84])+[90]]
    # Kitchen doorway provides side light; no invented window replaces the wall.
    s.j['windows']=[s.rect([402,115,8,52])]
    s.j['steam']=s.point([404,164])
    for r in [[482,208,123,60],[477,107,139,19],[640,94,32,24]]:s.obstacle(r)
    s.hot('meal','坐下来吃饭',[546,211],[636,286]);s.hot('tea','倒一杯温水',[500,87],[447,141]);s.hot('recipe','翻翻食谱',[586,91],[622,154]);s.hot('cook','看看厨房',[404,151],[433,177]);s.hot('living','回到客厅',[646,369],[652,329])
    for id,p in {'father_meal':[480,265],'mother_meal':[612,265],'ayu_meal':[548,290],'guest_meal':[545,185],'cook':[434,178],'mother_read':[607,235],'father_read':[487,232],'clean':[627,309],'qiuqiu':[446,303]}.items():s.anchor(id,p)
    s.j['camera_ahead']=65
    return s,s.finish([650,322],[419,134,257,200])

def main():
    A.mkdir(exist_ok=True);E.mkdir(exist_ok=True,parents=True);source_check()
    ext=Image.open(REF/NAMES[0]);f1=Image.open(REF/NAMES[1]);used=set()
    for fn,im in [(exterior,ext),(living,f1),(dining,f1)]:
        s,files=fn(im);used|=files;print(s.name,len(s.j['props']),'parts; visible pixel difference = 0')
    # Album/puzzle use this actual user-approved courtyard, no invented family photos.
    ext.save(A/'still_courtyard.png',optimize=True)
    for p in A.glob('*.png'):
        if p.name.startswith(('living_','dining_','exterior_')) and p.name not in used:p.unlink()
    for p in A.glob('*.import'):
        if not p.with_suffix('').exists():p.unlink()
    files={p.name:dict(bytes=p.stat().st_size,sha256=sha(p)) for p in A.iterdir() if p.suffix in ['.png','.json','.wav'] and p.name!='manifest.json'}
    dump(A/'manifest.json',dict(files=files,total_bytes=sum(x['bytes'] for x in files.values())))
    print('Original restoration assets:',len(files),'files,',sum(x['bytes'] for x in files.values()),'bytes')
if __name__=='__main__':main()
