extends SceneTree
## GPU-rendered native phone resolution, independent of the physical Mac screen limit.
const Home = preload("res://ayu_home/home.gd")
func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var dimensions := Vector2i(540,960)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ayu-render-size="):
			var value := arg.get_slice("=",1)
			dimensions = Vector2i(int(value.get_slice("x",0)),int(value.get_slice("x",1)))
	var surface := SubViewport.new()
	surface.size = dimensions
	surface.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	surface.transparent_bg = false
	surface.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(surface)
	var home := Home.new()
	var failing := "--ayu-fail-assets" in OS.get_cmdline_user_args()
	if failing: home.asset_test_config = {"files":{"missing-test.png":{"bytes":1,"sha256":"invalid","file_id":""}}}
	surface.add_child(home)
	if failing:
		await create_timer(2.5).timeout
		await RenderingServer.frame_post_draw
		var output := "/private/tmp/ayu-assets-failed.png"
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--ayu-screenshot="): output = arg.substr(17)
		surface.get_texture().get_image().save_png(output)
		print("AYU_FAILURE_CAPTURE ",output," size=",dimensions)
		quit()
