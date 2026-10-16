extends Node2D
const Assets = preload("res://ayu_home/v2/assets.gd")
const Art = preload("res://ayu_home/v4/redraw_art.gd")
const Actor = preload("res://ayu_home/v4/actor.gd")
const P := "res://ayu_home/v3/assets/"
const ROOMS := "res://ayu_home/v4/assets/"
const SPRING_SHADER = preload("res://ayu_home/v4/assets/village/c4-spring-v1/season-material.gdshader")
const SPRING_BINDINGS := "res://ayu_home/v4/assets/village/c4-spring-v1/bindings.json"
var CELL := 4
static var shared_light_texture:Texture2D
var life
var use_baked_navigation:=true
var local_lighting:=false
var door_samples:Dictionary={}
var debug_paths := false
var effects_enabled := true
var area := "exterior"
var cfg: Dictionary = {}
var actors: Node2D
var ground: Node2D
var atmosphere: Node2D
var props: Array = []
var obstacles: Array[Rect2] = []
var grid := AStarGrid2D.new()
var hour := 12.0
var month := 10
var weather := "clear"
var elapsed := 0.0
var lamp_on := true
var tv_on := true
var tv_channel:=0
var ball_visible:=false
var ball_position:=Vector2.ZERO
var steam_player_until:=0.0
var food_until := 0.0
var camera_center := Vector2.ZERO
var ambient: CanvasModulate
var lights: Array[PointLight2D] = []
var windows: Array = []
var reactions:Dictionary={}
var toggles:Dictionary={}
var sharp:=false # 关掉：它把原图里很淡的纹理拉成一层颗粒，就是阿鱼说的「失真」（体验师 10/5 量过）
var light_rect:=Rect2()
var table_top:Node2D
var plane_cache:Dictionary={}
static var season_shader:Shader
static var village_spring_bindings:Dictionary={}
static var black_spring_mask:Texture2D
var village_material_cache:Dictionary={}
var plant_materials:Array=[]
var season_material:ShaderMaterial
var sharp_material:ShaderMaterial
var base_sprite:Sprite2D
var nearest_cache:Dictionary={}
var parallax_origin := Vector2.ZERO

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

## 只算路（home.nav 给家人在别的房间找路用的那几份）：不读图，只要房间数据和能走范围。
## 手机上图是分批下载的，不读图才不会一开家就要把一楼、二楼的大底图都下完
var nav_only:=false
func art(path:String) -> Texture2D:return null if nav_only else Assets.texture(path)
func load_room(which: String) -> void:
	for n in get_children(): remove_child(n); n.queue_free()
	props.clear();lights.clear();obstacles.clear();windows.clear();nearest_cache.clear();plane_cache.clear()
	area = which
	cfg = JSON.parse_string(FileAccess.get_file_as_string(ROOMS+area+".json"))
	CELL=int(cfg.get("nav_cell",4))
	var bg := Sprite2D.new();bg.centered = false;add_child(bg);base_sprite=bg
	if int(cfg.get("floor",0)) in [1,2]:
		bg.texture=art("res://ayu_home/v4/assets/floor1-redraw/floor1.png" if int(cfg.floor)==1 else P+"approved-2.png")
		bg.position=v(cfg.source_offset)-v(cfg.source_crop)
	else:bg.texture = art(asset_path(str(cfg.get("background",area+"_floor.png"))))
	if cfg.get("floor",0)==1 and sharp:bg.material=sharpen_material()
	# 屋外的季节和雨：冬天草和树叶上盖一层雪，秋天叶子泛黄，雨天地面发暗发凉（后花园有四季原图，不叠）
	season_material=null;plant_materials.clear();village_material_cache.clear()
	if cfg.get("outdoor",false) and area!="garden":
		season_material=make_village_season_material(asset_path(str(cfg.background)),0,0) if area=="village" else make_season_material()
		bg.material=season_material
	ground = Node2D.new();ground.draw.connect(_ground_draw);add_child(ground)
	actors = Node2D.new();actors.y_sort_enabled = true;add_child(actors)
	for p in cfg.props:
		var base := Node2D.new();base.position = Vector2(0,float(p.foot))
		(ground if p.get("ground",false) else actors).add_child(base)
		var sp := Sprite2D.new();sp.centered = false;sp.texture = art(asset_path(p.file));sp.position = v(p.pos)-base.position;base.add_child(sp)
		if p.has("atlas_region"):
			var region_texture:=AtlasTexture.new();region_texture.atlas=sp.texture
			var r:Array=p.atlas_region;region_texture.region=Rect2(r[0],r[1],r[2],r[3]);region_texture.filter_clip=true;sp.texture=region_texture
		if p.has("scale"):sp.scale=v(p.scale)
		if cfg.get("floor",0)==1 and sharp:
			var mat:=sharpen_material().duplicate();var src_origin:=v(cfg.source_crop)+v(p.pos)-v(cfg.source_offset);mat.set_shader_parameter("source_origin",src_origin);sp.material=mat
		if season_material:
			if area=="village":
				var source:=asset_path(p.file)
				var binding:Dictionary=get_village_spring_bindings().get("props",{}).get(str(p.id),{})
				# 当前接口无图集；源图或UV变化时用黑遮罩，不能误把背景掩区套到房屋上。
				var matched:bool=binding.get("texture","")==source and not p.has("atlas_region")
				var kind:int=int(binding.plant_kind) if matched else int({"fruit":3,"deciduous":1,"evergreen":2}.get(str(p.get("plant_type","")),0))
				var sm:=make_village_season_material(source,kind,int(binding.get("spring_layer_kind",1)),matched)
				sp.material=sm
				if not plant_materials.has(sm):plant_materials.append(sm)
			elif p.has("plant_type"):
				var sm:=make_season_material();sm.set_shader_parameter("plant_kind",{"fruit":3,"deciduous":1,"evergreen":2}.get(str(p.plant_type),0));sp.material=sm;plant_materials.append(sm)
			else:sp.material=season_material
		props.append({"root":base,"sprite":sp,"origin":sp.position,"config":p})
	for pane in []:
		var view=preload("res://ayu_home/v2/window_view.gd").new()
		view.texture=art(P+pane.file);view.centered=false;view.position=v(pane.pos);view.z_index=2
		var shader:=Shader.new();shader.code="shader_type canvas_item; uniform float shift=0.0; void fragment(){COLOR=texture(TEXTURE,vec2(clamp(UV.x+shift,0.0,1.0),UV.y));}"
		var mat:=ShaderMaterial.new();mat.shader=shader;view.material=mat;add_child(view);windows.append(view)
	for b in cfg.obstacles: obstacles.append(Rect2(b[0],b[1],b[2],b[3]))
	# 窗光只落在本房间的地面上，不穿墙画到隔壁。
	var wr:Array=cfg.walk_rect;light_rect=Rect2(wr[0],wr[1],wr[2],wr[3]).grow(10)
	ambient = CanvasModulate.new();add_child(ambient)
	if shared_light_texture==null:
		var im := Image.create(128,128,false,Image.FORMAT_RGBA8)
		for y in 128:
			for x in 128:
				var a := pow(maxf(0,1-Vector2(x-64,y-64).length()/64),1.7)
				im.set_pixel(x,y,Color(a,a,a,1))
		shared_light_texture=ImageTexture.create_from_image(im)
	var tex:Texture2D=shared_light_texture
	for l in cfg.lamps:
		var lamp := PointLight2D.new();lamp.texture = tex;lamp.texture_scale = float(l[2])/64;lamp.position = Vector2(l[0],l[1]);lamp.color = Color("ffd49b");lamp.blend_mode = Light2D.BLEND_MODE_ADD;add_child(lamp);lights.append(lamp)
	atmosphere = Node2D.new();atmosphere.z_index = 100;atmosphere.draw.connect(_air_draw);atmosphere.draw.connect(_life_draw);add_child(atmosphere)
	grid.region = Rect2i(0,0,int(cfg.size[0])/CELL,int(cfg.size[1])/CELL)
	grid.cell_size = Vector2(CELL,CELL);grid.offset = Vector2(CELL/2,CELL/2);grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES;grid.update()
	var nav_file:String=Assets.resolved_paths.get(ROOMS+area+".nav",ROOMS+area+".nav")
	var mask:=FileAccess.get_file_as_bytes(nav_file) if use_baked_navigation and FileAccess.file_exists(nav_file) else PackedByteArray()
	var baked:bool=mask.size()==grid.region.size.x*grid.region.size.y
	for y in grid.region.size.y:
		for x in grid.region.size.x:grid.set_point_solid(Vector2i(x,y),bool(mask[y*grid.region.size.x+x]) if baked else not walkable(Vector2(x*CELL+CELL/2,y*CELL+CELL/2)))
	seal_islands()
	add_table_top();add_tap_water()
	update_light()

## 桌面上的东西（餐桌上的菜、麻将桌上的牌）跟着桌子排前后，不再画在所有人上面（第六轮第 20 条：妈妈走到餐桌边头被菜碗盖住）
## 第 28 条（第六轮 15 没修全）：水龙头的水原来画在最上面那层（atmosphere），人站在龙头正前面时水线压在人头和身上。
## 现在每个水龙头一层，跟人一起排前后：排在水池那件家具（或水池）脚下再往前一点，人站在龙头前面时人在水前面、挡住水
var tap_layers:Array=[]
func add_tap_water() -> void:
	tap_layers.clear()
	for h in cfg.get("hotspots",[]):
		if h.get("kind","")!="tap":continue
		var spout:=v(h.get("spout",h.pos));var basin:=v(h.get("basin",[spout.x,spout.y+12]))
		var y:=basin.y+0.1
		for p in props:
			var tex:Texture2D=p.sprite.texture
			if tex and Rect2(v(p.config.pos),tex.get_size()).has_point(spout) and float(p.config.foot)<spout.y+60:y=maxf(y,float(p.config.foot)+0.1)
		var n:=Node2D.new();n.position=Vector2(0,y);n.set_meta("tap",h.id);n.draw.connect(_tap_draw.bind(n));actors.add_child(n);tap_layers.append(n)
func _tap_draw(n:Node2D) -> void:
	var id:String=str(n.get_meta("tap"))
	if not effects_enabled or not toggles.get(id,false):return
	var h:=spot(id);n.draw_set_transform(Vector2(0,-n.position.y))
	# 水从水龙头嘴流下来、落进水池；所有水龙头一样，简单克制
	var spout:=v(h.get("spout",h.pos));var basin:=v(h.get("basin",[spout.x,spout.y+12]))
	var len:=maxf(2.0,basin.y-spout.y)
	n.draw_rect(Rect2((spout+Vector2(-1,0)).round(),Vector2(2,len).round()),Color(.72,.88,.92,.85))
	for i in 2:
		var y:=fmod(elapsed*40+i*len*.5,len)
		n.draw_rect(Rect2((spout+Vector2(-1,y)).round(),Vector2(2,3)),Color(.93,.98,1,.95))
	for i in 3:
		var t:=fmod(elapsed*2+i*.33,1.0)
		n.draw_rect(Rect2((basin+Vector2(-4+i*3,-1+t*2)).round(),Vector2(2,1)),Color(.88,.97,1,1-t))
func add_table_top() -> void:
	table_top=null
	var key:String={"dining":"dining-table.png","mahjong":"mahjong-table.png"}.get(area,"")
	if key.is_empty():return
	for p in props:
		if str(p.config.file).ends_with(key):
			table_top=Node2D.new();table_top.position=Vector2(0,float(p.config.foot));table_top.draw.connect(_table_draw);actors.add_child(table_top)
func _table_draw() -> void:
	if not effects_enabled or table_top==null:return
	table_top.draw_set_transform(Vector2(0,-table_top.position.y))
	if area=="dining" and life:
		var center:=v(cfg.get("meal_center",[159,232]))
		var menu:Array=life.meal_menu(month)
		for i in menu.size():Art.dish(table_top,str(menu[i]),center+Vector2(cos(i*TAU/3)*45,sin(i*TAU/3)*32))
	elif area=="mahjong":mahjong_walls()
## 第六轮第 16 条（阿鱼）：麻将桌上摆一副牌，背面朝上码成四面牌墙（两层），只是摆设、不能操作、不画牌面
func mahjong_walls() -> void:
	var back:=Color("e2a95a");var lite:=Color("f3cd86");var side:=Color("a8682e");var line:=Color("6b3c18")
	var c:=Vector2(173,165)
	var tile:=func(at:Vector2,sz:Vector2) -> void:
		table_top.draw_rect(Rect2(at+Vector2(0,1),sz),line)
		table_top.draw_rect(Rect2(at,sz),side)
		table_top.draw_rect(Rect2(at,sz-Vector2(0,1)),back)
		table_top.draw_rect(Rect2(at,Vector2(sz.x-1,1)),lite)
	for i in 8:
		tile.call(c+Vector2(-24+i*6,-27),Vector2(6,5));tile.call(c+Vector2(-24+i*6,-29),Vector2(6,5))
		tile.call(c+Vector2(-24+i*6,21),Vector2(6,5));tile.call(c+Vector2(-24+i*6,19),Vector2(6,5))
	for i in 6:
		tile.call(c+Vector2(-33,-18+i*6),Vector2(5,6));tile.call(c+Vector2(-33,-20+i*6),Vector2(5,6))
		tile.call(c+Vector2(28,-18+i*6),Vector2(5,6));tile.call(c+Vector2(28,-20+i*6),Vector2(5,6))
## 走不到的小块（家具缝里、床后面那种跟大片空地不连着的格子）当成不能走：
## 点到那里就说「这里过不去」，不会点了以后人站着不动（体验师：二楼浴室点书房、衣柜点卧室停在几百像素外）
func seal_islands() -> void:
	if not use_baked_navigation:return
	var size:=grid.region.size;var seen:=PackedByteArray();seen.resize(size.x*size.y)
	var stack:Array[Vector2i]=[]
	var seeds:Array=[v(cfg.spawn)]
	for d in cfg.doors+cfg.hotspots:seeds.append(v(d.approach))
	for sp in seeds:
		var c:=Vector2i(nearest(sp)/CELL)
		if grid.is_in_boundsv(c) and not grid.is_point_solid(c) and seen[c.y*size.x+c.x]==0:seen[c.y*size.x+c.x]=1;stack.append(c)
	while not stack.is_empty():
		var c:Vector2i=stack.pop_back()
		for dlt in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			var q:Vector2i=c+dlt
			if q.x<0 or q.y<0 or q.x>=size.x or q.y>=size.y:continue
			var i:=q.y*size.x+q.x
			if seen[i]==0 and not grid.is_point_solid(q):seen[i]=1;stack.append(q)
	for y in size.y:
		for x in size.x:
			if seen[y*size.x+x]==0 and not grid.is_point_solid(Vector2i(x,y)):grid.set_point_solid(Vector2i(x,y),true)
	nearest_cache.clear()
static func v(a: Array) -> Vector2:return Vector2(a[0],a[1])
func walkable(at: Vector2) -> bool:
	var r: Array = cfg.walk_rect
	if not Rect2(r[0],r[1],r[2],r[3]).has_point(at):return false
	if not cfg.get("walk_polygons",[]).is_empty():
		var inside:=false
		for polygon in cfg.walk_polygons:
			var pts:=PackedVector2Array()
			for p in polygon:pts.append(v(p))
			if Geometry2D.is_point_in_polygon(at,pts):inside=true
		if not inside:return false
	for b in obstacles:
		if b.grow(3).has_point(at): return false
	return true
## 方向键走路也按烘好的导航格判断，和点地面走一样，不会多走进家具边的小块。
func passable(at: Vector2) -> bool:
	var cell:=Vector2i(at/CELL)
	return walkable(at) and grid.is_in_boundsv(cell) and not grid.is_point_solid(cell)
func nearest(at: Vector2) -> Vector2:
	if nearest_cache.has(at):return nearest_cache[at]
	var cell:=Vector2i(at/CELL)
	if grid.is_in_boundsv(cell) and not grid.is_point_solid(cell):return grid.get_point_position(cell)
	var best := Vector2.ZERO;var distance := INF
	for y in grid.region.size.y:
		for x in grid.region.size.x:
			var c := Vector2i(x,y)
			if grid.is_point_solid(c):continue
			var pos := grid.get_point_position(c);var d := pos.distance_squared_to(at)
			if d<distance:distance=d;best=pos
	nearest_cache[at]=best
	return best
func path(start: Vector2,finish: Vector2) -> PackedVector2Array:
	return grid.get_point_path(Vector2i(nearest(start)/CELL),Vector2i(nearest(finish)/CELL))
func spawn() -> Vector2:return nearest(v(cfg.spawn))
func spot(id: String) -> Dictionary:
	for h in cfg.hotspots+cfg.get("doors",[]):
		if h.id == id:return h
	return {}
func _process(dt: float) -> void:
	elapsed += dt
	if not ground:return
	update_light();ground.queue_redraw();atmosphere.queue_redraw()
	if table_top:table_top.queue_redraw()
	for n in tap_layers:n.queue_redraw()
	if area=="garden":
		base_sprite.texture=art(P+["garden_spring.png","garden_summer.png","garden.png","garden_winter.png"][preload("res://ayu_home/home_data.gd").season(month)])
	for view in windows:view.sync(camera_center.x-parallax_origin.x if effects_enabled else 0)
	for p in props:
		if p.config.get("front",false):p.sprite.position = p.origin-((camera_center-parallax_origin)*.012).clamp(Vector2(-1,-1),Vector2(1,1)) if effects_enabled else p.origin
		if p.config.has("off_file"):p.sprite.texture=art(P+(p.config.file if tv_on else p.config.off_file))
func make_season_material() -> ShaderMaterial:
	if season_shader==null:
		season_shader=Shader.new()
		season_shader.code="shader_type canvas_item;uniform int season=2;uniform float rain=0.0;uniform int plant_kind=0;void fragment(){vec4 c=texture(TEXTURE,UV);vec3 col=c.rgb;float green=clamp((col.g-max(col.r,col.b))*5.0,0.0,1.0);float lum=dot(col,vec3(.3,.59,.11));if(season==3){vec3 snow=vec3(.86,.9,.96)*(.72+lum*.55);col=mix(col,snow,green*.8);col*=vec3(.94,.97,1.04);}else if(season==2){float k=plant_kind==2?.04:(plant_kind==1?.88:(plant_kind==3?.68:.52));col=mix(col,vec3(col.g*1.22,col.g*.70,col.b*.46),green*k);}else if(season==0){col=mix(col,vec3(col.r*.9+.13,col.g*.88+.17,col.b*.85+.07),green*.82);}if(rain>0.0){col*=mix(vec3(1.0),vec3(.8,.86,.95),rain);}COLOR=vec4(col,c.a);}"
	var m:=ShaderMaterial.new();m.shader=season_shader;return m
func get_village_spring_bindings() -> Dictionary:
	if village_spring_bindings.is_empty():
		var parsed=JSON.parse_string(FileAccess.get_file_as_string(SPRING_BINDINGS))
		if parsed is Dictionary:village_spring_bindings=parsed
	return village_spring_bindings
func make_village_season_material(source:String,plant_kind:int,layer_kind:int,mask_allowed:=true) -> ShaderMaterial:
	var key:=source+"|"+str(plant_kind)+"|"+str(layer_kind)+"|"+str(mask_allowed)
	if village_material_cache.has(key):return village_material_cache[key]
	var binding:Dictionary=get_village_spring_bindings().get("textures",{}).get(source,{})
	var mask:Texture2D
	if mask_allowed and not nav_only:
		var path:String=str(binding.get("mask",""))
		if not path.is_empty() and (FileAccess.file_exists(path) or ResourceLoader.exists(path)):mask=art(path)
	if mask==null:
		if black_spring_mask==null:
			var im:=Image.create(1,1,false,Image.FORMAT_RGB8);im.fill(Color.BLACK)
			black_spring_mask=ImageTexture.create_from_image(im)
		mask=black_spring_mask
	var m:=ShaderMaterial.new();m.shader=SPRING_SHADER
	m.set_shader_parameter("spring_plant_mask",mask)
	m.set_shader_parameter("spring_mask_enabled",true)
	m.set_shader_parameter("spring_layer_kind",layer_kind)
	m.set_shader_parameter("plant_kind",plant_kind)
	village_material_cache[key]=m
	return m
func update_light() -> void:
	if not ambient:return
	for pm in plant_materials:
		pm.set_shader_parameter("season",preload("res://ayu_home/home_data.gd").season(month) if effects_enabled else 1)
		pm.set_shader_parameter("rain",1.0 if weather=="rain" and effects_enabled else 0.0)
	if season_material:
		season_material.set_shader_parameter("season",preload("res://ayu_home/home_data.gd").season(month) if effects_enabled else 1)
		season_material.set_shader_parameter("rain",1.0 if weather=="rain" and effects_enabled else 0.0)
	if not effects_enabled:
		ambient.color=Color.WHITE
		for light in lights:light.enabled=false
		return
	var night := hour<6 or hour>=22
	var evening := hour>=18 and hour<22
	ambient.color = Color("424c70") if night else (Color("ac846d") if evening else (Color("f5d9b6") if hour<10 else Color.WHITE))
	if weather=="rain" and not night:ambient.color *= Color(.78,.85,.91)
	elif weather=="cloud" and not night:ambient.color *= Color(.88,.9,.9)
	elif weather=="snow" and not night:ambient.color *= Color(.9,.94,1.0)
	# 屋里的光也跟着季节：春天微粉、夏天亮而暖、秋天偏琥珀、冬天偏冷（只在白天）
	if not night and not cfg.get("outdoor",false):ambient.color*=[Color(1,.97,.97),Color(1,1,.93),Color(1,.94,.85),Color(.9,.94,1.0)][preload("res://ayu_home/home_data.gd").season(month)]
	if local_lighting:modulate=ambient.color;ambient.color=Color.WHITE
	for i in lights.size():
		lights[i].enabled = lamp_on
		lights[i].energy = (1.5 if i==0 else 0.0) if night else (1.1 if evening else .32)
func sun_vector() -> Vector2:
	return Vector2(lerpf(45,-40,clampf((hour-6)/12,0,1)),(-23 if area=="living" else 23) if hour<18 else 13)
func shadow_vector(at:Vector2) -> Vector2:
	if not cfg.get("outdoor",false) and (hour<6 or hour>=18) and not lights.is_empty():return (at-lights[0].position).normalized()*26
	return sun_vector()
func _ground_draw() -> void:
	if not effects_enabled:return
	for b in obstacles:
		soft_shadow(b.get_center(),minf(b.size.x*.43,56),.07)
	for a in actors.get_children():
		if a is Actor and a.visible and a.action not in ["sit","lie","eat","tv","read"]:
			soft_shadow(a.position,10 if a.pet else 12,.13)
	if hour>=6 and hour<18 and weather!="rain":
		for w in cfg.windows:
			var x := float(w[0]);var y := float(w[1])+float(w[3]);var width := float(w[2]);var shift := sun_vector().x*3
			var reach:float=-280 if w[1]>float(cfg.size[1])*.5 else 280
			for n in 3:
				var p := Vector2(x+width*(n+.1)/3,y)
				var ray:=PackedVector2Array([p,p+Vector2(width*.23,0),p+Vector2(width*.23+shift,reach),p+Vector2(shift,reach)])
				var clip:=PackedVector2Array([light_rect.position,Vector2(light_rect.end.x,light_rect.position.y),light_rect.end,Vector2(light_rect.position.x,light_rect.end.y)])
				for piece in Geometry2D.intersect_polygons(ray,clip):ground.draw_colored_polygon(piece,Color(1,.85,.51,.19 if hour<10 else .13))
func soft_shadow(at:Vector2,width:float,opacity:float) -> void:
	var sv:=shadow_vector(at)*.60
	for layer in range(4):
		var spread:=1+float(3-layer)*.09
		var pts:=PackedVector2Array()
		for i in 24:
			var angle:=TAU*i/24.0
			pts.append(at+sv*.3+Vector2(cos(angle)*width*spread+sin(angle)*sv.x*.35,sin(angle)*(5+absf(sv.y)*.25)*spread))
		ground.draw_colored_polygon(pts,Color(.08,.09,.15,opacity*.25))
func weather_view() -> Rect2:
	# 实际视口经画布逆变换落回世界；窗口缩放、横屏和镜头缩放共用同一范围。
	var screen:=get_viewport_rect();var inverse:=get_global_transform_with_canvas().affine_inverse()
	var bounds:=Rect2(inverse*screen.position,Vector2.ZERO)
	for corner in [Vector2(screen.end.x,screen.position.y),screen.end,Vector2(screen.position.x,screen.end.y)]:bounds=bounds.expand(inverse*corner)
	return bounds.grow(20.0)
func weather_count(base_count:int,base_area:=156000.0) -> int:
	return clampi(roundi(base_count*weather_view().get_area()/base_area),1,1600)
func _air_draw() -> void:
	if not effects_enabled:return
	if area=="living":
		var r:Array=cfg.fish_rect
		for i in 9:
			var p:=Vector2(r[0]+4+fposmod(i*7,r[2]-8),r[1]+r[3]-fposmod(elapsed*8+i*7,r[3]-3))
			atmosphere.draw_arc(p,1,0,TAU,8,Color(.8,1,1,.55),1)
		if food_until>elapsed:
			for i in 8:atmosphere.draw_rect(Rect2(r[0]+7+i*6,r[1]+fposmod(elapsed*8+i*4,r[3]),1,2),Color("c89554"))
		var tv:Array=cfg.tv_rect
		atmosphere.draw_rect(Rect2(tv[0],tv[1],tv[2],tv[3]),Color(.45,.7,.85,.10+.06*sin(elapsed*2)) if tv_on else Color(.03,.035,.04,.83))
	elif area=="dining":
		for i in 7:
			var p:=v(cfg.steam)+Vector2(sin(elapsed+i)*4,-fposmod(elapsed*12+i*6,36))
			atmosphere.draw_arc(p,3,PI*.1,PI*.8,8,Color(.95,.9,.75,.26),1)
	if not cfg.get("outdoor",false):
		for w in cfg.windows:
			var rect := Rect2(w[0],w[1],w[2],w[3])
			# 窗外的季节色：春粉、夏绿、秋橙、冬白，雨天发灰
			if hour>=6 and hour<19:atmosphere.draw_rect(rect,Color(.7,.75,.8,.22) if weather=="rain" else [Color(1,.8,.85,.2),Color(.7,.9,.55,.2),Color(.95,.65,.3,.22),Color(.95,.97,1,.35)][preload("res://ayu_home/home_data.gd").season(month)])
			for i in 16:
				var x := rect.position.x+fposmod(i*29+elapsed*8-camera_center.x*.08,rect.size.x)
				var y := rect.position.y+fposmod(i*13+elapsed*15,rect.size.y)
				if weather=="rain":atmosphere.draw_line(Vector2(x,y),Vector2(x-2,minf(rect.end.y,y+7)),Color(.65,.82,.9,.65),1)
				else:atmosphere.draw_rect(Rect2(x,y,2,2),season_particle())
			if hour>=6 and hour<18 and weather!="rain":
				for i in 12:
					var p := Vector2(rect.position.x+fposmod(i*19+elapsed*2,rect.size.x),rect.end.y+fposmod(i*15-elapsed*3,250)*(-1 if rect.position.y>float(cfg.size[1])*.5 else 1))
					if light_rect.has_point(p):atmosphere.draw_rect(Rect2(p,Vector2.ONE),Color(1,.9,.64,.5))
	else:
		var full_view:=weather_view()
		for i in weather_count(100 if weather in ["rain","snow"] else 32,1560000.0):
			var p := full_view.position+Vector2(fposmod(i*79+elapsed*(30 if weather=="rain" else 8),full_view.size.x),fposmod(i*137+elapsed*(160 if weather=="rain" else 20),full_view.size.y))
			if weather=="rain":atmosphere.draw_line(p,p+Vector2(-3,10),Color(.7,.85,.9,.4),1)
			else:atmosphere.draw_rect(Rect2(p,Vector2(3,3) if weather=="snow" else Vector2(2,2)),Color(.94,.97,1,.7) if weather=="snow" else season_particle())
	# Every reaction changes the scene at the object, even in daylight.
	for id in toggles:
		var h:=spot(id)
		if h.is_empty():continue
		var p:=v(h.pos)
		if h.get("effect","")=="lamp":
			if toggles[id]:
				for r in [24,18,11]:atmosphere.draw_circle(p,r,Color(1,.82,.34,.11))
			else:atmosphere.draw_rect(Rect2(p-Vector2(10,8),Vector2(20,15)),Color(.21,.18,.17,.62))
		elif toggles[id] and h.get("kind","") not in ["tap","shower"]:
			atmosphere.draw_rect(Rect2(p-Vector2(14,22),Vector2(28,45)),Color("fff4cd"))
			for j in 3:
				atmosphere.draw_line(p+Vector2(-12,-7+j*12),p+Vector2(12,-7+j*12),Color("bba78a"),2)
				atmosphere.draw_rect(Rect2(p+Vector2(-9,-17+j*12),Vector2(8,8)),[Color("adc87f"),Color("db9d69"),Color("aad2cc")][j])
	for id in reactions:
		var entry:Dictionary=reactions[id];var age:=elapsed-float(entry.at)
		if age>6:continue
		var p:Vector2=v(entry.pos);var fx:String=entry.effect
		for i in 12:
			var q:=p+Vector2(sin(i*1.9+age)*18,-fposmod(age*18+i*5,45))
			var color:=Color("a1e9ed") if fx in ["water","wash"] else (Color("fff1bf") if fx in ["steam","lamp"] else Color("efb88e"))
			color.a=clampf(1-age/6,0,1)*.8
			atmosphere.draw_rect(Rect2(q.round(),Vector2(3,3)),color)
		if fx=="wash":atmosphere.draw_arc(p,14,age*4,age*4+PI*1.6,16,Color("b2ecf1"),3)
		elif fx=="fold":
			for j in 3:atmosphere.draw_rect(Rect2(p+Vector2(-12+j,-j*4),Vector2(24,5)),Color("f5debf").darkened(j*.06))
		elif fx=="tools":
			for j in 4:
				var q:=p+Vector2(-15+j*9,-10-minf(age,1)*10)
				atmosphere.draw_line(q,q+Vector2(0,20),Color("d8b076"),3);atmosphere.draw_rect(Rect2(q+Vector2(-3,-2),Vector2(7,4)),Color("829494"))
		elif fx=="book":
			atmosphere.draw_rect(Rect2(p+Vector2(-25,-18),Vector2(50,36)),Color("fff2d4"));atmosphere.draw_line(p+Vector2(0,-18),p+Vector2(0,18),Color("aa7950"),2)
			for j in 4:atmosphere.draw_line(p+Vector2(5,-10+j*6),p+Vector2(20,-10+j*6),Color("bcaa87"),1)
		elif fx=="mirror":atmosphere.draw_line(p+Vector2(-9,-15+age*5),p+Vector2(12,-5+age*5),Color("fff4df"),3)
		elif fx=="bell":
			for j in 3:atmosphere.draw_arc(p,10+j*6+fmod(age*10,7),-PI*.6,PI*.1,12,Color(1,.91,.65,1-age/6),2)
		elif fx=="bunny":atmosphere.draw_string(preload("res://ayu_home/v4/pixel_ui.gd").FONT,p+Vector2(5,-25-age*2),"♥",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("e2a1a8"))
		elif fx=="water":
			atmosphere.draw_line(p,p+Vector2(3,23),Color(.75,.94,1,.65),2)
			atmosphere.draw_arc(p+Vector2(0,8),10+age*3,0,TAU,16,Color(.7,.93,.95,.5),2)

func season_particle() -> Color:
	if month in [3,4,5]:return Color(1,.85,.87,.55)
	if month in [6,7,8]:return Color(1,.94,.58,.20)
	if month in [9,10,11]:return Color(.72,.47,.19,.5)
	return Color(.9,.95,1,.65)

func sharpen_material() -> ShaderMaterial:
	if sharp_material:return sharp_material
	var shader:=Shader.new()
	shader.code="shader_type canvas_item; uniform sampler2D approved_clarity:filter_nearest;uniform vec2 source_origin=vec2(0.0);uniform float amount=0.0;void fragment(){vec4 original=texture(TEXTURE,UV);vec2 p=vec2(1.0/1448.0,1.0/1086.0);vec2 g=(source_origin+UV/TEXTURE_PIXEL_SIZE)*p;vec3 c=texture(approved_clarity,g).rgb;vec3 n=(texture(approved_clarity,g+vec2(p.x*2.0,0.0)).rgb+texture(approved_clarity,g-vec2(p.x*2.0,0.0)).rgb+texture(approved_clarity,g+vec2(0.0,p.y*2.0)).rgb+texture(approved_clarity,g-vec2(0.0,p.y*2.0)).rgb)*0.25;COLOR=vec4(clamp(c+clamp((c-n)*amount,vec3(-12.0/255.0),vec3(12.0/255.0)),vec3(0.0),vec3(1.0)),original.a);}"
	sharp_material=ShaderMaterial.new();sharp_material.shader=shader;sharp_material.set_shader_parameter("amount",0.85 if sharp else 0.0);sharp_material.set_shader_parameter("approved_clarity",art("res://ayu_home/v4/assets/floor1-redraw/floor1.png"));return sharp_material

func react(h:Dictionary) -> void:
	reactions[h.id]={"effect":h.get("effect","spark"),"pos":h.pos,"at":elapsed}
	if h.get("effect","")=="lamp":
		lamp_on=not lamp_on;toggles[h.id]=lamp_on
	elif h.get("effect","")=="open":toggles[h.id]=not toggles.get(h.id,false)
func view_bounds() -> Rect2:
	return Rect2(Vector2.ZERO,v(cfg.size))

func asset_path(file:String) -> String:return file if file.begins_with("res://") else str(cfg.get("asset_root",P))+file
## 门槛跟画上的门洞一样宽（阿鱼 10/5「看到大门出不去」：原来每扇门只有正中约 42 像素算数）。
## 从站位往门外走到这间房的边上，沿着边看有多宽一段是「里面能站、再往外就出了这间」——那就是门洞；
## 门槛线还在原来的站位那条线上，只是左右放宽到门洞那么宽、居中对着门洞。
## 门在院子当中、门外也是空地的（院子进家门、进手作房），数据里用 span 写明门有多宽。
func door_plane(d:Dictionary) -> Dictionary:
	var key:String=str(d.get("id",""))
	if plane_cache.has(key):return plane_cache[key]
	var inward:Vector2={"up":Vector2.UP,"down":Vector2.DOWN,"left":Vector2.LEFT,"right":Vector2.RIGHT}.get(d.get("face","down"),Vector2.DOWN)
	var n:=-inward;var t:=Vector2(-n.y,n.x);var p:=nearest(v(d.approach));var width:=maxf(42.0,float(d.get("width",22)))
	if str(d.get("id","")) in ["to_stairs1","to_stairs2"]:pass # 楼梯口不放宽：上下楼是一级级走的楼梯路线
	elif d.has("span"):
		var sp:Array=d.span;width=float(sp.back()) # [宽] 就用站位那点；[x,y,宽] 是写明的门槛中点
		if sp.size()>=3:p=Vector2(sp[0],sp[1])
	elif not cfg.get("outdoor",false): # 屋外是大片空地，门洞不自己往两边找（会找出一大片），要宽的写 span
		var e:=p
		for k in 24:
			if not open_cell(e+n*2):break
			e+=n*2
		var lo:=0.0;var hi:=0.0
		for side in [-1,1]:
			var k:=2.0
			while k<130:
				var q:Vector2=e+t*k*side
				if not open_cell(q) or not leads_out(d,q+n*10) or near_other_door(d,q):break
				k+=2
			if side<0:lo=-(k-2)
			else:hi=k-2
		if hi-lo+4>width:width=minf(hi-lo+4,240);p=p+t*((lo+hi)*.5)
	var plane:={"point":p,"normal":n,"width":width}
	plane_cache[key]=plane;return plane
## 门洞放宽时，离别的门比离这扇门还近就停（二楼过道几扇门挨着）
func near_other_door(d:Dictionary,q:Vector2) -> bool:
	var own:float=q.distance_to(v(d.approach))
	for od in cfg.doors:
		if od.id!=d.id and q.distance_to(v(od.approach))<own+4:return true
	return false
## 门外这一点真的通到门那边：同一张画上的隔壁房间，要落在那间能走的地方；不是同一张画的（出门到院子），要已经出了这间
static var room_cfgs:Dictionary={}
func leads_out(d:Dictionary,at:Vector2) -> bool:
	if open_cell(at):return false
	var target:String=str(d.target)
	if not room_cfgs.has(target):room_cfgs[target]=JSON.parse_string(FileAccess.get_file_as_string(ROOMS+target+".json"))
	var other:Dictionary=room_cfgs[target]
	var same:bool=(int(cfg.get("floor",0))==int(other.get("floor",0)) and int(cfg.get("floor",0)) in [1,2])
	if not same:return true
	var floor_pt:=at+v(cfg.source_crop)-v(cfg.source_offset);var q:=floor_pt-v(other.source_crop)+v(other.source_offset)
	return walkable_in(other,q)
static func walkable_in(c:Dictionary,at:Vector2) -> bool:
	var r:Array=c.walk_rect
	if not Rect2(r[0],r[1],r[2],r[3]).has_point(at):return false
	if not c.get("walk_polygons",[]).is_empty():
		var inside:=false
		for polygon in c.walk_polygons:
			var pts:=PackedVector2Array()
			for p in polygon:pts.append(v(p))
			if Geometry2D.is_point_in_polygon(at,pts):inside=true
		if not inside:return false
	for b in c.obstacles:
		if Rect2(b[0],b[1],b[2],b[3]).grow(3).has_point(at):return false
	return true
func open_cell(at:Vector2) -> bool:
	var cell:=Vector2i(at/CELL)
	return grid.is_in_boundsv(cell) and not grid.is_point_solid(cell)
func crossed_door(d:Dictionary,previous:Vector2,current:Vector2) -> bool:
	if previous.distance_to(current)<.01:return false
	var plane:=door_plane(d);var n:Vector2=plane.normal;var p:Vector2=plane.point
	var a:float=(previous-p).dot(n);var b:float=(current-p).dot(n)
	var tangent:=Vector2(-n.y,n.x)
	return (current-previous).dot(n)>0 and a<-.2 and b>=-2.5 and a<b and absf((current-p).dot(tangent))<plane.width*.5

func pixel(r:Rect2,color:Color) -> void:atmosphere.draw_rect(Rect2(r.position.round(),r.size.round()),color)
func plate(at:Vector2,color:Color,variant:int) -> void:
	for y in range(-8,9,2):
		for x in range(-16,17,2):
			var radius:=pow(float(x)/16,2)+pow(float(y)/8,2)
			if radius<=1:pixel(Rect2(at+Vector2(x,y),Vector2(2,2)),Color("c9bf9e") if radius>.72 else Color("f8eed3"))
	for j in 5:
		var p:=at+Vector2(-9+(j*7+variant*3)%19,-4+(j*5)%8)
		pixel(Rect2(p,Vector2(6,4)),color);pixel(Rect2(p+Vector2(1,0),Vector2(2,2)),color.lightened(.2))
func _life_draw() -> void:
	if not effects_enabled:return
	# Every water fixture shares a persistent on/off stream. No generic "open box" over a tap.
	for id in toggles:
		var h:=spot(id)
		if h.is_empty() or not toggles[id]:continue
		if h.get("kind","")=="tap":continue # 水龙头的水画在跟人一起排前后的那层（_tap_draw）
		if h.get("kind","") in ["tap","shower"]:
			var p:=v(h.pos)
			for i in (9 if h.kind=="shower" else 3):
				var dx:=float(i*3-12 if h.kind=="shower" else i-1)
				var y:=fmod(elapsed*95+i*11,30)
				pixel(Rect2(p+Vector2(dx,y),Vector2(2,11)),Color("b9e4e4"))
			for i in 4:
				pixel(Rect2(p+Vector2(sin(elapsed*2+i)*13,34+cos(elapsed*3+i)*3),Vector2(4,2)),Color("d5f0e5"))
	if not life:return
	var saved:Dictionary=life.data.effects
	if area=="kitchen" and saved.get("soup",false):
		var p:=v(spot("stove").pos);Art.sprite(atmosphere,"household-2",Rect2(p-Vector2(24,24),Vector2(48,40)))
		for i in 4:pixel(Rect2(p+Vector2(-9+i*6,-9-fmod(elapsed*12+i*9,27)),Vector2(3,7)),Color("fff1d3"))
	if area=="laundry" and saved.get("laundry",false):
		var p:=v(spot("drying").pos)
		pixel(Rect2(p+Vector2(-36,-34),Vector2(74,2)),Color("98744d"))
		for i in 3:Art.sprite(atmosphere,"household-"+str(7+i),Rect2(p+Vector2(-34+i*24,-31),Vector2(22,26)))
	if area=="workshop" and saved.get("wood",false):
		Art.sprite(atmosphere,"household-5",Rect2(v(spot("wood").pos)+Vector2(9,-35),Vector2(36,32)))
	if area=="mahjong" and saved.get("tea",false):
		for i in 3:Art.sprite(atmosphere,"household-1",Rect2(v(spot("tea").pos)+Vector2(-24+i*18,-8),Vector2(18,16)))
	if area in ["dining","living"] and not life.data.flower_vase.is_empty():
		var p:=v(cfg.get("vase_position",[151,152] if area=="dining" else [253,272]))
		for i in life.data.flower_vase.size():
			var q:=p+Vector2(-7+i*11,-17-(i%2)*12)
			atmosphere.draw_line(p+Vector2(8,12),q,Color("78935c"),2)
			Art.sprite(atmosphere,"botanical-"+str(i%3),Rect2(q-Vector2(9,9),Vector2(18,18)))
		Art.sprite(atmosphere,"botanical-3",Rect2(p-Vector2(2,0),Vector2(21,27)))
	if area=="cats" and saved.get("pet_food",false):
		var p:=v(spot("bowls").pos);plate(p,Color("a27346"),1);plate(p+Vector2(26,0),Color("93bcca"),2)
	for h in cfg.hotspots:
		if not saved.get(area+":"+h.id,false):continue
		var p:=v(h.pos);var kind:String=h.get("kind","")
		if kind=="fold" or (kind=="tidy" and h.get("effect","")=="fold"):
			for j in 3:pixel(Rect2(p+Vector2(-12,-j*4),Vector2(25,5)),[Color("d4a29a"),Color("cbd7ad"),Color("e5d1a7")][j])
		elif kind=="wipe":
			pixel(Rect2(p+Vector2(-7,-10),Vector2(3,21)),Color("d2e4d7"));pixel(Rect2(p+Vector2(-16,-2),Vector2(21,3)),Color("d2e4d7"))
		elif kind=="tend":pixel(Rect2(p+Vector2(-3,13),Vector2(9,4)),Color("746644"))
	if area=="living" and tv_on:
		var r:Array=cfg.tv_rect;var rect:=Rect2(r[0],r[1],r[2],r[3]);var color:Color=[Color("71979b"),Color("b89f7a"),Color("697c99")][tv_channel]
		pixel(rect,color)
		for i in 4:
			var p:=rect.position+Vector2(fmod(elapsed*8+i*17,rect.size.x-3),fmod(i*11,rect.size.y-3));pixel(Rect2(p,Vector2(3,3)),Color("dfdab4"))
	# 原图上没有门的地方不再用代码画木框和字（体验师 10/5：厨房「后门」、后园「树林 / 厨房 / 院子」）。
	# 屋外各块之间的出口：路的尽头地上有三道慢慢往外走的小箭头，一眼看得出往哪走能到下一块（没有字）。
	if cfg.get("outdoor",false):
		for d in cfg.doors:
			if str(d.target) in ["exterior","side_path","bridge","oldhouse","garden","grove"]:exit_arrows(d)
	if cfg.get("outdoor",false):
		# 雪、花瓣、雨都只画在镜头看得到的地方，密一点，一眼看得出季节和天气
		var view:=weather_view()
		var winter:=month in [12,1,2] or weather=="snow"
		if winter:
			for i in weather_count(90):
				var p:=view.position+Vector2(fposmod(i*37.0+sin(elapsed*.7+i)*14+elapsed*6,view.size.x),fposmod(i*53.0+elapsed*(22+i%5*5),view.size.y))
				pixel(Rect2(p,Vector2(3,3) if i%3 else Vector2(2,2)),Color(.97,.98,1,.9))
		elif month in [3,4,5]:
			for i in weather_count(30):pixel(Rect2(view.position+Vector2(fposmod(i*47.0+elapsed*12,view.size.x),fposmod(i*61.0+elapsed*16,view.size.y)),Vector2(4,3)),Color("efb9b1"))
		elif month in [9,10,11]:
			for i in weather_count(22):pixel(Rect2(view.position+Vector2(fposmod(i*59.0+sin(elapsed+i)*20+elapsed*10,view.size.x),fposmod(i*71.0+elapsed*18,view.size.y)),Vector2(4,3)),[Color("d58a3a"),Color("c5652e"),Color("e2b04a")][i%3])
		if weather=="rain":
			for i in weather_count(110):
				var p:=view.position+Vector2(fposmod(i*29.0-elapsed*60,view.size.x),fposmod(i*47.0+elapsed*420,view.size.y))
				atmosphere.draw_line(p,p+Vector2(-4,14),Color(.78,.88,.96,.55),1)
			for i in weather_count(26):
				var p:=view.position+Vector2(fposmod(i*83.0,view.size.x),fposmod(i*131.0,view.size.y));var age:=fposmod(elapsed*1.6+i*.37,1.0)
				if walkable(p):atmosphere.draw_arc(p,2+age*7,0,TAU,10,Color(.82,.9,.95,(1-age)*.7),1)
			for i in 15:
				var p:=Vector2(130+fmod(i*147.0,1100),360+fmod(i*117.0,580))
				if walkable(p):pixel(Rect2(p,Vector2(31,6)),Color(.48,.67,.68,.6));atmosphere.draw_arc(p+Vector2(15,2),5+fmod(elapsed*8+i,14),0,TAU,12,Color(.73,.84,.82,.48),1)
		if area=="grove":
			for i in life.data.trees.size():
				var tree:Dictionary=life.data.trees[i]
				if tree.has("crop"):
					var p:=Vector2(420,660) if i==0 else Vector2(1030,653);var size:float=35+float(life.growth(tree))*100 if not tree.get("grown",false) else 135
					draw_young_tree(p,size,Color(preload("res://ayu_home/v4/life_state.gd").CROPS[tree.crop].color),life.growth(tree)>=.65)
			if month in [6,7,8] and (hour>=18 or hour<6):
				for i in 28:pixel(Rect2(430+fmod(i*83.0+sin(elapsed+i)*24,700),380+sin(elapsed*.6+i)*110,4,4),Color("f1eb9c"))
	if ball_visible:
		Art.sprite(atmosphere,"household-14",Rect2(ball_position-Vector2(12,23),Vector2(24,24)))
	if steam_player_until>elapsed:
		for a in actors.get_children():
			if a is Actor and a.id=="visitor":
				for i in 5:pixel(Rect2(a.position+Vector2(sin(elapsed+i)*13,-91-fmod(elapsed*12+i*6,26)),Vector2(4,8)),Color(.95,.94,.85,.7))

func exit_arrows(d:Dictionary) -> void:
	var out:Vector2=-{"up":Vector2.UP,"down":Vector2.DOWN,"left":Vector2.LEFT,"right":Vector2.RIGHT}.get(str(d.get("face","down")),Vector2.DOWN)
	var side:=Vector2(-out.y,out.x);var base:=nearest(v(d.approach))-out*34
	for i in 3:
		var t:=fposmod(elapsed*.8+i/3.0,1.0);var at:=base+out*(t*26);var alpha:=sin(t*PI)*.85
		for k in [-1,1]:
			for j in 4:
				var q:Vector2=(at+side*k*(j*2)-out*(j*2)).round()
				atmosphere.draw_rect(Rect2(q-Vector2(2,2),Vector2(4,4)),Color(.23,.16,.1,alpha*.55))
				atmosphere.draw_rect(Rect2(q-Vector2(1,1),Vector2(2,2)),Color(1,.96,.82,alpha))
func draw_young_tree(at:Vector2,height:float,fruit_color:Color,fruit:bool) -> void:
	pixel(Rect2(at-Vector2(4,height*.57),Vector2(8,height*.57)),Color("8b643b"));pixel(Rect2(at-Vector2(1,height*.54),Vector2(3,height*.54)),Color("c29452"))
	for y in range(-int(height),-int(height*.36),4):
		for x in range(-int(height*.35),int(height*.35),4):
			var n:=Vector2(float(x)/(height*.35),(y+height*.69)/(height*.32))
			if n.length_squared()>1.0+sin(y*.21)*.12:continue
			var shade:=posmod(x*13+y*17,7)
			pixel(Rect2(at+Vector2(x,y),Vector2(4,4)),[Color("426b39"),Color("5c883e"),Color("77a34d"),Color("90b64f"),Color("a6c957"),Color("719546"),Color("759d4c")][shade])
	if fruit:
		for i in 5:pixel(Rect2(at+Vector2(sin(i*2.3)*height*.23,-height*.65+cos(i*1.7)*height*.18),Vector2(6,7)),fruit_color)
