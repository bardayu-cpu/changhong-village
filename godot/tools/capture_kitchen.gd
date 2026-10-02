extends SceneTree
const KitchenPanel = preload("res://scripts/kitchen/kitchen_panel.gd")
const Save = preload("res://scripts/games/game_save.gd")
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    root.content_scale_size = Vector2i(540,960)
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
    var w = Save.new()
    w.local_path = "user://kitchen_capture_wallet.json"
    var p = KitchenPanel.new()
    p.saved_path = "user://kitchen_capture_progress.json"
    var target := SubViewport.new()
    target.size = Vector2i(1170,2532) if "--long" in OS.get_cmdline_user_args() else Vector2i(540,960)
    target.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(target)
    target.add_child(p)
    p.open(w,load("res://assets/fonts/fusion-pixel-12px-proportional-zh_hans.otf.woff2"))
    p._start(8)
    p.set_process(false)
    var g = p.rules
    g.add_order()
    g.add_order()
    for i in 3:
        var id: String = ["beef","tofu","noodles"][i]
        g.choose(i,id)
        for ingredient in g.recipe(id).ingredients: g.add_ingredient(i,ingredient)
        g.heat(i,g.recipe(id).heat)
    g.tick(8)
    p._render()
    p._process(0.01)
    for i in 8: await process_frame
    await RenderingServer.frame_post_draw
    target.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../验收记录/厨房长屏运行.png" if "--long" in OS.get_cmdline_user_args() else "res://../验收记录/厨房原型运行.png"))
    print("CAPTURE OK")
    p.queue_free()
    await process_frame
    quit()
