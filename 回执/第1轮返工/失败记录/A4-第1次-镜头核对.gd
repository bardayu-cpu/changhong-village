extends SceneTree
class FrameHarness:
	extends "res://ayu_home/v4/home.gd"
	func _ready() -> void:pass
	func _process(_dt:float) -> void:pass
	func _exit_tree() -> void:pass
	func hud_bottom() -> float:return 100.0
var failed:=0
var rows:Array=[]
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var definitions:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://ayu_home/v4/assets/rooms.json")).rooms
	var vp:=SubViewport.new();root.add_child(vp)
	var h:=FrameHarness.new();vp.add_child(h)
	h.scene_frame=Control.new();h.add_child(h.scene_frame)
	h.world=preload("res://ayu_home/v4/world.gd").new();h.scene_frame.add_child(h.world);h.world.set_process(false)
	for screen in [Vector2i(540,960),Vector2i(360,800),Vector2i(1280,720)]:
		vp.size=screen;await process_frame
		for area in ["v_h3","v_h3_up","v_h5","v_mayor","v_mayor_up","my_cabin"]:
			h.area=area;h.world.cfg=definitions[area];h.camera=Vector2(40,510);h.layout_world()
			var room_size:Vector2=Vector2(h.world.cfg.size[0],h.world.cfg.size[1])
			var bounds:=Rect2(h.world.position,room_size*h.world.scale)
			var frame:=Rect2(Vector2.ZERO,h.scene_frame.size)
			var first:Vector2=h.world.position
			h.camera=Vector2(460,110);h.layout_world()
			var fits:bool=frame.encloses(bounds) and first==h.world.position
			if not fits:failed+=1
			rows.append({"room":area,"viewport":[screen.x,screen.y],"full_room_inside_scene_frame":fits,"stable_when_player_camera_moves":first==h.world.position,"scale":h.view_scale,"nominal_actor_screen_height":84*h.view_scale})
	var out:=FileAccess.open("res://../回执/第1轮返工/A4-首修镜头核对.json",FileAccess.WRITE)
	out.store_string(JSON.stringify({"mode":"headless actual layout_world with memory-only viewport fixtures; no save opened","failures":failed,"samples":rows,"pending":"C3 real first-entry comparison and A2 common on-screen actor size; no visual acceptance claimed"},"\t")+"\n");out.close()
	h.queue_free();vp.queue_free();await process_frame
	print("A4_CAMERA ","PASS" if failed==0 else "FAIL"," ",rows.size()," room/viewport samples; actual visual and actor-size acceptance pending")
	quit(0 if failed==0 else 1)
