extends SceneTree
const Home=preload("res://ayu_home/v2/home.gd")
var h
var vp:SubViewport
var index:=0
var clip:=""
var folder:="/private/tmp/ayu-v2-original-motion/"
func _initialize() -> void:call_deferred("run")
func frames(count:int) -> void:
	for i in count:
		await create_timer(.125).timeout
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(folder+clip+"-%04d.png"%index);index+=1
func new_clip(name:String) -> void:clip=name;index=0
func run() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	vp=SubViewport.new();vp.size=Vector2i(540,960);vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp)
	h=Home.new();h.save_path="/private/tmp/ayu-v2-motion-save.json";vp.add_child(h)
	h.set_test_clock(12.5);h.player.position=Home.World.v(h.world.spot("door").approach);h.camera=h.player.position-Vector2(0,170);h.layout()
	new_clip("entry");await frames(6);h.knock();await frames(9);h.admit();await frames(11);h.go("album");await frames(25)
	h.admitted=true;h.enter_room("living",false);h.set_test_clock(7)
	new_clip("living");await frames(5);h.player.route=h.world.path(h.player.position,Vector2(187,187));await frames(22);h.go("fish");await frames(18)
	h.interact("fish");await frames(18);h.player.destination_action="idle";h.go("sofa");await frames(20)
	h.set_test_clock(20);h.interact("tv");await frames(10);h.interact("lamp");await frames(7);h.interact("lamp");await frames(7)
	h.enter_room("dining",true);h.set_test_clock(12.5)
	new_clip("dining");await frames(12);h.go("cook");await frames(22);h.set_test_clock(7);await frames(10);h.set_test_clock(20);await frames(10);h.set_test_clock(23.5);await frames(10)
	print("MOTION DONE native 540x960 frames at 8 fps");quit()
