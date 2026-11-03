extends SceneTree
const World=preload("res://ayu_home/v4/world.gd")
var failures:=0
var checks:=0
func check(ok:bool,label:String) -> void:
	checks+=1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok:failures+=1
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var w:=World.new();w.nav_only=false;root.add_child(w);w.load_room("village")
	var origin:=Vector2(w.cfg.spawn[0],w.cfg.spawn[1]);var plant_props:=0
	check(w.base_sprite.texture!=null and w.base_sprite.texture.get_size()==Vector2(4800,4700),"authored whole-map ground loaded")
	check(w.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST,"coarse pixel nearest filtering")
	check(w.actors.y_sort_enabled,"raised plants use actor Y sorting")
	for p in w.props:
		if not str(p.config.id).begins_with("c4_"):continue
		plant_props+=1
		check(p.sprite.texture!=null and p.root.get_parent()==w.actors and p.root.position.y==float(p.config.foot),"loaded sorted plant at authored foot "+str(p.config.id))
	check(plant_props==23,"all 23 C4 raised plants attached")
	var index:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://ayu_home/v4/assets/rooms.json"))
	check(index.rooms.village==w.cfg,"master index exactly matches village file")
	for spot in w.cfg.doors+w.cfg.hotspots:
		var goal:=Vector2(spot.approach[0],spot.approach[1]);var path:=w.path(origin,goal)
		check(w.nearest(goal).distance_to(goal)<12 and not path.is_empty() and path[-1].distance_to(goal)<24,"preserved reachable approach "+str(spot.id))
	for obstacle in w.cfg.landscape_obstacles:
		var foot:=Vector2(obstacle[0]+obstacle[2]/2,obstacle[1]+obstacle[3]/2)
		check(not w.walkable(foot),"new solid plant root has collision")
	w.queue_free();await process_frame;print("LANDSCAPE ","PASS" if failures==0 else "FAIL"," ",checks," checks; headless path/asset precheck; N1-N5 screenshots remain C3");quit(0 if failures==0 else 1)
