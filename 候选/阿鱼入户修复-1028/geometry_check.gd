extends SceneTree
const Ground = preload("res://ayu_home/v4/core/village_ground.gd")
const World = preload("res://ayu_home/v4/world.gd")
const ROOT = "res://ayu_home/v4/assets/"
func _initialize() -> void: call_deferred("run")
func key(polygon) -> String:
	var values:Array=[]
	for p in polygon: values.append([roundi(p[0]*1000),roundi(p[1]*1000)])
	return JSON.stringify(values)
func run() -> void:
	var args:Dictionary={}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a: args[a.get_slice("=",0)]=a.substr(a.find("=")+1)
	var cfg:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"village.json"))
	var ground=Ground.new()
	ground.layout=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"village/g0-1026/layout.json"))
	ground.build_geometry()
	var surfaces:Array=[];var known:Dictionary={}
	for kind in ["road","yard","entry_road"]:
		for polygon in ground.polygons[kind]:
			var values:Array=[]
			for p in polygon: values.append([p.x,p.y])
			surfaces.append(values);known[key(values)]=true
	if args.has("--baseline"):
		var extras:Array=[];var matched:=0
		for polygon in cfg.field_navigation.walk_surfaces:
			if known.has(key(polygon)): matched+=1
			else: extras.append(polygon)
		FileAccess.open(args["--baseline"],FileAccess.WRITE).store_string(JSON.stringify({"old_count":cfg.field_navigation.walk_surfaces.size(),"generated_count":surfaces.size(),"matched":matched,"extras":extras}))
		print("BASELINE generated=",surfaces.size()," matched=",matched," extras=",extras.size())
	elif args.has("--geometry"):
		FileAccess.open(args["--geometry"],FileAccess.WRITE).store_string(JSON.stringify(surfaces))
		print("GEOMETRY regenerated=",surfaces.size())
	elif args.has("--probe"):
		var w=World.new();w.nav_only=true;w.use_baked_navigation=false;w.load_room("village")
		var door:Dictionary=w.spot("visit_ayu")
		var g:Vector2=w.nearest(Vector2(2424,2616));var r:Vector2=w.nearest(Vector2(2418,2689))
		var mask:=PackedByteArray();mask.resize(w.grid.region.size.x*w.grid.region.size.y)
		for y in w.grid.region.size.y:
			for x in w.grid.region.size.x: mask[y*w.grid.region.size.x+x]=1 if w.grid.is_point_solid(Vector2i(x,y)) else 0
		FileAccess.open(ROOT+"village.nav",FileAccess.WRITE).store_buffer(mask)
		var hashing:=HashingContext.new();hashing.start(HashingContext.HASH_SHA256);hashing.update(mask)
		var report:Dictionary={"kind":"author_engine_navigation_only_not_native_playthrough","G":[g.x,g.y],"R":[r.x,r.y],"plane":[w.door_plane(door).point.x,w.door_plane(door).point.y],"width":w.door_plane(door).width,"path_public_to_G":w.path(Vector2(1800,3704),g).size(),"path_G_to_R":w.path(g,r).size(),"negative_left_wall":not w.passable(Vector2(2300,2640)),"negative_garage":not w.passable(Vector2(2072,2620)),"negative_south_neighbor":not w.passable(Vector2(2250,2880)),"swept_entry":w.crossed_door(door,Vector2(2424,2640),g),"side_pass_does_not_enter":not w.crossed_door(door,Vector2(2504,2640),Vector2(2504,2616)),"baked_bytes":mask.size(),"baked_sha256":hashing.finish().hex_encode()}
		FileAccess.open(args["--probe"],FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
		print("AUTHOR_NAV_PROBE ",JSON.stringify(report))
		var ok:bool=g==Vector2(2424,2616) and r==Vector2(2424,2696) and report.path_public_to_G>0 and report.path_G_to_R>0 and report.negative_left_wall and report.negative_garage and report.negative_south_neighbor and report.swept_entry and report.side_pass_does_not_enter
		w.free();ground.free();quit(0 if ok else 3);return
	ground.free();quit()
