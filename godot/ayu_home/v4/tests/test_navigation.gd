extends SceneTree
const W=preload("res://ayu_home/v4/world.gd")
var failures:Array=[]
var rows:Array=[]
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var definitions:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://ayu_home/v4/assets/rooms.json")).rooms
	for id in definitions:
		var w=W.new();root.add_child(w);w.load_room(id);w.effects_enabled=false;w.set_process(false)
		var start:Vector2=w.spawn();var count:=0;var missing:Array=[]
		for item in w.cfg.hotspots+w.cfg.doors:
			var target:Vector2=w.nearest(W.v(item.approach));var route:PackedVector2Array=w.path(start,target)
			if route.is_empty():missing.append(item.id);failures.append(id+":"+item.id+" unreachable "+str(start)+" -> "+str(target))
			else:
				for p in route:
					if not w.walkable(p):failures.append(id+":"+item.id+" crosses blocked point "+str(p))
				count+=1
		rows.append({"room":id,"routes":count,"failed":missing,"obstacles":w.cfg.obstacles.size(),"spawn":[start.x,start.y]})
		print(id," routes=",count," failed=",missing);w.queue_free();await process_frame
	var file:=FileAccess.open("res://ayu_home/v4/evidence/navigation.json",FileAccess.WRITE);file.store_string(JSON.stringify({"rooms":rows,"failures":failures},"  "));file.close()
	for problem in failures:print("FAIL ",problem)
	print("RESULT ","PASS" if failures.is_empty() else "FAIL"," ",failures.size());quit(0 if failures.is_empty() else 1)
