extends SceneTree
## 门口的名字牌（阿鱼 10/3「每个房间的门口需要用牌子写明这是哪里」；01 F 派）
## 1 后厅三间门口各一块：化妆间、休息间、麻将室；挂在门洞东边的墙上，不压门洞；不挡路（不加挡人的占地，走廊照样走得通）；
##   按墙脚那条线排前后：走廊里的人画在牌子前面；字比世界里的字大一号
## 2 宴会厅东侧门（通后厅）一块「后厅」：在门那个点上方，不压门那个点；不挡路
## 用法：Godot --headless --path . --script res://tools/test_room_signs.gd ；最后一行 RESULT PASS 才算过

var m
var started := false
var ok := true

func _initialize() -> void:
    m = load("res://scripts/main.gd").new()
    m.fast = true
    get_root().add_child(m)

func _process(_dt: float) -> bool:
    if started:
        return false
    started = true
    run()
    return false

func check(name: String, cond: bool) -> void:
    print(("  好 " if cond else "  不行 ") + name)
    ok = ok and cond

## 牌子在画布上的框（字那块 Label，连底板）
func sign_box(s: Node2D) -> Rect2:
    var l: Label = s.get_child(0)
    return Rect2(s.position + l.position, l.size)

func run() -> void:
    get_root().size = Vector2i(540, 960)
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    m.ensure_canvas("backhall")
    var b = m.backhall
    print("1 后厅三间")
    var texts: Array = b.room_signs.map(func(s): return (s.get_child(0) as Label).text)
    check("三块牌子：%s" % [texts], texts == ["化妆间", "休息间", "麻将室"])
    var doors := {"化妆间": [128.0, 208.0], "休息间": [464.0, 544.0], "麻将室": [800.0, 880.0]}
    for s in b.room_signs:
        var l: Label = s.get_child(0)
        var box := sign_box(s)
        var d: Array = doors[l.text]
        check("「%s」挂在门洞东边的墙上（牌子 x %.0f～%.0f，门洞 %.0f～%.0f），下沿在墙上（%.0f）" % [l.text, box.position.x, box.end.x, d[0], d[1], box.end.y],
            box.position.x >= float(d[1]) and box.position.x - float(d[1]) < 40.0 and box.end.y <= 696.0 and box.end.y >= 674.0)
        check("「%s」在会排前后的那层（排在墙脚 696 前面一点：%.0f）" % [l.text, s.position.y], s.get_parent() == b.world and s.position.y > 696.0 and s.position.y < 708.0)
        check("「%s」字 %d（比世界里的字 %d 大）" % [l.text, l.get_theme_font_size("font_size"), b.WORLD_FONT], l.get_theme_font_size("font_size") > b.WORLD_FONT)
    var blocked := 0
    for x in range(40, 1500, 12):
        if not b._free(Vector2(x, 780)):
            blocked += 1
    check("不挡路：走廊 y 780 从西走到东一路都能走（挡住的 %d 格）" % blocked, blocked == 0)
    for id in ["dress", "lounge", "mahjong", "to_hall", "to_lawn"]:
        var pt: Vector2 = b.points[id]["pos"]
        var path: Array = b.find_path(b.SPAWN, pt)
        check("%s 照样走得到" % id, not path.is_empty() and (path[path.size() - 1] as Vector2).distance_to(pt) <= float(b.points[id]["r"]))

    print("2 宴会厅东侧门")
    var h = m.hall
    var hs: Array = h.room_signs.filter(func(s): return (s.get_child(0) as Label).text == "后厅")
    check("东侧门有一块「后厅」", hs.size() == 1)
    if hs.size() == 1:
        var box2 := sign_box(hs[0])
        check("牌子在门那个点上方、不压门（牌子 %s，门 %s）" % [box2, h.side_door], box2.end.y < h.side_door.y and not box2.has_point(h.side_door))
        check("牌子在画布里（右边 %.0f ≤ %d）" % [box2.end.x, int(h.cfg["size"][0])], box2.end.x <= float(h.cfg["size"][0]) and box2.position.x >= 0.0)
        check("门那个点照样站得住", h._free(h.side_door + Vector2(-20, 0)))
    print("RESULT PASS" if ok else "RESULT FAIL")
    quit(0 if ok else 1)
