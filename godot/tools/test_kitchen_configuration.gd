extends SceneTree
const Rules = preload("res://scripts/kitchen/kitchen_rules.gd")
const KitchenPanel = preload("res://scripts/kitchen/kitchen_panel.gd")
const Save = preload("res://scripts/games/game_save.gd")
var ok := true
func check(label: String, value: bool) -> void:
    print(("PASS " if value else "FAIL ")+label)
    ok = ok and value
func descendants(node: Node) -> Array:
    var out: Array = []
    for child in node.get_children():
        out.append(child)
        out.append_array(descendants(child))
    return out
func _initialize() -> void: call_deferred("run")
func run() -> void:
    var recipes: Array = Rules.RECIPES.duplicate(true)
    var ingredients: Array = []
    for i in 9: ingredients.append("测试食材%d" % i)
    recipes.append({"id":"configuration_test","name":"配置测试菜","ingredients":ingredients,"variants":[ingredients],"seconds":1.0,"window":5.0,"coins":11,"unlock":1,"visual_group":"configuration_test"})
    var people: Array = []
    for i in 5: people.append({"id":"server_test_%d" % i,"gender":"male" if i%2 == 0 else "female"})
    var config := {"recipes":recipes,"characters":people}
    var g = Rules.new()
    check("新菜谱与五种身份可只用配置扩展",g.configure(config))
    check("无效配置不污染原配置",not g.configure({"recipes":[],"characters":people}) and g.recipe_catalog.size() == recipes.size())
    g.start(30,101)
    check("高级菜池保留所有菜系与新菜",g.available().size() == recipes.filter(func(r): return bool(r.get("enabled",true))).size() and g.recipe_data("pork").name == "红烧肉")
    var seen: Dictionary = {}
    for i in 100:
        g.orders.clear()
        g.add_order()
        seen[g.orders[0].character] = true
        check("动态订单槽仍最多三菜",g.orders[0].dishes.size() in [1,2,3])
    check("身份不绑定三个位或固定男女图",seen.size() == 5)
    var w = Save.new()
    w.local_path = "user://kitchen_test_配置测试-wallet.tmp.json"
    var p = KitchenPanel.new()
    p.saved_path = "user://kitchen_test_配置测试-progress.tmp.json"
    check("界面接收同一配置",p.rules.configure(config))
    root.add_child(p)
    p.open(w,load("res://assets/fonts/fusion-pixel-12px-proportional-zh_hans.otf.woff2"))
    p.set_process(false)
    p._start(30)
    p.rules.spawn_in = 1000.0
    p.rules.orders = [{"id":100,"slot":0,"character":"server_test_4","dishes":[{"recipe":"configuration_test","ingredients":ingredients,"done":false}],"left":70.0,"total":70.0}]
    check("新菜照单绑定九种配料",p.rules.choose_order_dish(0,100,0))
    p._render()
    await process_frame
    check("原料槽一次显示八项",p._tray_ingredients().size() == 8)
    for i in 8: p.rules.add_ingredient(0,ingredients[i])
    p._render()
    await process_frame
    check("超过八项可继续配置加料",p._tray_ingredients() == ["测试食材8"])
    var nodes := descendants(p.panel)
    var last_button: Button
    for node in nodes:
        if node is Button and node.get_meta("kitchen_action","") == "测试食材8": last_button = node
    check("后续配料有实际命中按钮",last_button != null)
    if last_button: last_button.pressed.emit()
    check("缺素材保持显式缺项",nodes.any(func(n): return n.get_meta("asset_missing","") == "character/server_test_4/confirm"))
    check("运行页面不再从母版裁取移动精灵",nodes.all(func(n): return not n is Polygon2D))
    p.rules.tick(1.0)
    check("配置菜可盛出交付且使用配置奖励",p.rules.serve_pot(0) and p.rules.deliver_auto() and w.coins == 11 and p.rules.orders.is_empty())
    p.queue_free()
    await process_frame
    for path in [w.local_path,"user://kitchen_test_配置测试-progress.tmp.json"]:
        if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    print("RESULT ","PASS" if ok else "FAIL")
    quit(0 if ok else 1)
