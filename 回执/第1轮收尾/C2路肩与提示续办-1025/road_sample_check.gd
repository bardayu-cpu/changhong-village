extends SceneTree
const Terrain=preload("res://ayu_home/v4/core/village_ground.gd")
const World=preload("res://ayu_home/v4/world.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var start:=Time.get_ticks_msec()
	var terrain:=Terrain.new();root.add_child(terrain)
	var cfg:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://ayu_home/v4/assets/village.json"))
	terrain.configure_path(str(cfg.ground_layers),str(cfg.background))
	var w:=World.new()
	terrain.mount_layers(func(_kind):return w.make_season_material())
	var okay:bool=terrain.road_surface!=null and terrain.has_node("road_surface") and not terrain.has_node("road") and terrain.road_surface.mask.get_width()==1200 and terrain.road_surface.road.get_width()==256
	print(JSON.stringify({"pass":okay,"configure_ms":Time.get_ticks_msec()-start,"road_polygons":terrain.polygons.road.size(),"mask_size":str(terrain.road_surface.mask.get_size()),"scope":"load, material setup and coverage construction only; actual shader/visual gate by C3"}))
	terrain.queue_free();w.free();await process_frame;quit(0 if okay else 1)
