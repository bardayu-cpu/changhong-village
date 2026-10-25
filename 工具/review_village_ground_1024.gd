extends SceneTree
const World=preload("res://ayu_home/v4/world.gd")
const MapView=preload("res://ayu_home/v4/core/map_view.gd")
class MapState:
	extends RefCounted
	var data={"village":{"location":""}}
	var winter:=false
	func season():return "冬" if winter else "夏"
var render:=false
var run_id:=""
var failed:=false
var rows:Array=[]
func _initialize():
	render="--render" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--run-id="):run_id=arg.trim_prefix("--run-id=")
	if not run_id.is_empty() and (run_id.length()!=32 or not run_id.is_valid_hex_number(false)):push_error("Expected32 hex run id");quit(1);return
	call_deferred("run")
func check(ok:bool,label:String):
	failed=failed or not ok;rows.append({"check":label,"pass":ok});print("PASS " if ok else "FAIL ",label)
func run():
	root.size=Vector2i(1000,980)
	var folder=ProjectSettings.globalize_path("res://../测试数据/地面接入-1024/")
	if not run_id.is_empty():folder+="runs/"+run_id+"/"
	DirAccess.make_dir_recursive_absolute(folder)
	var viewport=SubViewport.new();viewport.world_2d=World2D.new();viewport.size=Vector2i(1000,980);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var world=World.new();world.nav_only=not render;world.effects_enabled=true;world.hour=13;world.weather="clear";viewport.add_child(world);world.load_room("village");world.scale=Vector2.ONE*(1000.0/4800.0)
	var start=world.spawn()
	for y in [750,1900,3050,4320]:
		var goal=Vector2(3525,y);var path=world.path(start,goal)
		check(world.passable(goal) and not path.is_empty() and path[-1].distance_to(goal)<16,"original bridge reachable "+str(y))
	for door in world.cfg.doors:
		if float(door.approach[1])>=600:continue
		var goal=World.v(door.approach);var path=world.path(start,goal)
		check(world.passable(goal) and not path.is_empty() and path[-1].distance_to(goal)<16,"north door reachable "+str(door.id))
	check(not world.passable(Vector2(2560,90)),"mountain band blocked")
	check(world.nearest(Vector2(2560,90)).y>=180,"old north-band position resolves to safe ground")
	if render:
		for month in [4,7,10,1]:
			world.month=month;world.update_light()
			for i in 4:await process_frame
			await RenderingServer.frame_post_draw
			check(viewport.get_texture().get_image().save_png(folder+"world_month_"+str(month)+".png")==OK,"save engine overview month "+str(month))
		world.month=7;world.update_light();world.scale=Vector2.ONE;world.position=Vector2(-2000,0)
		for i in 4:await process_frame
		await RenderingServer.frame_post_draw
		check(viewport.get_texture().get_image().save_png(folder+"north_detail.png")==OK,"save north mountain detail")
		world.queue_free();await process_frame
		var map=MapView.new();map.houses=JSON.parse_string(FileAccess.get_file_as_string("res://ayu_home/v4/assets/village/houses.json"));map.state=MapState.new();map.size=Vector2(1000,980);viewport.add_child(map)
		for winter in [false,true]:
			map.state.winter=winter;map.queue_redraw()
			for i in 4:await process_frame
			await RenderingServer.frame_post_draw
			check(viewport.get_texture().get_image().save_png(folder+("map_winter.png" if winter else "map_summer.png"))==OK,"save same-helper map "+str(winter))
	viewport.queue_free();await process_frame
	FileAccess.open(folder+("render.json" if render else "navigation.json"),FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"failed":failed,"mode":"engine preview/navigation only; no save or real input"},"\t"))
	quit(1 if failed else 0)
