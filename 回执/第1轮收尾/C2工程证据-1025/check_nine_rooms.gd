extends SceneTree
const World=preload("res://ayu_home/v4/world.gd")
var rows:Array=[]
var failures:Array=[]
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var folder:String=OS.get_cmdline_user_args()[0]
	for id in ["h1","h2","h4","h6","h7","whitebrick","erba","daba","rose"]:
		var cfg:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder+"/v_"+id+".json"))
		var w:=World.new();w.cfg=cfg;w.CELL=4;w.use_baked_navigation=false
		for box in cfg.obstacles:w.obstacles.append(Rect2(box[0],box[1],box[2],box[3]))
		w.grid.region=Rect2i(0,0,int(cfg.size[0])/w.CELL,int(cfg.size[1])/w.CELL)
		w.grid.cell_size=Vector2(w.CELL,w.CELL);w.grid.offset=Vector2(w.CELL/2,w.CELL/2)
		w.grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES;w.grid.update()
		for y in w.grid.region.size.y:
			for x in w.grid.region.size.x:w.grid.set_point_solid(Vector2i(x,y),not w.walkable(w.grid.get_point_position(Vector2i(x,y))))
		var targets:Array=cfg.hotspots+cfg.doors
		for spot in targets:
			var target:=World.v(spot.approach);var near:Vector2=w.nearest(target)
			var adjustment:=target.distance_to(near)
			var passable:=w.passable(target);var reachable:=not w.path(World.v(cfg.spawn),near).is_empty()
			rows.append({"room":id,"target":spot.id,"passable":passable,"snap_pixels":adjustment,"reachable":reachable,"nearest":[near.x,near.y]})
			if not passable or not reachable:failures.append(id+":"+str(spot.id))
		if id=="daba" and not w.passable(Vector2(396,270)):failures.append("daba ghost table on new rug")
		w.free()
	var report:={"pass":failures.is_empty(),"failures":failures,"rows":rows,"scope":"9 room physical approach/route checks only; no source-art or OS acceptance"}
	var f:=FileAccess.open(folder+"/route-check.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
