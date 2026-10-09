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
func descendants(node: Node) -> Array:
    var result: Array = []
    for child in node.get_children():
        result.append(child)
        result.append_array(descendants(child))
    return result
func click_action(id: String) -> void:
    for child in descendants(p.panel):
        if child is Button and str(child.get_meta("kitchen_action","")) == id:
            child.pressed.emit()
            await process_frame
            return
    print("FAIL missing action ",id)
    ok = false
func run() -> void:
    var w = Save.new()
    w.local_path = "user://test_kitchen_buttons_wallet.json"
    p = KitchenPanel.new()
    p.saved_path = "user://test_kitchen_buttons_progress.json"
    root.add_child(p)
    p.open(w,load("res://assets/fonts/fusion-pixel-12px-proportional-zh_hans.otf.woff2"))
    p.set_process(false)
    await click_action("start")
    if not ok:
        print("RESULT FAIL")
        quit(1)
        return
    var order_button: Button
    for child in descendants(p.panel):
        if child is Button and child.has_meta("order_dish"): order_button = child
    if order_button: order_button.pressed.emit()
    else: ok = false
    await process_frame
    for ingredient in p.rules.pots[0].required: await click_action(str(ingredient))
    p.rules.tick(8)
    p._render()
    await click_action("serve")
    await click_action("deliver")
    ok = ok and w.coins == 3 and p.rules.completed == 1
    print("PASS " if ok else "FAIL ","实际按钮流程：点订单、照单加料、盛出、自动交菜发币")
    ok = ok and p.rules.served_counts.get("beef",0) == 1
    p._start(8)
    ok = ok and p.rules.served_counts.is_empty()
    await click_action("pause")
    var before: float = p.rules.orders[0].left
    p._process(5)
    ok = ok and p.rules.orders[0].left == before
    await click_action("pause")
    ok = ok and not p.rules.paused
    p.queue_free()
    await process_frame
    DirAccess.remove_absolute(ProjectSettings.globalize_path(w.local_path))
    print("RESULT ","PASS" if ok else "FAIL")
    quit(0 if ok else 1)
