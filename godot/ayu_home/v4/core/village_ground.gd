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
var winter_active:=false
var layout:Dictionary={}
var field_tiles:Array=[]
var season_index:=1
var roadside=preload("res://ayu_home/v4/core/natural_verges.gd").new()
var road_surface
var native_surface
var native_enabled:=false
var native_cut:=PackedVector2Array()
var legacy_earth:Texture2D
var view_rect:=Rect2()
func set_view(rect:Rect2) -> void:
	if view_rect.is_equal_approx(rect):return
	view_rect=rect
	if has_node("mountain"):get_node("mountain").queue_redraw()
func configure_path(path:String,background:String) -> void:
	configure(JSON.parse_string(FileAccess.get_file_as_string(path)),background)
func configure(value:Dictionary,background:String) -> void:
	spec=value;old_background=Assets.texture(background)
	native_enabled=spec.has("g0_native")
	if spec.has("layout"):
		layout=JSON.parse_string(FileAccess.get_file_as_string(str(spec.layout)))
		if layout.has("mountain_rect"):spec.mountain.rect=layout.mountain_rect
	for kind in ORDER:
		polygons[kind]=[]
		if spec.has(kind):textures[kind]=Assets.texture(str(spec[kind].file))
		elif kind=="entry_road":textures[kind]=Assets.texture(str(spec.road.file))
	build_geometry()
	if not layout.is_empty() and spec.has("road_sample") and not native_enabled:
		road_surface=preload("res://ayu_home/v4/core/road_surface.gd").new()
		road_surface.setup(polygons.road+polygons.yard+polygons.entry_road,Vector2(layout.size[0],layout.size[1]),spec.road_sample)
	if native_enabled:
		native_surface=preload("res://ayu_home/v4/core/native_surface.gd").new()
		var contract:Dictionary={}
		if FileAccess.file_exists(str(spec.g0_native.manifest)):contract=JSON.parse_string(FileAccess.get_file_as_string(str(spec.g0_native.manifest)))
		native_surface.configure(self,spec.g0_native,contract)
		var b:Array=spec.g0_native.region
		native_cut=PackedVector2Array([Vector2(b[0],b[1]),Vector2(b[0]+b[2],b[1]),Vector2(b[0]+b[2],b[1]+b[3]),Vector2(b[0],b[1]+b[3])])
		var atlas:=AtlasTexture.new();atlas.atlas=Assets.texture("res://ayu_home/v4/assets/village/road-shoulder-1025/road-transition-atlas.png");atlas.region=Rect2(0,0,256,256);atlas.filter_clip=true;legacy_earth=atlas
	if not layout.is_empty():roadside.setup(layout,polygons.road+polygons.yard+polygons.entry_road)
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
func build_geometry() -> void:
	# All four seasons consume this geometry; materials change the surface, never the layout.
	field_rects.clear()
	field_tiles.clear()
	for kind in ORDER:polygons[kind]=[]
	if not layout.is_empty():
		build_layout_geometry();return
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
func build_layout_geometry() -> void:
	add_rect("grass",Rect2(Vector2.ZERO,Vector2(layout.size[0],layout.size[1])))
	for road in layout.roads:
		if not road is Dictionary:add_path("road",road,112);continue
		for i in range(1,road.points.size()):
			var a:Array=road.points[i-1];var b:Array=road.points[i]
			var middle:=Vector2((a[0]+b[0])*.5,(a[1]+b[1])*.5);var width:=float(road.get("width",112))
			for limit in road.get("width_limits",[]):
				var r:Array=limit.rect
				if Rect2(r[0],r[1],r[2],r[3]).has_point(middle):width=minf(width,float(limit.width))
			add_path("road",[a,b],width)
	for path in layout.get("field_paths",[]):add_path("yard",path.points if path is Dictionary else path,float(path.get("width",34)) if path is Dictionary else 34.0)
	for polygon in layout.get("yards",[]):polygons.yard.append(points_of(polygon))
	polygons.water.append(points_of(layout.water_polygon))
	var houses:Array=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"houses.json"))
	for house in houses:
		if layout.has("entry_paths"):break
		var gate:=Vector2(house.at[0],house.at[1]);var nearest:=gate;var distance:=INF
		for road in layout.roads:
			var points:Array=road.points if road is Dictionary else road
			for i in range(1,points.size()):
				var a:=Vector2(points[i-1][0],points[i-1][1]);var b:=Vector2(points[i][0],points[i][1])
				var on_line:=Geometry2D.get_closest_point_to_segment(gate,a,b)
				if on_line.distance_squared_to(gate)<distance:nearest=on_line;distance=on_line.distance_squared_to(gate)
		add_path("entry_road",[[gate.x,gate.y],[nearest.x,nearest.y]],56)
	for path in layout.get("entry_paths",[]):add_path("entry_road",path.points,float(path.get("width",56)))
	for field in layout.fields:
		var polygon:=points_of(field.polygon) if field.has("polygon") else PackedVector2Array([Vector2(field.rect[0],field.rect[1]),Vector2(field.rect[0]+field.rect[2],field.rect[1]),Vector2(field.rect[0]+field.rect[2],field.rect[1]+field.rect[3]),Vector2(field.rect[0],field.rect[1]+field.rect[3])])
		field_tiles.append({"polygon":polygon,"spec":field})
	# Trim the full drawn width and round caps against the same solid footprints.
	for box in layout.get("surface_obstacles",[]):
		var r:=Rect2(box[0],box[1],box[2],box[3]).grow(3)
		var cutter:=PackedVector2Array([r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)])
		for kind in ["road","yard","entry_road"]:
			var pieces:Array=[]
			for polygon in polygons[kind]:pieces.append_array(Geometry2D.clip_polygons(polygon,cutter))
			polygons[kind]=pieces
static func points_of(values:Array) -> PackedVector2Array:
	var result:=PackedVector2Array()
	for point in values:result.append(Vector2(point[0],point[1]))
	return result
func add_rect(kind:String,r:Rect2) -> void:
	polygons[kind].append(PackedVector2Array([r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)]))
func add_path(kind:String,points:Array,width:float) -> void:
	var line=PackedVector2Array()
	for p in points:line.append(Vector2(p[0],p[1]))
	for polygon in Geometry2D.offset_polyline(line,width*.5,Geometry2D.JOIN_ROUND,Geometry2D.END_ROUND):polygons[kind].append(polygon)
func mount_layers(material_factory:Callable) -> void:
	for kind in draw_order():
		if road_surface and kind in ["yard","entry_road","road"]:
			if kind!="yard":continue
			var lane:=Node2D.new();lane.name="road_surface";add_child(lane)
			lane.material=road_surface.material(material_factory.call("road"))
			lane.draw.connect(func():road_surface.paint(lane))
			continue
		if kind=="water" and not layout.is_empty():
			var verge_layer:=Node2D.new();verge_layer.name="natural_verges";add_child(verge_layer);verge_layer.draw.connect(func():roadside.paint(verge_layer,1.0,Vector2.ZERO,season_index))
		var layer=Node2D.new();layer.name=kind;add_child(layer)
		layer.texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
		layer.material=material_factory.call(kind)
		layer.draw.connect(func():draw_to(layer,1.0,Vector2.ZERO,kind))
	if native_enabled:native_surface.mount(self)
func set_winter(active:bool) -> void:
	if active==winter_active:return
	winter_active=active
	# Winter used to hide these layers and expose the obsolete baked road network.
	# Keep the same layers for both the live world and map; world materials apply snow.
	queue_redraw()
	for child in get_children():child.queue_redraw()
func set_season(index:int) -> void:
	if index==season_index:return
	season_index=index;set_winter(index==3)
	queue_redraw()
	for child in get_children():child.queue_redraw()
func draw_order() -> Array:
	if native_enabled:return ["grass","fields","yard","entry_road","road","water"]
	return ORDER if layout.is_empty() else ["grass","fields","yard","entry_road","road","water","mountain"]
func visible_legacy_pieces(polygon:PackedVector2Array,only:String) -> Array:
	# Map style remains legacy during G0; no holes. G1 will unify the full map.
	if native_enabled and native_surface.ready_art and not only.is_empty():
		var north:float=spec.g0_native.north_y
		var sky_cut:=PackedVector2Array([Vector2(0,0),Vector2(layout.size[0],0),Vector2(layout.size[0],north),Vector2(0,north)])
		var result:Array=[]
		for piece in Geometry2D.clip_polygons(polygon,native_cut):result.append_array(Geometry2D.clip_polygons(piece,sky_cut))
		return result
	return [polygon]
func draw_to(canvas:CanvasItem,factor:=1.0,offset:=Vector2.ZERO,only:="") -> void:
	for kind in draw_order():
		if only.is_empty() and kind=="water" and not layout.is_empty():roadside.paint(canvas,factor,offset,season_index)
		if not only.is_empty() and kind!=only:continue
		if kind=="fields":
			if not layout.is_empty():
				for field in field_tiles:
					var definition:Dictionary=field.spec
					var key:String=["spring","summer","autumn","winter"][season_index]
					var file:=str(definition.get("season_files",{}).get(key,definition.get("file","")))
					if file.is_empty():continue
					var texture:=preload("res://ayu_home/v4/core/natural_terrain.gd").foliage(file,season_index)
					if texture==null:continue
					for piece in visible_legacy_pieces(field.polygon,only):
						var screen:=PackedVector2Array();var uv:=PackedVector2Array()
						for point in piece:screen.append(offset+point*factor);uv.append(point/float(definition.get("repeat",192)))
						canvas.draw_polygon(screen,PackedColorArray([Color.WHITE]),uv,texture)
				continue
			if old_background:
				for rect in field_rects:canvas.draw_texture_rect_region(old_background,Rect2(offset+rect.position*factor,rect.size*factor),rect)
			continue
		var texture:Texture2D=textures.get(kind)
		if texture==null:continue
		if not layout.is_empty():
			if kind in ["road","yard","entry_road"]:texture=legacy_earth if native_enabled else (road_surface.road if road_surface else preload("res://ayu_home/v4/core/natural_terrain.gd").earth())
			elif kind=="grass":texture=preload("res://ayu_home/v4/core/natural_terrain.gd").foliage(str(spec.grass.file),season_index,true)
		if kind=="mountain":
			if not layout.is_empty() and spec.mountain.get("panorama",false):
				var band:Array=layout.mountain_rect
				var region:Array=spec.mountain.get("panorama_region",[500,0,1200,600])
				var span:=Rect2(band[0],band[1],band[2],band[3])
				canvas.draw_rect(Rect2(offset+span.position*factor,span.size*factor),Color("b8d0db"))
				# The map shows the whole distant range; normal play frames its skyline in the visible horizon.
				if only=="mountain" and view_rect.has_area():
					var left:=maxf(span.position.x,view_rect.position.x);var right:=minf(span.end.x,view_rect.end.x)
					if right<=left:continue
					var height:float=(right-left)*float(region[3])/float(region[2])
					var target:=Rect2(left,span.end.y-height,right-left,height)
					canvas.draw_texture_rect_region(texture,target,Rect2(region[0],region[1],region[2],region[3]))
				else:
					var source:Array=spec.mountain.source_region
					canvas.draw_texture_rect_region(texture,Rect2(offset+span.position*factor,span.size*factor),Rect2(source[0],source[1],source[2],source[3]))
				continue
			canvas.draw_rect(Rect2(offset+Vector2(float(spec.mountain.rect[0]),0)*factor,Vector2(float(spec.mountain.rect[2]),180)*factor),Color("b8d0db"))
			var a:Array=spec.mountain.rect
			var destination=Rect2(offset+Vector2(a[0],a[1])*factor,Vector2(a[2],a[3])*factor)
			var region:Array=spec.mountain.source_region
			canvas.draw_texture_rect_region(texture,destination,Rect2(region[0],region[1],region[2],region[3]))
			continue
		var repeat_size:float=float(spec.get(kind,spec.road).get("repeat",384))
		if native_enabled and kind in ["road","yard","entry_road"]:repeat_size=256.0
		for polygon in polygons[kind]:
			for piece in visible_legacy_pieces(polygon,only):
				var screen=PackedVector2Array();var uv=PackedVector2Array()
				for point in piece:screen.append(offset+point*factor);uv.append(point/repeat_size)
				canvas.draw_polygon(screen,PackedColorArray([Color.WHITE]),uv,texture)
