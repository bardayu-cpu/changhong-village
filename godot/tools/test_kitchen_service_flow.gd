extends SceneTree
const KitchenPanel = preload("res://scripts/kitchen/kitchen_panel.gd")
const Rules = preload("res://scripts/kitchen/kitchen_rules.gd")
const Art = preload("res://scripts/kitchen/kitchen_art.gd")
const Save = preload("res://scripts/games/game_save.gd")
var ok := true
func check(label: String, value: bool) -> void:
    print(("PASS " if value else "FAIL ")+label)
    ok = ok and value
func _initialize() -> void: call_deferred("run")
func order_for(g, rows: Array, id: int, identity := "server_male_1", slot := 0) -> Dictionary:
    var dishes: Array = []
    for row in rows: dishes.append({"recipe":row.id,"ingredients":row.ingredients.duplicate(),"done":false})
    return {"id":id,"slot":slot,"character":identity,"dishes":dishes,"left":200.0,"total":200.0,"age":1.0}
func cook(g, order: Dictionary, index: int) -> bool:
    if not g.choose_order_dish(0,order.id,index): return false
    for ingredient in order.dishes[index].ingredients:
        if not g.add_ingredient(0,ingredient): return false
    g.tick(float(g.recipe_data(order.dishes[index].recipe).seconds)+0.01)
    return g.serve_pot(0)
func dish_keys(layer: Node) -> Array:
    var out: Array = []
    for child in layer.get_children():
        if not child.is_queued_for_deletion() and str(child.get_meta("asset_key","")).begins_with("dish/"): out.append(child.get_meta("asset_key"))
    return out
func run() -> void:
    var g = Rules.new()
    g.start(30,87)
    g.target = 100
    g.spawn_in = 9999.0
    var reward := [0]
    g.delivered.connect(func(n): reward[0]+=n)
    for row in g.available():
        g.orders = [order_for(g,[row],100+g.completed)]
        var order: Dictionary = g.orders[0]
        var initial: int = reward[0]
        var success: bool = cook(g,order,0) and g.deliver_auto()
        check("实际加料熟制盛菜交付："+str(row.name),success and g.orders.is_empty() and g.plates.is_empty() and reward[0]-initial == int(row.coins))
    var viewport := SubViewport.new()
    viewport.size = Vector2i(540,960)
    root.add_child(viewport)
    var p = KitchenPanel.new()
    p.saved_path = "user://kitchen_test_service-progress.tmp.json"
    p.set_meta("capture_mode",true)
    viewport.add_child(p)
    var wallet = Save.new()
    wallet.local_path = "user://kitchen_test_service-wallet.tmp.json"
    p.open(wallet,load("res://assets/fonts/fusion-pixel-12px-proportional-zh_hans.otf.woff2"))
    p.set_process(false)
    p._start(30)
    p.rules.spawn_in = 9999.0
    p.rules.target = 100
    var rows: Array = p.rules.available().slice(0,3)
    for identity in p.rules.character_catalog:
        for action in ["waiting","confirm","carrying","leaving"]:
            var actor := Control.new()
            p.playfield.add_child(actor)
            var order := order_for(p.rules,rows,44,identity.id)
            order.action = action
            p._refresh_actor_action(actor,order,0)
            check("现代制服身份动作与空托盘绑定："+str(identity.id)+"/"+action,actor.get_meta("character_asset") == "character/"+str(identity.id)+"/"+action and actor.get_child(0) is TextureRect and bool(Art.visual_assets[actor.get_meta("character_asset")].approved) and Art.visual_assets[actor.get_meta("character_asset")].wardrobe == "modern_hotel" and Art.visual_assets[actor.get_meta("character_asset")].tray_empty)
            var layer := Control.new()
            p.playfield.add_child(layer)
            order.dishes[0].done = true
            order.dishes[1].done = true
            order.dishes[2].done = true
            p._refresh_tray(layer,order,0)
            var surface: Rect2 = layer.get_meta("tray_surface_rect")
            check("动态三菜沿当前动作托盘对齐："+str(identity.id)+"/"+action,dish_keys(layer).size() == 3 and layer.get_children().all(func(d): return d.has_meta("tray_dish") and is_equal_approx(d.position.y+d.size.y,surface.end.y) and d.position.x >= surface.position.x and d.position.x+d.size.x <= surface.end.x))
            layer.queue_free()
            actor.queue_free()
    p.rules.orders = [order_for(p.rules,rows,400)]
    p._render()
    await process_frame
    check("未交菜托盘为空",dish_keys(p.figures[0].overlay).is_empty())
    for index in 3:
        var order: Dictionary = p.rules.orders[0]
        check("分次交付第%d道" % (index+1),cook(p.rules,order,index) and p.rules.deliver_auto())
        p._render()
        await process_frame
        check("已收菜单无状态文字，每位等待服务员只显示一次耐心计时",p.order_labels.all(func(entry): return entry.label.text.begins_with("◴") if entry.show_patience and not entry.dish.done else entry.label.text.is_empty()) and p.order_labels.filter(func(entry): return not entry.label.text.is_empty()).size() == p.rules.orders.size())
        var layer: Control = p.figures[0].overlay if index < 2 else p.departures[0].overlay
        var expected: Array = rows.slice(0,index+1).map(func(row): return "dish/"+str(row.id))
        check("托盘只显示已收齐的%d份真实菜" % (index+1),dish_keys(layer) == expected)
        check("未收齐留队，收齐立即移出队列",p.rules.orders.size() == (1 if index < 2 else 0))
    p.rules.paused = true
    p._update_waiter_motion(1.0)
    check("暂停不推进离场",p.departures.size() == 1 and p.departures[0].elapsed == 0.0)
    p.rules.paused = false
    p._update_waiter_motion(0.3)
    await process_frame
    check("收齐后切换离场并保持菜品叠层",p.departures[0].order.action == "leaving" and dish_keys(p.departures[0].overlay).size() == 3)
    p._update_waiter_motion(0.7)
    await process_frame
    check("离场结束清理人物与菜盘",p.departures.is_empty())
    p.rules.orders = [order_for(p.rules,[rows[0]],500)]
    p.rules.orders[0].left = 0.1
    p.rules.tick(0.2)
    p._render()
    await process_frame
    check("超时移出队列，不给未交的菜和金币",p.rules.orders.is_empty() and p.departures.size() == 1 and p.departures[0].order.impatient and dish_keys(p.departures[0].overlay).is_empty())
    p.departures.clear()
    p.rules.orders = [order_for(p.rules,[rows[0]],600)]
    p.rules.target = p.rules.completed+1
    check("最后一道交付",cook(p.rules,p.rules.orders[0],0) and p.rules.deliver_auto())
    p._render()
    await process_frame
    p._process(0.2)
    check("最终结算等待端菜离场",not p.round_saved and not p.departures.is_empty() and not p.rules.active)
    p._process(0.8)
    await process_frame
    check("离场完成进入结算",p.round_saved and p.departures.is_empty())
    p.queue_free()
    await process_frame
    print("RESULT ","PASS" if ok else "FAIL")
    quit(0 if ok else 1)
