extends Node2D
# One geometry source for the live village and its map. Textures remain byte-for-byte C4 art.
const Assets=preload("res://ayu_home/v2/assets.gd")
const ROOT="res://ayu_home/v4/assets/village/"
const ORDER=["grass","entry_road","yard","road","fields","water","bridge","mountain"]
var spec:Dictionary={}
var polygons:Dictionary={}
var textures:Dictionary={}
var field_rects:Array=[]
var old_background:Texture2D
var winter_original:=false
func configure_path(path:String,background:String) -> void:
	configure(JSON.parse_string(FileAccess.get_file_as_string(path)),background)
func configure(value:Dictionary,background:String) -> void:
	spec=value;old_background=Assets.texture(background)
	for kind in ORDER:
		polygons[kind]=[]
		if spec.has(kind):textures[kind]=Assets.texture(str(spec[kind].file))
		elif kind=="entry_road":textures[kind]=Assets.texture(str(spec.road.file))
	var topology:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"topology.json"))
	var landscape:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"landscape-layout.json"))
	var houses:Array=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"houses.json"))
	add_rect("grass",Rect2(0,0,4800,4700))
	var road_points:Array=[]
	for road in topology.roads:
		add_path("road",road,112)
		road_points.append_array(road)
	for path in landscape.get("field_paths",[]):add_path("yard",path,34)
	for house in houses:
		var gate=Vector2(house.at[0],house.at[1]);var nearest=gate;var distance=INF
		for point in road_points:
			var p=Vector2(point[0],point[1]);var d=gate.distance_squared_to(p)
			if d<distance:distance=d;nearest=p
		var width=clampf(float(house.bounds[2])*.62,240,540)
		var depth=240.0 if house.id in ["mayor","community"] else 200.0
		if house.id in ["mayor","community"]:width=560.0
		add_rect("yard",Rect2(gate-Vector2(width*.5,30),Vector2(width,depth)))
		add_path("entry_road",[[gate.x,gate.y],[gate.x,gate.y+36],[nearest.x,nearest.y]],76)
	for field in landscape.fields:
		var a:Array=field.rect;field_rects.append(Rect2(a[0],a[1],a[2],a[3]).grow(24))
	# This water band and these four openings exactly match the existing collision source.
	add_rect("water",Rect2(3480,0,90,4700))
	for span in [[660,850],[1820,1990],[2970,3150],[4230,4420]]:
		add_rect("bridge",Rect2(3440,span[0],170,span[1]-span[0]))
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
func add_rect(kind:String,r:Rect2) -> void:
	polygons[kind].append(PackedVector2Array([r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)]))
func add_path(kind:String,points:Array,width:float) -> void:
	var line=PackedVector2Array()
	for p in points:line.append(Vector2(p[0],p[1]))
	for polygon in Geometry2D.offset_polyline(line,width*.5,Geometry2D.JOIN_ROUND,Geometry2D.END_ROUND):polygons[kind].append(polygon)
func mount_layers(material_factory:Callable) -> void:
	for kind in ORDER:
		var layer=Node2D.new();layer.name=kind;add_child(layer)
		layer.texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
		layer.material=material_factory.call(kind)
		layer.draw.connect(func():draw_to(layer,1.0,Vector2.ZERO,kind))
func set_winter(active:bool) -> void:
	if active==winter_original:return
	winter_original=active
	for child in get_children():child.visible=not active or child.name=="mountain"
func draw_to(canvas:CanvasItem,factor:=1.0,offset:=Vector2.ZERO,only:="") -> void:
	for kind in ORDER:
		if not only.is_empty() and kind!=only:continue
		if winter_original and kind!="mountain":continue
		if kind=="fields":
			if old_background:
				for rect in field_rects:canvas.draw_texture_rect_region(old_background,Rect2(offset+rect.position*factor,rect.size*factor),rect)
			continue
		var texture:Texture2D=textures.get(kind)
		if texture==null:continue
		if kind=="mountain":
			canvas.draw_rect(Rect2(offset+Vector2(float(spec.mountain.rect[0]),0)*factor,Vector2(float(spec.mountain.rect[2]),180)*factor),Color("b8d0db"))
			var a:Array=spec.mountain.rect
			var destination=Rect2(offset+Vector2(a[0],a[1])*factor,Vector2(a[2],a[3])*factor)
			var region:Array=spec.mountain.source_region
			canvas.draw_texture_rect_region(texture,destination,Rect2(region[0],region[1],region[2],region[3]))
			continue
		var repeat_size:float=float(spec.get(kind,spec.road).get("repeat",384))
		for polygon in polygons[kind]:
			var screen=PackedVector2Array();var uv=PackedVector2Array()
			for point in polygon:screen.append(offset+point*factor);uv.append(point/repeat_size)
			canvas.draw_polygon(screen,PackedColorArray([Color.WHITE]),uv,texture)
