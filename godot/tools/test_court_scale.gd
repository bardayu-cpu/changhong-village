extends SceneTree
## 验收：迎宾院照「人 = 1」摆（01 E 10/3；04 基线第 7 条、必须做的第 5 条；ASSETS §15）
## 1 游戏里画出来的每件东西，外框跟 gen_specs_court.py 从 layout.json 算的（回执/零件规格/迎宾院/迎宾院-框.json）一样——两边一个算法，唯一源对得上
## 2 签到桌长 ≤1.4 个人、树 ≥3 个人高、大门门洞 232 / 整座 344 / 柱高 196（直接量游戏里画的）
## 3 改完摆设，交互点都走得到：签到、回忆册、祝福牌、合影、休息区、楼门、大门、两条小径；签到站位在桌子前面、不在桌子里
## 用法：Godot --headless --path . --script res://tools/test_court_scale.gd ；最后一行 RESULT PASS 才算过

const Main = preload("res://scripts/main.gd")
const BOXES := "res://回执/零件规格/迎宾院/迎宾院-框.json"

var m
var started := false
var ok := true

func _initialize() -> void:
    m = Main.new()
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

## 一件东西（world 下面那个 holder）画出来的外框：多边形的点，加上 holder 的位置
func drawn_box(holder: Node2D) -> Rect2:
    var r := Rect2()
    var first := true
    for c in holder.get_children():
        var pts := PackedVector2Array()
        if c is Polygon2D:
            pts = (c as Polygon2D).polygon
        elif c is Sprite2D:
            var s := c as Sprite2D
            var img := s.texture.get_image()
            if img.is_compressed():
                img.decompress()
            var u := img.get_used_rect()
            var o := s.position + s.offset
            pts = PackedVector2Array([o + Vector2(u.position), o + Vector2(u.end)])
        else:
            continue
        for v in pts:
            var p: Vector2 = v + holder.position
            if first:
                r = Rect2(p, Vector2.ZERO)
                first = false
            else:
                r = r.expand(p)
    return r

func run() -> void:
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    m.court_save.local_path = "user://test_court_scale_court.json"
    m.court_save.welcomed = true
    m.nickname = "小李"
    await m._enter_court()
    var c = m.court

    print("1 画的跟唯一源一样")
    var spec = JSON.parse_string(FileAccess.get_file_as_string(BOXES))
    check("读到 迎宾院-框.json", spec is Dictionary)
    if not spec is Dictionary:
        print("RESULT FAIL")
        quit(1)
        return
    var bad: Array = []
    var n := 0
    var by_id := {}
    for it in spec["items"]:
        by_id[it["id"]] = it
        var holder: Node2D = c.world.get_node_or_null(NodePath(str(it["id"])))
        if holder == null:
            bad.append("%s 没画" % it["id"])
            continue
        var want := Rect2(Vector2(it["box"][0], it["box"][1]), Vector2(float(it["box"][2]) - float(it["box"][0]), float(it["box"][3]) - float(it["box"][1])))
        var got := drawn_box(holder)
        n += 1
        if absf(got.position.x - want.position.x) > 1.5 or absf(got.position.y - want.position.y) > 1.5 or absf(got.end.x - want.end.x) > 1.5 or absf(got.end.y - want.end.y) > 1.5:
            bad.append("%s 画的 %s 表里 %s" % [it["id"], got, want])
    check("%d 件东西画出来的外框跟 layout.json 算的一样（不对的 %s）" % [n, bad], n >= 40 and bad.is_empty())

    print("2 几样关键的直接量")
    var sign := drawn_box(c.world.get_node("sign_table"))
    check("签到桌长 %.0f = %.2f 个人（≤1.4）" % [sign.size.x, sign.size.x / 84.0], sign.size.x / 84.0 <= 1.4)
    var trees: Array = []
    for t in ["tree_nw", "tree_ne", "tree_sw", "tree_se"]:
        trees.append(snappedf(drawn_box(c.world.get_node(t)).size.y / 84.0, 0.01))
    check("四棵树 %s 个人高（≥3）" % [trees], trees.all(func(v): return v >= 3.0))
    var pw := drawn_box(c.world.get_node("gate_post_w"))
    var pe := drawn_box(c.world.get_node("gate_post_e"))
    var roof := drawn_box(c.world.get_node("gate_roof"))
    check("大门门洞 %.0f、整座 %.0f、柱高 %.0f（表：232、344、196）" % [pe.position.x - pw.end.x, roof.size.x, by_id["gate_post_w"]["dims"]["h"]],
        is_equal_approx(pe.position.x - pw.end.x, 232.0) and is_equal_approx(roof.size.x, 344.0) and is_equal_approx(float(by_id["gate_post_w"]["dims"]["h"]), 196.0))

    print("3 站位跟着核")
    var from: Vector2 = c.SPAWN
    var miss: Array = []
    for id in ["sign_in", "album", "blessing", "photo_wait", "photo_mark", "rest", "to_hall", "gate", "to_lake", "to_lawn"]:
        var p: Vector2 = c.spot_pos(id)
        var path: Array = c.find_path(from, p)
        if path.is_empty() or (path[path.size() - 1] as Vector2).distance_to(p) > float(c.points[id]["r"]):
            miss.append(id)
    check("从大门口走得到每个交互点的圈里（走不到的 %s）" % [miss], miss.is_empty())
    var st: Array = by_id["sign_table"]["box"]
    var sp: Vector2 = c.spot_pos("sign_in")
    check("签到站位 %s 在桌子前沿 %.0f 前面、左右在桌子中间" % [sp, st[3]], sp.y > float(st[3]) and sp.x > float(st[0]) and sp.x < float(st[2]) and c._free(sp))
    var cp: Vector2 = c.couple_pos() if c.has_method("couple_pos") else Vector2(c.cfg["couple"][0], c.cfg["couple"][1])
    var fw: Array = by_id["flower_wall"]["box"]
    check("新人 %s 站在花墙（%s～%s）正前面" % [cp, fw[0], fw[2]], cp.x > float(fw[0]) and cp.x < float(fw[2]) and cp.y > float(fw[3]))

    print("RESULT PASS" if ok else "RESULT FAIL")
    quit(0 if ok else 1)
