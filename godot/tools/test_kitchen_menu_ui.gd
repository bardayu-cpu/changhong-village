extends SceneTree
const PanelScript = preload("res://scripts/kitchen/kitchen_panel.gd")
const Save = preload("res://scripts/games/game_save.gd")
const Capture = preload("res://tools/kitchen_software_capture.gd")
var p
var viewport: SubViewport
var ok := true
var checks := 0
var output := "user://kitchen_test_v3_evidence"
func check(label: String, value: bool) -> void:
    checks += 1
    ok = ok and value
    print(("PASS " if value else "FAIL ")+label)
func nodes(node: Node) -> Array:
    var out: Array = []
    for child in node.get_children():
        if child.is_queued_for_deletion(): continue
        out.append(child)
        out.append_array(nodes(child))
    return out
func cards() -> Array:
    return nodes(p.panel).filter(func(n): return n.has_meta("order_card"))
func card_for(id: int, index: int):
    var hits: Array = nodes(p.panel).filter(func(n): return n is Button and n.get_meta("order_id",-1) == id and n.get_meta("dish_index",-1) == index)
    return hits[0].get_parent() if hits.size() == 1 else null
func textless_menu() -> bool:
    var boards: Array = nodes(p.panel).filter(func(n): return n.has_meta("waiter_order_board"))
    return boards.all(func(board): return nodes(board).filter(func(n): return n is Label).all(func(label): return label.has_meta("order_reward") or label.has_meta("waiter_patience_timer")))
func order_for(id: int, slot: int, recipes: Array) -> Dictionary:
    var dishes: Array = []
    for recipe in recipes:
        var row: Dictionary = p.rules.recipe_data(recipe)
        dishes.append({"recipe":recipe,"ingredients":row.ingredients.duplicate(),"done":false})
    return {"id":id,"slot":slot,"character":["server_male_1","server_female_2","server_female_3"][slot],"dishes":dishes,"left":200.0,"total":200.0,"age":1.0}
func press_dish(id: int, index: int) -> void:
    var hits: Array = nodes(p.panel).filter(func(n): return n is Button and n.get_meta("order_id",-1) == id and n.get_meta("dish_index",-1) == index)
    if hits.size() == 1: hits[0].pressed.emit()
    else: check("找到唯一菜单操作",false)
    await process_frame
func press_pot(index: int) -> void:
    var hits: Array = nodes(p.panel).filter(func(n): return n is Button and n.get_meta("pot_index",-1) == index)
    if hits.size() == 1: hits[0].pressed.emit()
    else: check("找到唯一锅操作",false)
    await process_frame
func screenshot(name: String) -> void:
    var gpu := "--gpu-capture" in OS.get_cmdline_user_args()
    var image: Image
    if gpu:
        await process_frame
        await RenderingServer.frame_post_draw
        image = viewport.get_texture().get_image()
    else:
        image = Capture.new().capture(p,viewport.size)
    image.save_png(ProjectSettings.globalize_path(output+"/"+name+("-原生GPU.png" if gpu else "-CPU诊断.png")))
func _initialize() -> void: call_deferred("run")
func run() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
    viewport = SubViewport.new()
    viewport.size = Vector2i(540,960)
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)
    p = PanelScript.new()
    p.set_meta("capture_mode",true)
    p.saved_path = "user://test_menu_ui_progress.json"
    viewport.add_child(p)
    var wallet = Save.new()
    wallet.local_path = "user://test_menu_ui_wallet.json"
    p.open(wallet,load("res://assets/fonts/fusion-pixel-12px-proportional-zh_hans.otf.woff2"))
    p.set_process(false)
    p._start(30)
    p.rules.target = 999
    p.rules.spawn_in = 9999.0
    p.rules.orders = [order_for(101,0,["beef"]),order_for(102,1,["yeerba","ice_jelly"]),order_for(103,2,["ice_jelly","beef","yeerba"])]
    p._render()
    await process_frame
    var all: Array = nodes(p.panel)
    var boards: Array = all.filter(func(n): return n.has_meta("waiter_order_board"))
    check("三位服务员六道菜全部可直接点",all.filter(func(n): return n is Button and n.has_meta("order_dish")).size() == 6)
    check("每道菜只有一张主菜图",cards().all(func(card): return nodes(card).filter(func(n): return n.has_meta("order_dish_picture")).size() == 1))
    check("每道菜在卡内展示真实组成材料",cards().all(func(card): return nodes(card).filter(func(n): return n.has_meta("ingredient_icon")).map(func(n): return str(n.get_meta("ingredient_icon"))) == card.get_meta("order_recipe_ingredients")))
    check("所有菜单不显示菜名原料名或说明",textless_menu())
    check("无旧详情文字栏",all.all(func(n): return not n.has_meta("order_detail_panel")))
    check("同一人多道菜并排不叠列",boards.all(func(board): return nodes(board).filter(func(n): return n.has_meta("order_card")).all(func(card): return is_equal_approx(card.position.y,0))))
    await press_pot(1)
    await press_dish(102,1)
    check("换锅点另一人的第二张菜图配方正确",p.selected_pot == 1 and p.rules.pots[1].recipe == "ice_jelly" and p.rules.pots[1].required == p.rules.orders[1].dishes[1].ingredients)
    check("选菜单不修改其他锅",p.rules.pots[0].state == "empty" and p.rules.pots[2].state == "empty")
    await press_pot(2)
    await press_dish(103,2)
    check("三道菜单第三张图可直接选",p.rules.pots[2].recipe == "yeerba" and p.rules.pots[2].order_id == 103 and p.rules.pots[2].dish_index == 2)
    await press_pot(1)
    for ingredient in p.rules.pots[1].required.duplicate(): p.rules.add_ingredient(1,ingredient)
    p.rules.tick(float(p.rules.recipe_data("ice_jelly").seconds)+0.01)
    var served: bool = p.rules.serve_pot(1)
    var delivered: bool = p.rules.deliver_auto()
    p._render()
    await process_frame
    check("真实做菜交付后已收卡只淡化且不可再点",served and delivered and p.rules.orders[1].dishes[1].done and nodes(p.panel).filter(func(n): return n is Button and n.get_meta("order_id",-1) == 102 and n.get_meta("dish_index",-1) == 1).all(func(n): return n.disabled and n.get_parent().modulate != Color.WHITE))
    check("交付后仍无菜单状态文字",textless_menu())
    check("每人整单只有一个等待计时",p.order_labels.size() == 3 and p.order_labels.all(func(entry): return entry.label.text.begins_with("◴")))
    p.rules.paused = true
    var patience: float = p.rules.orders[0].left
    p.rules.tick(5.0)
    p._update_live_labels()
    check("暂停不推进菜单耐心",p.rules.orders[0].left == patience)
    p.rules.paused = false
    p.rules.pots = p.rules.pots.map(func(_pot): return p.rules.empty_pot())
    p.departures.clear()
    p.selected_pot = 0
    var ingredients: Array = ["汤底","牛肉","葱花","香菜","辣椒","芝麻","鸭","鸡肉串"]
    for row in p.rules.recipe_catalog:
        if row.id == "beef":
            row.name = "清汤跷脚牛肉"
            row.ingredients = ingredients.duplicate()
    p.rules.orders = [order_for(201,0,["beef"]),order_for(202,1,["yeerba","ice_jelly"]),order_for(203,2,["ice_jelly","beef","yeerba"])]
    p._render()
    await process_frame
    var card: Control = card_for(201,0)
    var icons: Array = nodes(card).filter(func(n): return n.has_meta("ingredient_icon"))
    check("八原料按真实订单顺序全部显示",icons.map(func(n): return str(n.get_meta("ingredient_icon"))) == ingredients)
    check("八原料小图完全留在所属卡内",icons.all(func(n): return n.position.x >= 0 and n.position.y >= 0 and n.position.x+n.size.x <= card.size.x and n.position.y+n.size.y <= card.size.y))
    check("材料顺序元数据0到7完整",icons.map(func(n): return int(n.get_meta("ingredient_step"))) == range(8))
    check("六字菜名也不会出现为菜单文字",textless_menu() and nodes(p.panel).all(func(n): return not n.has_meta("order_dish_name")))
    for dimensions in [Vector2i(390,844),Vector2i(540,960),Vector2i(1080,1920)]:
        viewport.size = dimensions
        await process_frame
        p._render()
        await process_frame
        var controls: Array = nodes(p.panel).filter(func(n): return n.has_meta("waiter_order_board") or n.has_meta("order_card"))
        check("纯图菜单完全留在屏内："+str(dimensions),controls.all(func(n): return n.get_global_rect().position.x >= -0.01 and n.get_global_rect().position.y >= -0.01 and n.get_global_rect().end.x <= dimensions.x+0.01 and n.get_global_rect().end.y <= dimensions.y+0.01))
        var board_list: Array = nodes(p.panel).filter(func(n): return n.has_meta("waiter_order_board"))
        check("三人菜单不互相遮挡："+str(dimensions),not board_list[0].get_global_rect().intersects(board_list[1].get_global_rect()) and not board_list[1].get_global_rect().intersects(board_list[2].get_global_rect()))
        check("同单菜卡不互相遮挡："+str(dimensions),board_list.all(func(board):
            var items: Array = nodes(board).filter(func(n): return n.has_meta("order_card"))
            for index in items.size()-1:
                if items[index].get_global_rect().intersects(items[index+1].get_global_rect()): return false
            return true))
        check("菜卡主图均大于旧48源像素图："+str(dimensions),cards().all(func(c): return nodes(c).filter(func(n): return n.has_meta("order_dish_picture")).all(func(image): return image.size.x >= 82 and image.size.y >= (56 if c.get_meta("narrow_menu_rows",false) else 72))))
        check("每尺寸只有金币与时间文字："+str(dimensions),textless_menu())
        var hits: Array = nodes(p.panel).filter(func(n): return n is Button and n.has_meta("order_dish"))
        check("各尺寸菜图点击宽高至少44像素："+str(dimensions),hits.all(func(hit): return hit.get_global_rect().size.x >= 44 and hit.get_global_rect().size.y >= 44))
        check("三菜在390以2+1同时显示："+str(dimensions),cards().filter(func(c): return c.get_parent().get_meta("order_id",-1) == 203).all(func(c): return bool(c.get_meta("narrow_menu_rows",false)) == (dimensions.x == 390)))
        check("底部辅菜卡全部为木盒："+str(dimensions),nodes(p.panel).filter(func(n): return n.has_meta("ingredient_wood_box")).size() == p._tray_ingredients().size())
        check("空盘移到服务员前并在锅上方："+str(dimensions),nodes(p.panel).filter(func(n): return n.has_meta("serving_counter_plate")).all(func(n): return n.position.y >= 640 and n.position.y+n.size.y <= 780))
        check("每人前一个独立空盘："+str(dimensions),nodes(p.panel).filter(func(n): return n.has_meta("empty_counter_plate_slot")).map(func(n): return int(n.get_meta("empty_counter_plate_slot"))) == [0,1,2])
        check("每人的耐心条随实际等待比例："+str(dimensions),p.patience_bars.size() == 3 and p.patience_bars.all(func(entry): return is_equal_approx(entry.fill.size.x/float(entry.width),float(entry.order.left)/float(entry.order.total))))
        check("没熟时没有盛出按钮："+str(dimensions),nodes(p.panel).all(func(n): return not n.has_meta("serve_pot_index")))
        await screenshot("确认图菜单八原料-"+str(dimensions.x)+"x"+str(dimensions.y))
    p.rules.orders.clear()
    p._render()
    await process_frame
    check("订单全部离场后不留旧菜单",cards().is_empty() and p.order_labels.is_empty())
    var gpu := "--gpu-capture" in OS.get_cmdline_user_args()
    var f := FileAccess.open(output+("/原生适配检查结果.json" if gpu else "/检查结果.json"),FileAccess.WRITE)
    f.store_string(JSON.stringify({"passed":ok,"checks":checks,"renderer":"Godot native GPU viewport readback" if gpu else "CPU diagnostics; not GPU","native_gpu":gpu,"dimensions":[[390,844],[540,960],[1080,1920]]},"  "))
    p.queue_free()
    await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(wallet.local_path))
    print("RESULT ","PASS" if ok else "FAIL")
    quit(0 if ok else 1)
