extends SceneTree
const Main=preload("res://scripts/main.gd")
var out:="res://ayu_home/v3/evidence/runtime/"
func _initialize() -> void:call_deferred("run")
func run() -> void:
	for dim in [Vector2i(540,960),Vector2i(1170,2532)]:
		var vp:=SubViewport.new();vp.size=dim;vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp)
		var m=Main.new();m.fast=true;vp.add_child(m)
		for i in 600:
			if m.state=="title":break
			await process_frame
		m.nickname="小李";m.cloud.fake_no_news=true
		m.ensure_canvas("backhall");m._show_canvas("backhall");m._goto("backhall")
		await create_timer(1).timeout
		var b=m.backhall;b.walking_enabled=false;b.lounge.frozen=true
		m.dialog.visible=false;m.hint.visible=false
		b.reset_to(Vector2(1032,540));b.cam.reset_smoothing()
		await create_timer(1).timeout
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(out+"roman-%d.png"%dim.x)
		print("ROMAN SHOT ",dim," camera ",b.cam.zoom)
		vp.queue_free();await process_frame
	quit()
