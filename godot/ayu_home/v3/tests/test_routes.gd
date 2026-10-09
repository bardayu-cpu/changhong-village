extends SceneTree
const Home=preload("res://ayu_home/v3/home.gd")
var fails:Array=[]
var rows:Array=[]
var h
func _initialize() -> void:call_deferred("run")
func run() -> void:
	h=Home.new();h.save_path="/private/tmp/ayu-v3-route-save.json";root.add_child(h);await process_frame;h.set_process(false);h.set_test_clock(12.25)
	for id in h.definitions:
		h.enter_room(id,false);h.set_process(false)
		var start:Vector2=h.player.position
		for item in h.world.cfg.hotspots+h.world.cfg.doors:
			var raw:=Vector2(item.approach[0],item.approach[1]);var dest:Vector2=h.world.nearest(raw);var path:PackedVector2Array=h.world.path(start,raw)
			var ok:=not path.is_empty() and dest.distance_to(raw)<21
			rows.append({"room":id,"object":item.id,"path_points":path.size(),"approach_snap":dest.distance_to(raw),"ok":ok})
			if not ok:fails.append(id+":"+item.id+" snap="+str(dest.distance_to(raw)))
			for point in path:
				if not h.world.walkable(point):fails.append("wall "+id+":"+item.id);break
		for d in h.world.cfg.doors:
			var back:bool=false
			for other in h.definitions[d.target].doors:
				if other.target==id:back=true
			if not back:fails.append("one way "+id+":"+d.target)
	var f:=FileAccess.open("res://ayu_home/v3/evidence/routes.json",FileAccess.WRITE);f.store_string(JSON.stringify({"routes":rows,"failures":fails},"  "));f.close()
	for fail in fails:print("FAIL ",fail)
	print("RESULT ","PASS" if fails.is_empty() else "FAIL"," routes=",rows.size()," failures=",fails.size());h.stop_audio();quit(fails.size())
