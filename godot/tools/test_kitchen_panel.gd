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
    w.local_path = "user://kitchen_test_test_kitchen_wallet.json"
    var p = KitchenPanel.new()
    p.saved_path = "user://kitchen_test_test_kitchen_progress.json"
    DirAccess.remove_absolute(ProjectSettings.globalize_path(p.saved_path))
    root.add_child(p)
    var f = load("res://assets/fonts/fusion-pixel-12px-proportional-zh_hans.otf.woff2")
    p.open(w,f)
    p.set_process(false)
    p._start(1)
    await process_frame
    var g = p.rules
    var wait_before: float = g.orders[0].left
    p._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
    await process_frame
    p._process(120.0)
    check("切后台暂停且长时间不扣耐心", g.paused and g.orders[0].left == wait_before)
    p._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
    p._process(1.0)
    check("回前台仍暂停，等待玩家继续", g.paused and g.orders[0].left == wait_before)
    p._toggle_pause()
    g.choose_order_dish(0,g.orders[0].id,0)
    for ingredient in g.pots[0].required: g.add_ingredient(0,ingredient)
    g.tick(8)
    g.serve_pot(0)
    g.deliver(g.plates[0].id,g.orders[0].id)
    check("逐菜接入原有金币钱包", w.coins == 3)
    p._render()
    await process_frame
    check("面板采用540×960设计尺寸", p.panel.size == Vector2(540,960))
    # The panel animates served waiters out before settlement. This unit test
    # jumps straight to the result state, so finish that presentation step.
    p.departures.clear()
    g.won = true
    g.active = false
    p._process(0.01)
    check("过关解锁并保存", p.unlocked == 2 and FileAccess.file_exists(p.saved_path))
    p._menu()
    await process_frame
    var progress_path: String = p.saved_path
    p.queue_free()
    await process_frame
    for path in [w.local_path,progress_path]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    print("RESULT ","PASS" if ok else "FAIL")
    quit(0 if ok else 1)
