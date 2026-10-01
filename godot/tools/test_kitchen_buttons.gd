extends SceneTree
const KitchenPanel = preload("res://scripts/kitchen/kitchen_panel.gd")
const Save = preload("res://scripts/games/game_save.gd")
var p
var ok := true
func _initialize() -> void: call_deferred("run")
func click(text: String, last := false) -> void:
    var children: Array = p.panel.get_children()
    if last: children.reverse()
    for child in children:
        if child is Button and child.text == text:
            if child.disabled:
                print("FAIL disabled ",text)
                ok = false
                return
            child.pressed.emit()
            await process_frame
            return
    print("FAIL missing button ",text)
    ok = false
func run() -> void:
    var w = Save.new()
    w.local_path = "user://test_kitchen_buttons_wallet.json"
    p = KitchenPanel.new()
    p.saved_path = "user://test_kitchen_buttons_progress.json"
    root.add_child(p)
    p.open(w,load("res://assets/fonts/fusion-pixel-12px-proportional-zh_hans.otf.woff2"))
    p.set_process(false)
    await click("穿上厨师套装 · 开始第 1 关")
    await click("跷脚牛肉")
    await click("汤底")
    await click("牛肉")
    await click("葱花")
    p.rules.tick(8)
    p._render()
    await click("盛出选中的锅")
    await click("跷脚牛肉",true)
    var customer: Button
    for c in p.panel.get_children():
        if c is Button and c.text.begins_with("· 跷脚牛肉"): customer=c
    if customer: customer.pressed.emit()
    else: ok=false
    await process_frame
    ok = ok and w.coins == 3 and p.rules.completed == 1
    print("PASS " if ok else "FAIL ","实际按钮流程：选关、菜谱、三次加料、盛出、交付发币")
    p._start(8)
    await click("暂停")
    var before: float = p.rules.orders[0].left
    p._process(5)
    ok = ok and p.rules.orders[0].left == before
    await click("继续")
    ok = ok and not p.rules.paused
    p.queue_free()
    await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(w.local_path))
    print("RESULT ","PASS" if ok else "FAIL")
    quit(0 if ok else 1)
