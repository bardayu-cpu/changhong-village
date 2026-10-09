extends SceneTree
## 验收：后厅的空起点（01 D 10/1 派：后厅厨房交给 GPT 试接手，GPT 从这块空地开始搭）。无界面跑整个 main.gd，云函数走电脑假数据。
## 把 main 搭好的灰盒后厅换成 backhall_start.gd（跟启动参数 --backhall=start 搭出来的一样），再走一圈：
## 1 空地：只有 to_hall、to_lawn 两个出口，没有家具、没有 NPC、交互点跟灰盒后厅的出口一个坐标；
## 2 宴会厅东侧门 → 空后厅站 (100,780)，不弹回去；3 东口 → 草坪 → 回来站厨房后门边 (1440,780)；4 西口 → 宴会厅
## 用法：Godot --headless --path . --script res://tools/test_backhall_start.gd
## 最后一行 RESULT PASS 才算过

const Main = preload("res://scripts/main.gd")
const DT := 1.0 / 60.0

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

func tick(n: int) -> void:
    for i in n:
        m.cv._process(DT)
        m._process(DT)

func walk_to(target: Vector2, secs := 20.0) -> void:
    m.cv.go_to(target)
    for i in int(secs / DT):
        tick(1)
        if m.cv.path.is_empty():
            break

func run() -> void:
    m.cloud.fake_no_news = true
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await process_frame
    m.games_save.local_path = "user://test_backhall_start_games.json"
    m.court_save.local_path = "user://test_backhall_start_court.json"
    # 换成空起点：跟 main 里 --backhall=start 那一行搭法一样
    var old = m.backhall
    var sv: Node = old.get_parent()
    old.queue_free()
    var b = load(Main.BACKHALL_START).new()
    sv.add_child(b)
    b.build(m.preset, "", m.font)
    b.spot.connect(m._on_backhall_spot)
    b.walking_enabled = false
    b.visible = false
    m.backhall = b
    await process_frame

    print("1 空地")
    check("只有两个出口：%s" % [b.points.keys()], b.points.size() == 2 and b.points.has("to_hall") and b.points.has("to_lawn"))
    check("出口坐标跟灰盒后厅一样：to_hall %s、to_lawn %s" % [b.spot_pos("to_hall"), b.spot_pos("to_lawn")],
        b.spot_pos("to_hall") == Vector2(1496, 780) and b.spot_pos("to_lawn") == Vector2(40, 780))   # 10/4 方案 C 对调
    check("没有家具、没有 NPC", (b.cfg.get("items", []) as Array).is_empty() and (b.cfg.get("npcs", []) as Array).is_empty() and b.obstacles.is_empty())
    check("画布 1536×1024，进门站的地方 (1436,780) 能走", Vector2(b.cfg["size"][0], b.cfg["size"][1]) == Vector2(1536, 1024) and b._free(Vector2(1436, 780)))
    check("房间里随便一处能走（北墙脚 (768,260)、中间 (768,500)）", b._free(Vector2(768, 260)) and b._free(Vector2(768, 500)))

    print("2 宴会厅西侧门进空后厅")
    m.nickname = "小李"
    await m._enter_banquet()
    tick(2)
    var h = m.hall
    walk_to(h.side_off(90, 0))
    walk_to(h.side_door)
    check("进了空后厅 state=%s" % m.state, m.state == "backhall" and m.cv == b and b.visible and not h.visible)
    check("站在 (1436,780)：%s" % b.pos, b.pos == Vector2(1436, 780))
    tick(60)
    check("站在东口边 60 帧不弹回宴会厅", m.state == "backhall")
    check("灰盒后厅的房间按钮没出来", not m.backhall_ui.act_btn.visible)

    print("3 西口去草坪、再回来")
    walk_to(b.spot_pos("to_lawn"), 30.0)
    check("进了草坪 state=%s" % m.state, m.state == "lawn")
    walk_to(m.lawn.spot_pos("to_backhall"), 30.0)
    check("回到空后厅、站在厨房后门边 %s" % b.pos, m.state == "backhall" and b.pos == Vector2(100, 780))

    print("4 东口回宴会厅")
    walk_to(b.spot_pos("to_hall"), 30.0)
    check("回到宴会厅 state=%s" % m.state, m.state == "banquet" and m.cv == h)

    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_backhall_start_games.json"))
    DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_backhall_start_court.json"))
    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
