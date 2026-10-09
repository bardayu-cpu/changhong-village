extends SceneTree
const NewHome=preload("res://ayu_home/v4/home.gd")
const OldHome=preload("res://ayu_home/v3/home.gd")
var records:Array=[]
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var out:="res://ayu_home/v4/evidence/clarity/";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	for height in [960,1168]:
		for version in [3,4]:
			var vp:=SubViewport.new();vp.size=Vector2i(540,height);vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp)
			if height==1168:vp.size=Vector2i(1170,2532);vp.size_2d_override=Vector2i(540,1168);vp.size_2d_override_stretch=true
			var h=NewHome.new() if version==4 else OldHome.new();h.save_path="/private/tmp/ayu-comparison-v"+str(version)+".json";vp.add_child(h);await process_frame;h.set_process(false);h.close_modal();h.set_test_clock(12.25);h.enter_room("dining",false);h.player.position=Vector2(262,318)
			# A declared calibration view: identical camera and standing coordinate.
			# It compares source detail rather than each version's different camera clamp.
			h.world.effects_enabled=false;h.world.update_light();h.world.set_process(false)
			var center:=Vector2(185,300);h.world.scale=Vector2(2,2);h.world.position=Vector2(540,height)*.5-center*2;h.markers.visible=false
			for a in h.world.actors.get_children():a.set_process(false)
			for i in 4:await process_frame
			await process_frame;RenderingServer.force_draw(false);vp.get_texture().get_image().save_png(out+"dining-v"+str(version)+"-"+str(height)+".png")
			records.append({"version":version,"viewport":[vp.size.x,vp.size.y],"logical_viewport":[540,height],"standing":[262,318],"camera":[185,300],"zoom":2,"nearest_sampling":true,"lighting_and_effects":"off for calibrated comparison only"});h.stop_audio();vp.queue_free();await process_frame
	var f:=FileAccess.open(out+"capture-parameters.json",FileAccess.WRITE);f.store_string(JSON.stringify(records,"  "));f.close();print("RESULT PASS calibrated v3/v4 clarity captures");quit()
