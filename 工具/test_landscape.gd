extends SceneTree
const World=preload("res://ayu_home/v4/world.gd")
var failures:=0
func check(ok:bool,label:String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok:failures+=1
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var w:=World.new();w.nav_only=false;root.add_child(w);w.load_room("village")
	var origin:=Vector2(w.cfg.spawn[0],w.cfg.spawn[1]);var ground_props:=0;var plant_props:=0
	for p in w.cfg.props:
		if not str(p.id).begins_with("land_"):continue
		if p.get("ground",false):ground_props+=1
		else:plant_props+=1
		check(FileAccess.file_exists(w.asset_path(p.file)),"asset exists "+str(p.id))
	check(ground_props>0 and plant_props>0,"ground decorations and sorted raised plants both attached")
	var index:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://ayu_home/v4/assets/rooms.json"))
	check(index.rooms.village==w.cfg,"master index exactly matches village file")
	for spot in w.cfg.doors+w.cfg.hotspots:
		var goal:=Vector2(spot.approach[0],spot.approach[1]);var path:=w.path(origin,goal)
		check(w.nearest(goal).distance_to(goal)<12 and not path.is_empty() and path[-1].distance_to(goal)<24,"preserved reachable approach "+str(spot.id))
	for obstacle in w.cfg.landscape_obstacles:
		var foot:=Vector2(obstacle[0]+obstacle[2]/2,obstacle[1]+obstacle[3]/2)
		check(not w.walkable(foot),"new solid plant root has collision")
	w.queue_free();await process_frame;print("LANDSCAPE ","PASS" if failures==0 else "FAIL","; headless path/asset precheck; N1-N5 screenshots remain C3");quit(0 if failures==0 else 1)
