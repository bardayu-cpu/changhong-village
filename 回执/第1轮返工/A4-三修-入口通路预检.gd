extends SceneTree
const World=preload("res://ayu_home/v4/world.gd")
const Actor=preload("res://ayu_home/v4/actor.gd")
class Harness:
	extends "res://ayu_home/v4/home.gd"
	var header_height:=100.0
	func _ready() -> void:pass
	func _process(_dt:float) -> void:pass
	func _exit_tree() -> void:pass
	func hud_bottom() -> float:return header_height
var failures:Array=[]
func check(value:bool,label:String) -> void:
	if not value:failures.append(label)
func rect_values(r:Rect2) -> Array:return [r.position.x,r.position.y,r.size.x,r.size.y]
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var viewport:=SubViewport.new();root.add_child(viewport)
	var home:=Harness.new();viewport.add_child(home);home.area="my_cabin"
	home.scene_frame=Control.new();home.scene_frame.clip_contents=true;home.add_child(home.scene_frame)
	home.world=World.new();home.scene_frame.add_child(home.world);home.world.set_process(false);home.world.load_room("my_cabin")
	home.player=Actor.new();home.world.actors.add_child(home.player);home.player.setup("visitor");home.player.set_process(false)
	var arrival:Vector2=home.world.spawn()
	var door_inside:Vector2=home.world.nearest(Vector2(347,499))
	var entrance_path:PackedVector2Array=home.world.path(door_inside,arrival)
	check(not entrance_path.is_empty(),"door_to_arrival_path")
	var length:=0.0
	for n in entrance_path.size():
		check(home.world.passable(entrance_path[n]),"entry_passable_"+str(n))
		if n>0:length+=entrance_path[n].distance_to(entrance_path[n-1])
	check(is_equal_approx(length,door_inside.distance_to(arrival)),"entry_is_straight_continuous_corridor")
	var paths:Dictionary={}
	for spot in home.world.cfg.hotspots+home.world.cfg.doors:
		var approach:=World.v(spot.approach)
		check(home.world.passable(approach),"approach_passable_"+str(spot.id))
		var route:PackedVector2Array=home.world.path(arrival,approach)
		check(not route.is_empty(),"reachable_"+str(spot.id))
		paths[spot.id]=route
	for n in [0,1]:check(home.world.passable(World.v(home.world.cfg.resident.schedule[n].pos)),"resident_work_position_"+str(n))
	var entries:Array=[];var walks:Array=[]
	for window in [Vector2i(540,960),Vector2i(1280,720)]:
		viewport.size=window;await process_frame
		for header in [88.0,100.0]:
			home.header_height=header;home.player.position=arrival;home.player.action="idle";home.player.face="up";home.player.pose();home.camera=home.room_camera_target();home.layout_world()
			var xf:Transform2D=home.world.get_global_transform_with_canvas()
			var safe:=Rect2(20,125,window.x-40,window.y-310)
			var table_screen:Rect2=xf*Rect2(136,212,225,162)
			var actor_screen:Rect2=xf*Rect2(arrival-Vector2(32,84),Vector2(64,84))
			check(safe.encloses(table_screen),"entry_table_"+str(window)+"_"+str(header))
			check(safe.encloses(actor_screen),"entry_actor_"+str(window)+"_"+str(header))
			check(is_equal_approx(home.view_scale,2.0),"actor_scale_"+str(window))
			entries.append({"window":[window.x,window.y],"header":header,"center":[home.world.camera_center.x,home.world.camera_center.y],"table":rect_values(table_screen),"actor":rect_values(actor_screen),"table_visible":safe.encloses(table_screen),"actor_visible":safe.encloses(actor_screen),"nominal_actor_height":84*home.view_scale})
		home.header_height=100.0
		for id in paths:
			home.player.position=arrival;home.player.route=paths[id];home.player.destination_action="idle";home.player.destination_face="up";home.camera=home.room_camera_target()
			var steps:=0;var route_ok:=true;var visible:=true
			while not home.player.route.is_empty() and steps<1800:
				home.player.move_along(1.0/60.0,135.0);home.player.pose();home.camera=home.camera.lerp(home.room_camera_target(),1-exp(-7.0/60.0));home.layout_world()
				route_ok=route_ok and home.world.passable(home.player.position)
				var xf:Transform2D=home.world.get_global_transform_with_canvas()
				var actor_box:Rect2=xf*Rect2(home.player.position-Vector2(20,84),Vector2(40,84))
				var frame:=Rect2(home.scene_frame.position,home.scene_frame.size)
				visible=visible and frame.grow(.5).encloses(actor_box);steps+=1
			check(route_ok and home.player.route.is_empty(),"walk_route_"+id+"_"+str(window))
			check(visible,"walk_visible_"+id+"_"+str(window))
			walks.append({"window":[window.x,window.y],"target":id,"steps":steps,"continuous_passable":route_ok,"finished":home.player.route.is_empty(),"actor_visible":visible})
	var samples:=[]
	for room in ["living","v_h3","v_h3_up","v_h5","v_mayor","v_mayor_up"]:
		home.area=room;home.player.position=Vector2(280,350)
		var unchanged:bool=home.room_camera_target()==home.player.position-Vector2(0,65)
		check(unchanged,"other_room_camera_"+room);samples.append({"room":room,"target_unchanged":unchanged})
	var result:={"mode":"Native headless path, Actor.move_along, camera and sprite-bound preflight; no GUI or save. Visual style/corner recognition and actual doorway experience await C3.","failures":failures,"arrival":[arrival.x,arrival.y],"old_door_inside":[door_inside.x,door_inside.y],"entry_path_world_length":length,"entries":entries,"walks":walks,"unaffected_room_targets":samples}
	FileAccess.open("res://../回执/第1轮返工/A4-三修-入口通路预检.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n")
	home.free();viewport.free();print("A4_THIRD_PRECHECK failures=",failures.size()," ",failures)
	quit(0 if failures.is_empty() else 1)
