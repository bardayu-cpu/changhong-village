extends SceneTree
const Terrain=preload("res://ayu_home/v4/core/village_ground.gd")
const Home=preload("res://ayu_home/v4/home.gd")
var failures:Array=[]
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var terrain:=Terrain.new();root.add_child(terrain)
	var cfg:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://ayu_home/v4/assets/village.json"))
	terrain.configure_path(str(cfg.ground_layers),str(cfg.background))
	terrain.mount_layers(func(_kind):return null)
	var geometry:=var_to_str([terrain.polygons,terrain.field_rects])
	var road_count:int=terrain.polygons.road.size()
	if road_count==0:failures.append("missing roads")
	for winter in [false,true,false,true]:
		terrain.set_winter(winter)
		if var_to_str([terrain.polygons,terrain.field_rects])!=geometry:failures.append("season changed geometry")
		for layer in terrain.get_children():
			if not layer.visible:failures.append("hidden layer: "+str(layer.name))
	print(JSON.stringify({"winter_toggles":4,"road_polygons":road_count,"layers":terrain.get_child_count(),"geometry_stable":failures.is_empty(),"failures":failures}))
	terrain.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
