extends SceneTree
const Ground=preload("res://ayu_home/v4/core/village_ground.gd")
const World=preload("res://ayu_home/v4/world.gd")
var failures:Array=[]
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var ground:=Ground.new();root.add_child(ground)
	var cfg:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://ayu_home/v4/assets/village.json"))
	ground.configure_path(cfg.ground_layers,cfg.background)
	ground.layout={"size":[4800,4700],"roads":[{"points":[[500,4500],[2500,2500],[4700,800]],"width":112}],"field_paths":[[[900,900],[2000,900]]],"water_polygon":[[4750,0],[4800,0],[4800,4700],[4750,4700]],"fields":[{"rect":[200,220,400,400],"file":"res://ayu_home/v4/assets/village/ground-pixel-1024/grass.png"}]}
	ground.build_geometry()
	if not ground.polygons.bridge.is_empty():failures.append("old bridges leaked into new layout")
	if ground.polygons.water.size()!=1 or ground.field_tiles.size()!=1:failures.append("layout field or water omitted")
	var snapshot:=var_to_str([ground.polygons,ground.field_tiles])
	for season in 4:
		ground.set_season(season)
		if snapshot!=var_to_str([ground.polygons,ground.field_tiles]):failures.append("season modified layout")
	var collision:Dictionary={"walk_rect":[0,0,4800,4700],"obstacles":[],"blocked_polygons":[ground.layout.water_polygon]}
	if World.walkable_in(collision,Vector2(4770,900)):failures.append("water is walkable")
	if not World.walkable_in(collision,Vector2(4700,900)):failures.append("bank is blocked")
	print(JSON.stringify({"pass":failures.is_empty(),"failures":failures,"seasons":4,"houses_connected":ground.polygons.entry_road.size(),"scope":"synthetic layout branch only; no production positions changed"}))
	ground.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
