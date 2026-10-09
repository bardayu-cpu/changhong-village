extends SceneTree
const Catalog = preload("res://scripts/kitchen/kitchen_catalog.gd")
const Rules = preload("res://scripts/kitchen/kitchen_rules.gd")
var ok := true
func check(label: String, value: bool) -> void:
    print(("PASS " if value else "FAIL ")+label)
    ok = ok and value
func _initialize() -> void:
    var setup: Dictionary = Catalog.read_json("res://data/kitchen/gameplay.json")
    var runtime := Catalog.resolve_setup(setup)
    var approved: Array = runtime.recipes.filter(func(r): return r.get("runtime_value_status","") == "confirmed" and r.get("gameplay_confirmed",false))
    check("十二道菜使用已批准接入占位值",approved.size() == 12 and not setup.has("recipes"))
    check("正式配置关闭开发覆盖",setup.get("allow_development_overrides",true) == false and setup.get("release_status","") == "integration_placeholder_approved_2026-10-02")
    check("登记明确标记逐菜替换",approved.all(func(r): return r.registry_record.get("value_status","") == "integration_placeholder_replace_recipe_by_recipe"))
    check("占位配方字段完整",approved.all(func(r): return not r.ingredients.is_empty() and r.seconds > 0.0 and r.window > 0.0 and r.coins > 0 and r.unlock > 0))
    var qiaojiao: Dictionary = runtime.recipes.filter(func(r): return r.dish_id == "qiaojiao_beef")[0]
    check("跷脚牛肉占位值与验收口径一致",qiaojiao.id == "beef" and qiaojiao.station_id == "stock_wok" and qiaojiao.ingredients == ["汤底","牛肉","葱花","香菜"] and qiaojiao.seconds == 8.0 and qiaojiao.window == 6.0 and qiaojiao.coins == 3 and qiaojiao.unlock == 1)
    var duck: Dictionary = runtime.recipes.filter(func(r): return r.dish_id == "sweet_skin_duck")[0]
    check("甜皮鸭使用批准占位工位与等级",duck.station_id == "grill" and duck.unlock == 10 and duck.coins == 5)
    var g = Rules.new()
    check("正式配置可直接启动",g.configure(runtime))
    g.start(30,2026)
    check("正式占位菜谱可接单且不会读取开发草案",not g.available().is_empty() and not g.orders.is_empty() and g.active and g.earned == 0)
    var pending := {"id":"test_confirmed","name":"测试配方","status":"pending_recipe_details","station_id":"stock_wok","finished_art":"dishes/local12/dish_qiaojiao_beef_full.png"}
    check("标记已确认但字段缺失不能启动",not Catalog.is_gameplay_confirmed({"status":"gameplay_confirmed"}))
    var confirmed := pending.duplicate(true)
    confirmed.status = "gameplay_confirmed"
    confirmed.steps = [{"component_id":"牛肉","label":"牛肉","action":"add"}]
    confirmed.cook_seconds = 2.0
    confirmed.ready_window_seconds = 6.0
    confirmed.reward_coins = 5
    confirmed.unlock_rule = {"min_level":2}
    var cooked := Catalog.resolve_record(confirmed,{},false)
    check("完整确认字段映射规则参数",cooked.enabled and cooked.gameplay_confirmed and cooked.ingredients == ["牛肉"] and cooked.seconds == 2.0 and cooked.coins == 5 and cooked.unlock == 2)
    confirmed.steps = [{"component_id":"broth","action":"add"}]
    var named := Catalog.resolve_record(confirmed,{},false,{"broth":{"name":"汤底"}})
    check("原料ID通过组件登记映射中文名称",named.ingredients == ["汤底"])
    print("RESULT ","PASS" if ok else "FAIL")
    quit(0 if ok else 1)
