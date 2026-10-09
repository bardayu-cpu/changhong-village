extends SceneTree
const Home = preload("res://ayu_home/v2/home.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var dim:=Vector2i(540,960)
	var out:="/private/tmp/ayu-v2.png"
	var hold:=2.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--size="):var s:=arg.get_slice("=",1).split("x");dim=Vector2i(int(s[0]),int(s[1]))
		elif arg.begins_with("--out="):out=arg.substr(6)
		elif arg.begins_with("--hold="):hold=float(arg.get_slice("=",1))
	var viewport:=SubViewport.new();viewport.size=dim;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;viewport.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST;root.add_child(viewport)
	var h:=Home.new();viewport.add_child(h)
	await create_timer(hold).timeout
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--interact="):h.interact(arg.get_slice("=",1))
	await create_timer(.2).timeout
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(out)
	var state:={"area":h.area,"hour":h.hour,"month":h.month,"weather":h.weather,"viewport":[dim.x,dim.y],"player":[h.player.position.x,h.player.position.y],"camera":[h.camera.x,h.camera.y],"scale":h.view_scale,"actors":{}}
	for id in h.people:
		var a=h.people[id];state.actors[id]={"visible":a.visible,"action":a.action,"face":a.face,"foot":[a.position.x,a.position.y]}
	var f:=FileAccess.open(out+".json",FileAccess.WRITE);f.store_string(JSON.stringify(state,"  "));f.close()
	print("CAPTURE ",out);quit()
