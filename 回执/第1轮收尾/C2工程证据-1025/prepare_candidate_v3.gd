extends SceneTree
const World=preload("res://ayu_home/v4/world.gd")
var w
var failures:Array=[]
var snaps:Array=[]
func _initialize() -> void:call_deferred("run")
func point(a:Array) -> Vector2:return Vector2(a[0],a[1])
func route(points:Array,label:String) -> Array:
	var result:Array=[]
	for i in range(1,points.size()):
		var part:PackedVector2Array=w.path(point(points[i-1]),point(points[i]))
		if part.is_empty():failures.append(label+":"+str(i));continue
		for p in part:
			var pair:=[p.x,p.y]
			if not result.is_empty() and pair==result.back():continue
			if result.size()>=2:
				var a:=point(result[-2]);var b:=point(result[-1])
				if (b-a).normalized().is_equal_approx((p-b).normalized()):result.pop_back()
			result.append(pair)
	return result
func make_grid() -> void:
	w.nearest_cache.clear()
	for y in w.grid.region.size.y:
		for x in w.grid.region.size.x:w.grid.set_point_solid(Vector2i(x,y),not w.walkable(w.grid.get_point_position(Vector2i(x,y)),true))
func plain(polygons:Array) -> Array:
	var result:Array=[]
	for polygon in polygons:
		var row:Array=[]
		for p in polygon:row.append([p.x,p.y])
		result.append(row)
	return result
func run() -> void:
	var folder:String=OS.get_cmdline_user_args()[0]
	var cfg:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder+"/village.json"))
	var layout:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder+"/village/layout-1025.json"))
	w=World.new();w.cfg=cfg;w.CELL=int(cfg.nav_cell);w.use_baked_navigation=false
	for box in cfg.obstacles:w.obstacles.append(Rect2(box[0],box[1],box[2],box[3]).grow(12))
	w.grid.region=Rect2i(0,0,int(cfg.size[0])/w.CELL,int(cfg.size[1])/w.CELL)
	w.grid.cell_size=Vector2(w.CELL,w.CELL);w.grid.offset=Vector2(w.CELL/2,w.CELL/2)
	w.grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES;w.grid.update();make_grid()
	for collection in ["roads","field_paths","entry_paths"]:
		for row in layout[collection]:
			row.points=route(row.points,str(row.id))
			if collection=="field_paths":row.width=56
	var all_lines:Array=layout.roads+layout.field_paths+layout.entry_paths
	var targets:Array=cfg.hotspots.duplicate(true)
	targets.append({"id":"player_spawn","approach":cfg.spawn})
	for spot in targets:
		var gate:=point(spot.approach);var closest:=gate;var distance:=INF
		for line in all_lines:
			for i in range(1,line.points.size()):
				var near:=Geometry2D.get_closest_point_to_segment(gate,point(line.points[i-1]),point(line.points[i]))
				if near.distance_squared_to(gate)<distance:closest=near;distance=near.distance_squared_to(gate)
		layout.entry_paths.append({"id":"public:"+str(spot.id),"points":route([spot.approach,[closest.x,closest.y]],"public:"+str(spot.id)),"width":56})
	layout.surface_obstacles=cfg.obstacles
	var Ground=load("res://ayu_home/v4/core/village_ground.gd")
	var ground=Ground.new()
	var layers:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder+"/village/ground-pixel-1024/layers.json"))
	layers.erase("layout");ground.configure(layers,cfg.background);ground.layout=layout;ground.build_geometry()
	cfg.field_navigation={"fields":[],"walk_surfaces":[],"margin":8}
	for field in ground.field_tiles:cfg.field_navigation.fields.append(plain([field.polygon])[0])
	for kind in ["road","yard","entry_road"]:cfg.field_navigation.walk_surfaces.append_array(plain(ground.polygons[kind]))
	w.obstacles.clear()
	for box in cfg.obstacles:w.obstacles.append(Rect2(box[0],box[1],box[2],box[3]))
	make_grid()
	var checks:Array=cfg.hotspots+cfg.doors+[{"id":"north_mountain_viewpoint","approach":[4580,600]}]
	for spot in checks:
		var target:=point(spot.approach);var near:Vector2=w.nearest(target)
		var adjustment:=target.distance_to(near);snaps.append({"id":spot.id,"pixels":adjustment})
		if adjustment>24:failures.append("approach in obstacle: "+str(spot.id))
		var path:PackedVector2Array=w.path(point(cfg.spawn),near)
		if path.is_empty():failures.append("unreachable: "+str(spot.id))
		for i in range(1,path.size()):
			for step in range(1,5):
				var at:=path[i-1].lerp(path[i],step/4.0)
				if not World.walkable_in(cfg,at):failures.append("path edge blocked: "+str(spot.id));break
	cfg.erase("_field_nav_cache")
	var report:={"failures":failures,"pass":failures.is_empty(),"approach_snaps":snaps,"doors":cfg.doors.size(),"hotspots":cfg.hotspots.size(),"entry_paths":layout.entry_paths.size(),"boundary":"actual World/AStar candidate; field walk masks exported from clipped rendered surfaces; not OS or final artwork"}
	for item in [["village/layout-1025.json",layout],["village.json",cfg],["route-check.json",report]]:
		var file:=FileAccess.open(folder+"/"+item[0],FileAccess.WRITE);file.store_string(JSON.stringify(item[1],"		"));file.close()
	print(JSON.stringify(report));ground.free();w.free();quit(0 if failures.is_empty() else 1)
