extends SceneTree
const KitchenPanel = preload("res://scripts/kitchen/kitchen_panel.gd")
const Save = preload("res://scripts/games/game_save.gd")
var ok := true
func check(label: String, condition: bool) -> void:
    print(("PASS " if condition else "FAIL ") + label)
    ok = ok and condition
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    var w = Save.new()
    w.local_path = "user://test_kitchen_wallet.json"
    var p = KitchenPanel.new()
    p.saved_path = "user://test_kitchen_progress.json"
    root.add_child(p)
    var f = load("res://assets/fonts/fusion-pixel-12px-proportional-zh_hans.otf.woff2")
    p.open(w,f)
    p.set_process(false)
    p._start(1)
    await process_frame
    var g = p.rules
    g.choose(0,"beef")
    for ingredient in g.recipe("beef").ingredients: g.add_ingredient(0,ingredient)
    g.tick(8)
    g.serve_pot(0)
    g.deliver(g.plates[0].id,g.orders[0].id)
    check("逐菜接入原有金币钱包", w.coins == 3)
    p._render()
    await process_frame
    check("面板采用540×960设计尺寸", p.panel.size == Vector2(540,960))
    g.won = true
    g.active = false
    p._process(0.01)
    check("过关解锁并保存", p.unlocked == 2 and FileAccess.file_exists(p.saved_path))
    p._menu()
    await process_frame
    p.queue_free()
    await process_frame
    for path in ["user://test_kitchen_wallet.json","user://test_kitchen_progress.json"]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    print("RESULT ","PASS" if ok else "FAIL")
    quit(0 if ok else 1)
