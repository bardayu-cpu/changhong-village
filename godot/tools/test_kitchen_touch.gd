extends SceneTree
const KitchenPanel = preload("res://scripts/kitchen/kitchen_panel.gd")
const Save = preload("res://scripts/games/game_save.gd")
var p
var ok := true
var checks := 0
var evidence_dir := "user://kitchen_test_v3_evidence"
func check(label: String, yes: bool) -> void:
    checks += 1
    print(("PASS " if yes else "FAIL ")+label)
    ok = ok and yes
func _initialize() -> void: call_deferred("run")
func descendants(node: Node) -> Array:
    var out: Array = []
    for child in node.get_children():
        if child.is_queued_for_deletion(): continue
        out.append(child)
        out.append_array(descendants(child))
    return out
func tap_screen(screen: Vector2) -> void:
    var event := InputEventScreenTouch.new()
    event.position = screen
    event.index = 0
    event.pressed = true
    root.push_input(event)
    await process_frame
    event = event.duplicate()
    event.pressed = false
    root.push_input(event)
    await process_frame
func tap_source(pos: Vector2) -> void:
    var screen: Vector2 = p.panel.position+p.panel.scale*(p.playfield.scale*pos)
    await tap_screen(screen)

func run() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence_dir))
    root.size = Vector2i(540,960)
    root.content_scale_size = Vector2i(540,960)
    var w = Save.new()
    w.local_path = "user://test_kitchen_touch_wallet.json"
    p = KitchenPanel.new()
    p.saved_path = "user://test_kitchen_touch_progress.json"
    root.add_child(p)
    p.open(w,load("res://assets/fonts/fusion-pixel-12px-proportional-zh_hans.otf.woff2"))
    p.set_process(false)
    if "--capture" in OS.get_cmdline_user_args(): p.set_meta("capture_mode",true)
    for dimensions in [Vector2i(390,844),Vector2i(540,960),Vector2i(1080,1920)]:
        root.size = dimensions
        root.content_scale_size = dimensions
        await process_frame
        p._start(1)
        p.rules.orders[0].dishes = [{"recipe":"beef","ingredients":["汤底","牛肉","葱花"],"done":false}]
        p.rules.orders[0].age = 1.0
        p._render()
        await process_frame
        var before_coins: int = w.coins
        var hits: Array = descendants(p.panel).filter(func(n): return n is Button and n.has_meta("order_dish"))
        check("菜单保留可直接点击菜项 "+str(dimensions),hits.size() == 1)
        check("见习仍只有一口可用锅另两口视觉锁定 "+str(dimensions),p.rules.pots.size() == 1 and descendants(p.panel).filter(func(n): return n.has_meta("locked_station")).size() == 2)
        if hits.is_empty():
            print("RESULT FAIL")
            quit(1)
            return
        var hit: Button = hits[0]
        var transform := hit.get_global_transform_with_canvas()
        check("菜项触摸区域至少44像素 "+str(dimensions),hit.size.x*transform.x.length() >= 44 and hit.size.y*transform.y.length() >= 44)
        await tap_screen(transform*(hit.size*0.5))
        check("真实命中木菜图卡无图层抢点击 "+str(dimensions),p.rules.pots[0].state == "prep")
        check("加料时没有可点击盛出按钮 "+str(dimensions),descendants(p.panel).all(func(n): return not n.has_meta("serve_pot_index")))
        for name in ["汤底","牛肉","葱花"]:
            var boxes: Array = descendants(p.panel).filter(func(n): return n is Button and n.get_meta("kitchen_action","") == name)
            check("木盒触摸区至少44像素："+name+str(dimensions),boxes.size() == 1 and boxes[0].get_global_rect().size.x >= 44 and boxes[0].get_global_rect().size.y >= 44)
            if boxes.size() == 1: await tap_screen(boxes[0].get_global_transform_with_canvas()*(boxes[0].size*0.5))
        check("真实命中3个木辅菜盒 "+str(dimensions),p.rules.pots[0].state == "cooking")
        check("烹饪时没有提前盛出按钮 "+str(dimensions),descendants(p.panel).all(func(n): return not n.has_meta("serve_pot_index")))
        p.rules.tick(8)
        p._render()
        await process_frame
        var serving: Array = descendants(p.panel).filter(func(n): return n is Button and n.get_meta("serve_pot_index",-1) == 0)
        check("熟菜状态牌变成本锅盛出按钮 "+str(dimensions),serving.size() == 1)
        if serving.is_empty():
            print("RESULT FAIL")
            quit(1)
            return
        var serving_hit: Button = serving[0]
        check("盛出按钮触摸宽高至少44像素 "+str(dimensions),serving_hit.get_global_rect().size.x >= 44 and serving_hit.get_global_rect().size.y >= 44)
        await tap_screen(serving_hit.get_global_transform_with_canvas()*(serving_hit.size*0.5))
        check("真实命中锅下盛出且未发币 "+str(dimensions),p.rules.plates.size() == 1 and w.coins == before_coins)
        var plates: Array = descendants(p.panel).filter(func(n): return n is Button and n.has_meta("plate_id"))
        check("盛盘在服务员前且触摸至少44像素 "+str(dimensions),plates.size() == 1 and plates[0].position.y >= 640 and plates[0].position.y+plates[0].size.y <= 780 and plates[0].get_global_rect().size.x >= 44 and plates[0].get_global_rect().size.y >= 44)
        if plates.size() == 1:
            await tap_screen(plates[0].get_global_transform_with_canvas()*(plates[0].size*0.5))
        check("服务台菜盘可真实触摸选择 "+str(dimensions),p.selected_plate == int(p.rules.plates[0].id))
        await tap_source(p.Art.UI_REGIONS.deliver.get_center())
        check("真实交菜发3金 "+str(dimensions),p.rules.plates.is_empty() and w.coins == before_coins+3)
    var evidence := FileAccess.open(evidence_dir+"/触摸检查结果.json",FileAccess.WRITE)
    evidence.store_string(JSON.stringify({"passed":ok,"checks":checks,"test_type":"Actual InputEventScreenTouch dispatch in headless Godot","native_gpu":false,"dimensions":[[390,844],[540,960],[1080,1920]]},"  "))
    p.queue_free()
    await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(w.local_path))
    print("RESULT ","PASS" if ok else "FAIL")
    quit(0 if ok else 1)
