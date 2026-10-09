extends Node2D
const Assets = preload("res://ayu_home/v2/assets.gd")
const Actor = preload("res://ayu_home/v3/actor.gd")
const P := "res://ayu_home/v3/assets/"
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
var food_until := 0.0
var camera_center := Vector2.ZERO
var ambient: CanvasModulate
var lights: Array[PointLight2D] = []
var windows: Array = []
var reactions:Dictionary={}
var toggles:Dictionary={}
var sharp:=false
var sharp_material:ShaderMaterial
var base_sprite:Sprite2D
var nearest_cache:Dictionary={}
var parallax_origin := Vector2.ZERO

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func load_room(which: String) -> void:
	for n in get_children(): remove_child(n); n.queue_free()
	props.clear();lights.clear();obstacles.clear();windows.clear();nearest_cache.clear()
	area = which
	cfg = JSON.parse_string(FileAccess.get_file_as_string(P+area+".json"))
	var bg := Sprite2D.new();bg.centered = false;bg.texture = Assets.texture(P+str(cfg.get("background",area+"_floor.png")));add_child(bg);base_sprite=bg
	if cfg.get("floor",0)==1 and sharp:bg.material=sharpen_material()
	ground = Node2D.new();ground.draw.connect(_ground_draw);add_child(ground)
	actors = Node2D.new();actors.y_sort_enabled = true;add_child(actors)
	for p in cfg.props:
		var base := Node2D.new();base.position = Vector2(0,float(p.foot));actors.add_child(base)
		var sp := Sprite2D.new();sp.centered = false;sp.texture = Assets.texture(P+p.file);sp.position = v(p.pos)-base.position;base.add_child(sp)
		if cfg.get("floor",0)==1 and sharp:sp.material=sharpen_material()
		props.append({"root":base,"sprite":sp,"origin":sp.position,"config":p})
	for pane in []:
		var view=preload("res://ayu_home/v2/window_view.gd").new()
		view.texture=Assets.texture(P+pane.file);view.centered=false;view.position=v(pane.pos);view.z_index=2
		var shader:=Shader.new();shader.code="shader_type canvas_item; uniform float shift=0.0; void fragment(){COLOR=texture(TEXTURE,vec2(clamp(UV.x+shift,0.0,1.0),UV.y));}"
		var mat:=ShaderMaterial.new();mat.shader=shader;view.material=mat;add_child(view);windows.append(view)
	for b in cfg.obstacles: obstacles.append(Rect2(b[0],b[1],b[2],b[3]))
	ambient = CanvasModulate.new();add_child(ambient)
	var im := Image.create(128,128,false,Image.FORMAT_RGBA8)
	for y in 128:
		for x in 128:
			var a := pow(maxf(0,1-Vector2(x-64,y-64).length()/64),1.7)
			im.set_pixel(x,y,Color(a,a,a,1))
	var tex := ImageTexture.create_from_image(im)
	for l in cfg.lamps:
		var lamp := PointLight2D.new();lamp.texture = tex;lamp.texture_scale = float(l[2])/64;lamp.position = Vector2(l[0],l[1]);lamp.color = Color("ffd49b");lamp.blend_mode = Light2D.BLEND_MODE_ADD;add_child(lamp);lights.append(lamp)
	atmosphere = Node2D.new();atmosphere.z_index = 100;atmosphere.draw.connect(_air_draw);add_child(atmosphere)
	grid.region = Rect2i(0,0,int(cfg.size[0])/8,int(cfg.size[1])/8)
	grid.cell_size = Vector2(8,8);grid.offset = Vector2(4,4);grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES;grid.update()
	for y in grid.region.size.y:
		for x in grid.region.size.x:grid.set_point_solid(Vector2i(x,y),not walkable(Vector2(x*8+4,y*8+4)))
	update_light()

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
		if b.grow(5).has_point(at): return false
	return true
func nearest(at: Vector2) -> Vector2:
	if nearest_cache.has(at):return nearest_cache[at]
	var cell:=Vector2i(at/8)
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
	return grid.get_point_path(Vector2i(nearest(start)/8),Vector2i(nearest(finish)/8))
func spawn() -> Vector2:return nearest(v(cfg.spawn))
func spot(id: String) -> Dictionary:
	for h in cfg.hotspots+cfg.get("doors",[]):
		if h.id == id:return h
	return {}
func _process(dt: float) -> void:
	elapsed += dt
	if not ground:return
	update_light();ground.queue_redraw();atmosphere.queue_redraw()
	if area=="garden":
		base_sprite.texture=Assets.texture(P+["garden_spring.png","garden_summer.png","garden.png","garden_winter.png"][preload("res://ayu_home/home_data.gd").season(month)])
	for view in windows:view.sync(camera_center.x-parallax_origin.x if effects_enabled else 0)
	for p in props:
		if p.config.front:p.sprite.position = p.origin-((camera_center-parallax_origin)*.012).clamp(Vector2(-1,-1),Vector2(1,1)) if effects_enabled else p.origin
		if p.config.has("off_file"):p.sprite.texture=Assets.texture(P+(p.config.file if tv_on else p.config.off_file))
func update_light() -> void:
	if not ambient:return
	if not effects_enabled:
		ambient.color=Color.WHITE
		for light in lights:light.enabled=false
		return
	var night := hour<6 or hour>=22
	var evening := hour>=18 and hour<22
	ambient.color = Color("424c70") if night else (Color("ac846d") if evening else (Color("f5d9b6") if hour<10 else Color.WHITE))
	if weather=="rain" and not night:ambient.color *= Color(.78,.85,.91)
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
				ground.draw_colored_polygon(PackedVector2Array([p,p+Vector2(width*.23,0),p+Vector2(width*.23+shift,reach),p+Vector2(shift,reach)]),Color(1,.85,.51,.19 if hour<10 else .13))
func soft_shadow(at:Vector2,width:float,opacity:float) -> void:
	var sv:=shadow_vector(at)*.60
	for layer in range(4):
		var spread:=1+float(3-layer)*.09
		var pts:=PackedVector2Array()
		for i in 24:
			var angle:=TAU*i/24.0
			pts.append(at+sv*.3+Vector2(cos(angle)*width*spread+sin(angle)*sv.x*.35,sin(angle)*(5+absf(sv.y)*.25)*spread))
		ground.draw_colored_polygon(pts,Color(.08,.09,.15,opacity*.25))
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
			for i in 10:
				var x := rect.position.x+fposmod(i*29+elapsed*8-camera_center.x*.08,rect.size.x)
				var y := rect.position.y+fposmod(i*13+elapsed*15,rect.size.y)
				if weather=="rain":atmosphere.draw_line(Vector2(x,y),Vector2(x-2,minf(rect.end.y,y+7)),Color(.65,.82,.9,.65),1)
				else:atmosphere.draw_rect(Rect2(x,y,2,2),season_particle())
			if hour>=6 and hour<18 and weather!="rain":
				for i in 12:
					var p := Vector2(rect.position.x+fposmod(i*19+elapsed*2,rect.size.x),rect.end.y+fposmod(i*15-elapsed*3,250)*(-1 if rect.position.y>float(cfg.size[1])*.5 else 1))
					atmosphere.draw_rect(Rect2(p,Vector2.ONE),Color(1,.9,.64,.5))
	else:
		for i in 32:
			var p := Vector2(fposmod(i*79+elapsed*(30 if weather=="rain" else 8),float(cfg.size[0])),fposmod(i*137+elapsed*(160 if weather=="rain" else 20),float(cfg.size[1])))
			if weather=="rain":atmosphere.draw_line(p,p+Vector2(-3,10),Color(.7,.85,.9,.4),1)
			else:atmosphere.draw_rect(Rect2(p,Vector2(2,2)),season_particle())
	# Every reaction changes the scene at the object, even in daylight.
	for id in toggles:
		var h:=spot(id)
		if h.is_empty():continue
		var p:=v(h.pos)
		if h.get("effect","")=="lamp":
			if toggles[id]:
				for r in [24,18,11]:atmosphere.draw_circle(p,r,Color(1,.82,.34,.11))
			else:atmosphere.draw_rect(Rect2(p-Vector2(10,8),Vector2(20,15)),Color(.21,.18,.17,.62))
		elif toggles[id]:
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
		elif fx=="bunny":atmosphere.draw_string(preload("res://ayu_home/v3/pixel_ui.gd").FONT,p+Vector2(5,-25-age*2),"♥",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("e2a1a8"))
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
	shader.code="shader_type canvas_item; void fragment(){vec4 c=texture(TEXTURE,UV); vec3 n=(texture(TEXTURE,UV+vec2(TEXTURE_PIXEL_SIZE.x*2.0,0.0)).rgb+texture(TEXTURE,UV-vec2(TEXTURE_PIXEL_SIZE.x*2.0,0.0)).rgb+texture(TEXTURE,UV+vec2(0.0,TEXTURE_PIXEL_SIZE.y*2.0)).rgb+texture(TEXTURE,UV-vec2(0.0,TEXTURE_PIXEL_SIZE.y*2.0)).rgb)*0.25; COLOR=vec4(clamp(c.rgb+clamp((c.rgb-n)*0.85,vec3(-0.0470588),vec3(0.0470588)),vec3(0.0),vec3(1.0)),c.a);}"
	sharp_material=ShaderMaterial.new();sharp_material.shader=shader;return sharp_material
func react(h:Dictionary) -> void:
	reactions[h.id]={"effect":h.get("effect","spark"),"pos":h.pos,"at":elapsed}
	if h.get("effect","")=="lamp":
		lamp_on=not lamp_on;toggles[h.id]=lamp_on
	elif h.get("effect","")=="open":toggles[h.id]=not toggles.get(h.id,false)
func view_bounds() -> Rect2:
	return Rect2(Vector2.ZERO,v(cfg.size))
