extends SceneTree
## Native, deterministic C4 scene composition from existing assets; no gameplay window.
const OUT="/Users/kayra_ayu/Desktop/苏七镇奇缘/cursor-claude-1010/裳泓村/回执/第1轮/设计/村外铺景/v2/"
const PROJECT="/Users/kayra_ayu/Desktop/苏七镇奇缘/cursor-claude-1010/裳泓村/"
const DESIGN="/Users/kayra_ayu/Desktop/苏七镇奇缘/cursor-claude-1010/裳泓村/回执/第1轮/设计/村外铺景/"
const S=3.0
var layout:Dictionary
var atlas:Image
var ground:Image
var canvas:Image
var cache={}
var leafs:Array[Image]=[]
var props:Array=[]
func _initialize():
	layout=JSON.parse_string(FileAccess.get_file_as_string(OUT+"完整美术布局-v2.json"))
	DirAccess.make_dir_recursive_absolute(OUT+"assets")
	atlas=Image.load_from_file(DESIGN+"村外地表田埂竹花-九格source-v1.png");atlas.convert(Image.FORMAT_RGBA8)
	var concrete=atlas.get_region(Rect2i(119,125,209,209));concrete.resize(64,64,Image.INTERPOLATE_NEAREST)
	var grass=atlas.get_region(Rect2i(522,125,209,209));grass.resize(64,64,Image.INTERPOLATE_NEAREST)
	var soil=atlas.get_region(Rect2i(925,125,209,209));soil.resize(64,64,Image.INTERPOLATE_NEAREST)
	ground=Image.create(1600,1567,false,Image.FORMAT_RGBA8)
	for y in ground.get_height():
		for x in ground.get_width():
			var c=sample(grass,x,y).lerp(Color("8eab69"),.65)
			var k=sin(float(x)*.011)*sin(float(y)*.009)*.045
			c.r+=k;c.g+=k*.55;c.b+=k*.32;c.a=1
			ground.set_pixel(x,y,c)
	print("C4 base meadow authored")
	# Whole connected network masks are completed before any interior texture fill.
	var all_roads:Array=layout.main_roads.duplicate();all_roads.append_array(layout.gate_connectors)
	var road_outer=mask();var road_inner=mask()
	for i in all_roads.size():stroke(road_outer,all_roads[i],126 if i<layout.main_roads.size() else 76,Color.WHITE)
	for i in all_roads.size():stroke(road_inner,all_roads[i],112 if i<layout.main_roads.size() else 67,Color.WHITE)
	paint_mask(road_outer,null,Color("aa997b"),1)
	paint_mask(road_inner,concrete,Color("c4bda8"),.57)
	var water=mask();stroke(water,layout.river,85,Color.WHITE);paint_mask(water,null,Color("567f70"),1)
	water=mask();stroke(water,layout.river,62,Color.WHITE);paint_mask(water,null,Color("59a6a0"),1)
	water=mask();stroke(water,layout.river,39,Color.WHITE);paint_mask(water,null,Color("80c1b8"),1)
	for yy in layout.bridge_y:
		fill_world(ground,Rect2(3434,yy-45,202,90),Color("6c533b"));fill_world(ground,Rect2(3440,yy-34,190,68),Color("bd9360"))
		for xx in range(3444,3628,12):fill_world(ground,Rect2(xx,yy-34,3,68),Color("8e6745"))
	make_leafs()
	for f in layout.fields:
		var fm=mask();polygon_fill(fm,f.polygon,Color.WHITE);paint_mask(fm,soil,Color("956f42"),.46)
		# One continuous earthen/grassy perimeter, with a real access gap.
		var bm=mask();stroke(bm,f.perimeter,18,Color.WHITE);paint_mask(bm,null,Color("745c37"),1)
		bm=mask();stroke(bm,f.perimeter,11,Color.WHITE);paint_mask(bm,soil,Color("b99a58"),.68)
		var r=f.rect;var rows=int(f.rows);var cols=int(f.columns)
		for row in rows:
			var yy=r[1]+23+row*f.row_gap
			var fur=mask();stroke(fur,[[r[0]+20,yy+17],[r[0]+r[2]-20,yy+17]],4,Color.WHITE);paint_mask(fur,null,Color("765c39"),1)
			for col in cols:
				if f.kind=="spaced" and (col+row)%7==0:continue
				if f.kind=="mixed" and row==rows-1 and col%3==0:continue
				var leaf=leafs[(col*3+row+int(f.id.get_slice("_",2)))%leafs.size()].duplicate()
				leaf.resize(27 if f.kind=="nursery" else 31,26 if f.kind=="nursery" else 29,Image.INTERPOLATE_NEAREST)
				var px=r[0]+22+col*f.spacing+(5 if row%2 else 0)
				blend_world(ground,leaf,Vector2(px,yy))
	for d in layout.drains:
		var dm=mask();stroke(dm,d.boundary_path,d.width+6,Color.WHITE);stroke(dm,d.outlet_path,d.width+6,Color.WHITE);paint_mask(dm,null,Color("999b87"),1)
		dm=mask();stroke(dm,d.boundary_path,d.width,Color.WHITE);stroke(dm,d.outlet_path,d.width,Color.WHITE);paint_mask(dm,null,Color("586f69"),1)
		dm=mask();stroke(dm,d.boundary_path,max(3,d.width-6),Color.WHITE);stroke(dm,d.outlet_path,max(3,d.width-6),Color.WHITE);paint_mask(dm,null,Color("7a9a87"),1)
		if d.has("pit"):fill_world(ground,Rect2(d.pit[0]-15,d.pit[1]-9,36,24),Color("728778"))
	for p in layout.field_paths:
		var m=mask();stroke(m,p.points,p.width+7,Color.WHITE);paint_mask(m,null,Color("ad9065"),1)
		m=mask();stroke(m,p.points,p.width,Color.WHITE);paint_mask(m,soil,Color("c9b482"),.83)
	# Patch the access opening through each perimeter using the field path's packed soil.
	for f in layout.fields:
		var r=f.rect;var entry=mask();var a=r[0]+r[2]-42 if r[0]<100 else r[0]-35;var b=r[0]+r[2]+35 if r[0]<100 else r[0]+42;stroke(entry,[[a,r[1]+r[3]+12],[b,r[1]+r[3]+12]],30,Color.WHITE);paint_mask(entry,soil,Color("baa277"),.9)
	for g in layout.gardens:draw_garden(g)
	ground.resize(4800,4700,Image.INTERPOLATE_NEAREST)
	ground.convert(Image.FORMAT_RGB8);ground.save_png(OUT+"ground-c4-v2.png");ground.convert(Image.FORMAT_RGBA8)
	for p in layout.plants:make_raised(p)
	canvas=ground.duplicate();var ordered:Array=layout.base_props.duplicate();ordered.append_array(props)
	ordered.sort_custom(func(a,b):return float(a.foot)<float(b.foot))
	for p in ordered:
		var path=p.get("design_file","")
		if path=="":path=PROJECT+"godot/"+str(p.file).trim_prefix("res://") if str(p.file).begins_with("res://") else PROJECT+"godot/ayu_home/v3/assets/"+str(p.file)
		var image=Image.load_from_file(path);image.convert(Image.FORMAT_RGBA8)
		if p.has("atlas_region"):
			var a=p.atlas_region;image=image.get_region(Rect2i(a[0],a[1],a[2],a[3]))
		if p.has("scale"):image.resize(roundi(image.get_width()*p.scale[0]),roundi(image.get_height()*p.scale[1]),Image.INTERPOLATE_NEAREST)
		canvas.blend_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),Vector2i(p.pos[0],p.pos[1]))
	var overview=canvas.duplicate();overview.resize(1200,1175,Image.INTERPOLATE_NEAREST);overview.save_png(OUT+"全村美术预览-v2.png")
	canvas.get_region(Rect2i(2870,850,890,860)).save_png(OUT+"东田同机位近景-v2.png")
	canvas.get_region(Rect2i(3280,1860,1230,700)).save_png(OUT+"河岸田沟近景-v2.png")
	canvas.get_region(Rect2i(70,2090,1050,760)).save_png(OUT+"磨坊院路绿化-v2.png")
	canvas.get_region(Rect2i(1220,35,410,690)).save_png(OUT+"北巷长田与路口-v2.png")
	var f=FileAccess.open(OUT+"新增物件接口-v2.json",FileAccess.WRITE);f.store_string(JSON.stringify({"props":props,"root_rects":layout.plants.filter(func(p):return p.root_collision!=null).map(func(p):return p.root_collision),"copy_policy":"C2 only copies exported ground/assets and exact props, no redraw/replan","preview_type":"C4 native asset composition, not game runtime"},"  "));f.close()
	print("C4 full map/plots/banks/ditches/gardens composited; ",props.size()," raised props");quit()
func mask():return Image.create(1600,1567,false,Image.FORMAT_RGBA8)
func mirror(n:int):
	var p=posmod(n,128);return p if p<64 else 127-p
func sample(texture:Image,x:int,y:int):return texture.get_pixel(mirror(x),mirror(y)).lerp(texture.get_pixel(mirror(x/2+37),mirror(y/2+19)),.27)
func paint_mask(m:Image,tex:Image,c:Color,base_mix:float):
	var used=m.get_used_rect()
	for y in range(used.position.y,used.end.y):
		for x in range(used.position.x,used.end.x):
			if m.get_pixel(x,y).a==0:continue
			var out=c if tex==null else sample(tex,x,y).lerp(c,base_mix);out.a=1;ground.set_pixel(x,y,out)
func fill_world(im:Image,r:Rect2,c:Color):im.fill_rect(Rect2i(floori(r.position.x/S),floori(r.position.y/S),max(1,ceili(r.size.x/S)),max(1,ceili(r.size.y/S))),c)
func disk(im:Image,p:Vector2,r:float,c:Color):
	var cx=p.x/S;var cy=p.y/S;var rr=r/S
	for yy in range(max(0,floori(cy-rr)),min(im.get_height(),ceili(cy+rr)+1)):
		var dx=sqrt(maxf(0,rr*rr-pow(float(yy)-cy,2)));var xx=max(0,floori(cx-dx));var right=min(im.get_width(),ceili(cx+dx)+1)
		im.fill_rect(Rect2i(xx,yy,max(0,right-xx),1),c)
func stroke(im:Image,path:Array,width:float,c:Color):
	for i in range(path.size()-1):
		var a=Vector2(path[i][0],path[i][1]);var b=Vector2(path[i+1][0],path[i+1][1]);var n=max(1,ceili(a.distance_to(b)/6))
		for j in range(n+1):disk(im,a.lerp(b,float(j)/n),width/2,c)
func polygon_fill(im:Image,points:Array,c:Color):
	var ys=points.map(func(p):return p[1]/S)
	for yy in range(floori(ys.min()),ceili(ys.max())+1):
		var xs=[]
		for i in points.size():
			var a=Vector2(points[i][0]/S,points[i][1]/S);var b=Vector2(points[(i+1)%points.size()][0]/S,points[(i+1)%points.size()][1]/S)
			if (a.y<=yy and b.y>yy) or (b.y<=yy and a.y>yy):xs.append(a.x+(yy-a.y)*(b.x-a.x)/(b.y-a.y))
		xs.sort()
		for i in range(0,xs.size()-1,2):im.fill_rect(Rect2i(floori(xs[i]),yy,ceili(xs[i+1]-xs[i]),1),c)
func make_leafs():
	# Render existing green plant pixels; the original atlas stays unchanged.
	for i in 6:
		var im=atlas.get_region(Rect2i(909+i*44,531,44,39))
		for y in im.get_height():
			for x in im.get_width():
				var c=im.get_pixel(x,y)
				if c.g-c.r<-.02 or c.g<c.b*1.15:c.a=0;im.set_pixel(x,y,c)
		leafs.append(im)
func blend_world(to:Image,im:Image,at:Vector2):
	var small=im.duplicate();small.resize(max(1,roundi(im.get_width()/S)),max(1,roundi(im.get_height()/S)),Image.INTERPOLATE_NEAREST)
	to.blend_rect(small,Rect2i(Vector2i.ZERO,small.get_size()),Vector2i(roundi(at.x/S),roundi(at.y/S)))
func atlas_piece(key:String):
	var rect={"flower_verge":Rect2i(436,935,375,174),"shrub":Rect2i(854,903,355,236),"bamboo":Rect2i(72,792,302,398)}[key]
	return atlas.get_region(rect)
func draw_garden(g:Dictionary):
	var r=g.rect;var x=r[0];var y=r[1];var w=r[2];var h=r[3]
	# Preserve the continuous meadow under low plants; no rectangular green patch.
	var n=3 if g.axis=="horizontal" else 5
	for i in n:
		var key="flower_verge" if (i+int(g.variant))%3 else "shrub";var piece=atlas_piece(key)
		var pw=100 if g.axis=="horizontal" else 68;var ph=(46 if key=="flower_verge" else 54) if g.axis=="horizontal" else (58 if key=="flower_verge" else 68)
		piece.resize(pw,ph,Image.INTERPOLATE_NEAREST)
		if i%2:piece.flip_x()
		var px=x+i*(w-pw)/max(1,n-1) if g.axis=="horizontal" else x+(i%2)*10;var py=y+15+(i%2)*8 if g.axis=="horizontal" else y+i*(h-ph)/max(1,n-1)
		blend_world(ground,piece,Vector2(px,py))
func make_raised(p:Dictionary):
	var r=p.rect;var im:Image
	if p.kind=="tree":
		var raw=Image.load_from_file(DESIGN+"村外干净树-source-v1.png");raw.convert(Image.FORMAT_RGBA8);im=raw.get_region(Rect2i(25,92,1034,1241))
	else:im=atlas_piece(p.kind)
	var k=min(float(r[2])/im.get_width(),float(r[3])/im.get_height());im.resize(roundi(im.get_width()*k),roundi(im.get_height()*k),Image.INTERPOLATE_NEAREST)
	if p.mirror:im.flip_x()
	var name=p.id+".png";im.save_png(OUT+"assets/"+name)
	props.append({"id":p.id,"file":"res://ayu_home/v4/assets/village/c4-landscape-v2/"+name,"design_file":OUT+"assets/"+name,"pos":[roundi(r[0]+(r[2]-im.get_width())*.5),roundi(r[1]+r[3]-im.get_height())],"foot":p.foot[1],"ground":false,"front":false,"plant_type":"evergreen" if p.kind=="bamboo" else "deciduous","root_rect":p.root_collision,"group":p.group})
