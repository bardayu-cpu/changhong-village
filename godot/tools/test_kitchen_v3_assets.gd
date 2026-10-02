extends SceneTree
const KitchenPanel = preload("res://scripts/kitchen/kitchen_panel.gd")
const Rules = preload("res://scripts/kitchen/kitchen_rules.gd")
const Art = preload("res://scripts/kitchen/kitchen_art.gd")
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
    var g = Rules.new()
    g.start(30,777)
    check("全量本地基础菜12道按配置解锁",g.available().size() == 12)
    check("六个身份不是二十四张新人物",g.character_catalog.size() == 6 and g.character_catalog.filter(func(c): return c.gender == "female").size() == 3)
    for row in g.available():
        check("菜谱完整字段与原料图："+str(row.name),row.has("dish_id") and row.has("cooking_family") and row.has("station_id") and row.has("component_steps") and ResourceLoader.exists(str(row.finished_art)) and row.ingredients.all(func(i): return bool(Art.visual_assets.get("ingredient/"+str(i),{}).get("approved",false))))
    var w = Save.new()
    w.local_path = "user://kitchen_test_v3-wallet.tmp.json"
    var target := SubViewport.new()
    target.size = Vector2i(540,960)
    target.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(target)
    var p = KitchenPanel.new()
    p.saved_path = "user://kitchen_test_v3-progress.tmp.json"
    p.set_meta("capture_mode",true)
    target.add_child(p)
    p.open(w,load("res://assets/fonts/fusion-pixel-12px-proportional-zh_hans.otf.woff2"))
    p.set_process(false)
    p._start(12)
    p.rules.orders.clear()
    for slot in 3:
        var row: Dictionary = p.rules.available()[slot]
        var dishes: Array = []
        for i in slot+1:
            var chosen: Dictionary = p.rules.available()[slot+i]
            dishes.append({"recipe":chosen.id,"ingredients":chosen.ingredients.duplicate(),"done":false})
        p.rules.orders.append({"id":101+slot,"slot":slot,"character":"server_male_1" if slot == 0 else "server_female_2" if slot == 1 else "server_male_3","dishes":dishes,"left":70.0,"total":80.0,"age":1.0})
    p._render()
    await process_frame
    var nodes := descendants(p.panel)
    var characters: Array = nodes.filter(func(n): return n is TextureRect and str(n.get_meta("asset_key","")).begins_with("character/"))
    check("新现代服务员进入画面，古装路径不使用",characters.size() == 3 and characters.all(func(n): return Art.visual_assets[n.get_meta("asset_key")].wardrobe == "modern_hotel"))
    var character_slots: Array = characters
    var character_keys: Array = character_slots.map(func(n): return str(n.get_meta("asset_key","")))
    check("三位现代人物各用一个独立身份",character_slots.size() == 3 and character_keys[0] != character_keys[1] and character_keys[1] != character_keys[2] and character_keys[0] != character_keys[2])
    check("简洁菜单菜名在540宽至少14像素且不溢出",nodes.filter(func(n): return n.has_meta("order_dish_name")).all(func(n): return n.get_theme_font_size("font_size")*n.get_global_transform_with_canvas().x.length() >= 14.0 and n.get_theme_font("font").get_string_size(n.text,HORIZONTAL_ALIGNMENT_LEFT,-1,n.get_theme_font_size("font_size")).x <= n.size.x))
    check("锅状态和倒计时紧凑单行且在540宽至少18像素",p.timers.all(func(t): return t.label.get_theme_font_size("font_size")*t.label.get_global_transform_with_canvas().x.length() >= 18.0 and not "\n" in t.label.text))
    check("一二三道订单动态六个槽",nodes.filter(func(n): return n.has_meta("order_card")).size() == 6)
    check("成菜和配料均加载独立透明图",nodes.any(func(n): return str(n.get_meta("asset_key","")).begins_with("dish/")) and nodes.any(func(n): return n.has_meta("ingredient_icon") and n is TextureRect))
    check("炒锅仍不以含菜整锅冒充空锅",not Art.visual_assets["station/wok/body"].approved)
    check("端菜启用的是现代空托盘，菜层独立",Art.visual_assets["character/server_male_1/carrying"].approved and Art.visual_assets["character/server_male_1/carrying"].tray_empty and Art.visual_assets["character/server_male_1/carrying"].wardrobe == "modern_hotel")
    check("十二菜存在多种工位类型",g.available().any(func(r): return r.station_id == "grill") and g.available().any(func(r): return r.station_id == "cold_mix"))
    p.rules.orders.clear()
    var station_recipes := ["beef","yeerba","ice_jelly"]
    for slot in 3:
        var recipe: Dictionary = p.rules.recipe_data(station_recipes[slot])
        p.rules.orders.append({"id":201+slot,"slot":slot,"character":["server_male_1","server_female_2","server_female_3"][slot],"dishes":[{"recipe":recipe.id,"ingredients":recipe.ingredients.duplicate(),"done":false}],"left":70.0,"total":80.0,"age":1.0})
        p.rules.choose_order_dish(slot,201+slot,0)
    p._render()
    await process_frame
    var station_nodes: Array = descendants(p.panel).filter(func(n): return n is TextureRect and str(n.get_meta("asset_key","")).begins_with("station/"))
    var shown: Array = station_nodes.map(func(n): return str(n.get_meta("asset_key")))
    check("三操作位随菜替换汤锅蒸笼凉拌盆",station_nodes.size() == 3 and "station/stock_wok/body" in shown and "station/steamer/body" in shown and "station/cold_mix/body" in shown)
    check("新透明图不被原始PNG尺寸撑大",descendants(p.panel).filter(func(n): return n is TextureRect and n.has_meta("asset_key") and not str(n.get_meta("asset_key")).begins_with("character/")).all(func(n): return n.size.x <= 329 and n.size.y <= 305))
    check("完整透明空盘已独立接入",descendants(p.panel).any(func(n): return n is TextureRect and n.get_meta("asset_key","") == "plate/empty"))
    for recipe_row in g.available():
        p.rules.orders.clear()
        p.rules.pots = p.rules.pots.map(func(_pot): return p.rules.empty_pot())
        p.rules.choose(0,recipe_row.id)
        for stage in ["prep","cooking","ready","burnt"]:
            p.rules.pots[0].state = stage
            p._render()
            await process_frame
            var stage_nodes := descendants(p.panel).filter(func(n): return not n.is_queued_for_deletion())
            var content_nodes: Array = stage_nodes.filter(func(n): return n.has_meta("pot_visual"))
            check("完整阶段无缺件："+str(recipe_row.name)+"/"+stage,content_nodes.size() == 1 and stage_nodes.all(func(n): return not n.has_meta("asset_missing")) and str(content_nodes[0].get_meta("asset_key")) == "content/"+str(recipe_row.dish_id)+"/"+stage)
            if stage == "ready":
                check("熟菜仍显示剩余盛出窗口："+str(recipe_row.name),p.timers[0].label.text.ends_with("00:06"))
            var effects: Array = stage_nodes.filter(func(n): return str(n.get_meta("asset_key","")).begins_with("effect/"))
            if recipe_row.visual_group == "cold_mix":
                check("冷装无火无热蒸汽无焦烟："+stage,effects.all(func(n): return n.get_meta("asset_key") not in ["effect/flame","effect/steam","effect/smoke"]))
            elif stage in ["cooking","ready"] and recipe_row.visual_group in ["stock_wok","steamer","grill"]:
                check("热工位独立火层："+stage,effects.any(func(n): return n.get_meta("asset_key") == "effect/flame"))
    for row in g.available():
        check("熟菜与订单同一份成菜资源："+str(row.name),Art.visual_assets["content/"+str(row.dish_id)+"/ready"].frames[0] == row.finished_art)
    p.rules.pots = p.rules.pots.map(func(_pot): return p.rules.empty_pot())
    p._render()
    await process_frame
    check("空工位无独立火层",descendants(p.panel).all(func(n): return n.get_meta("asset_key","") != "effect/flame"))
    p._start(1)
    await process_frame
    check("首关显示一口可用锅与两口锁定锅且无火焰",descendants(p.panel).filter(func(n): return str(n.get_meta("asset_key","")).begins_with("station/")).size() == 3 and descendants(p.panel).filter(func(n): return n.has_meta("locked_station")).size() == 2 and descendants(p.panel).all(func(n): return n.get_meta("asset_key","") != "effect/flame"))
    p.rules.choose(0,"beef")
    for ingredient in p.rules.pots[0].required.duplicate(): p.rules.add_ingredient(0,ingredient)
    p._render()
    await process_frame
    check("首关仅已解锁热工位出现一层火",descendants(p.panel).filter(func(n): return n.get_meta("asset_key","") == "effect/flame").size() == 1)
    if "--capture" in OS.get_cmdline_user_args():
        for i in 8: await process_frame
        await RenderingServer.frame_post_draw
        target.get_texture().get_image().save_png(ProjectSettings.globalize_path("user://kitchen_test_厨房-v3-01接入自审未通过.png"))
    p.queue_free()
    await process_frame
    print("RESULT ","PASS" if ok else "FAIL")
    quit(0 if ok else 1)
