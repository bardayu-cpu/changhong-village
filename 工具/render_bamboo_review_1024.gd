extends SceneTree
# 整屋美术预览：使用正式 World/Actor 渲染，不打开或修改任何游玩存档。
const World=preload("res://ayu_home/v4/world.gd")
const Actor=preload("res://ayu_home/v4/actor.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(540,960)
	var folder:=ProjectSettings.globalize_path("res://../测试数据/竹编静帧-1024/")
	DirAccess.make_dir_recursive_absolute(folder)
	var report:Array=[]
	for area in ["v_daba","living"]:
		var viewport:=SubViewport.new();viewport.world_2d=World2D.new()
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var world:=World.new();world.effects_enabled=false;world.hour=13;world.month=10;world.weather="clear";viewport.add_child(world);world.load_room(area)
		viewport.size=Vector2i(world.cfg.size[0],world.cfg.size[1])
		var visitor:=Actor.new();world.actors.add_child(visitor);visitor.preset=2;visitor.setup("visitor");visitor.position=world.spawn()
		for i in 3:await process_frame
		await RenderingServer.frame_post_draw
		var error:=viewport.get_texture().get_image().save_png(folder+area+".png")
		report.append({"room":area,"file":area+".png","error":error,"kind":"engine_room_art_preview_not_interactive_playtest","size":world.cfg.size})
		for spot in world.cfg.hotspots:
			if area!="v_daba" or spot.id!="tea_seat":continue
			visitor.action="sit";visitor.face="down";visitor.position=World.v(spot.seat)
			for i in 3:await process_frame
			await RenderingServer.frame_post_draw
			viewport.get_texture().get_image().save_png(folder+area+"_seat.png")
		viewport.queue_free();await process_frame
	FileAccess.open(folder+"预览说明.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("INTERIOR_PREVIEWS ",report.size());quit()
