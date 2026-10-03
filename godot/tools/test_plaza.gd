extends SceneTree
## 验收：喷泉广场灰盒和各处新连法（蓝图 v0.3 第 1.0 节新总图第 ② 步，阿鱼 10/4「行」；01 F 派）。无界面跑整个 main.gd。
##   1 布局：喷泉在正中、挡路；六个口（东去迎宾院、西去草坪、南去后厅、北边三个待做）；从哪来站的点能站、离口至少 1 米、都走得到
##   2 迎宾院西北口 ↔ 广场东口；广场西口 ↔ 草坪西南口；广场南口 ↔ 后厅走廊南口：真走过去、站对、站着不弹回去
##   3 北边三个口：走进去说一句还在布置、人还在广场；走出来再进去又说
##   4 连法：迎宾院没有去草坪的口了（湖边那个口照旧）；草坪没有回迎宾院的口；牌子都在（迎宾院、草坪、后厅、广场六个口）
##   5 老存档：10/3 以前存的迎宾院存档（只有老字段）照常读，进广场、回来都好
## 用法：Godot --headless --path . --script res://tools/test_plaza.gd
## 最后一行 RESULT PASS 才算过

const Main = preload("res://scripts/main.gd")
const DT := 1.0 / 60.0
const SAVE := "user://test_plaza_court.json"

var m
var started := false
var ok := true

func _initialize() -> void:
    # 5 的老存档先写好（main 开场就读）：只有 10/3 以前就有的几个字段
    var f := FileAccess.open(SAVE, FileAccess.WRITE)
    f.store_string(JSON.stringify({"welcomed": true, "signed_in": true, "candy": true, "gloss_seen": true, "door_hint": true}))
    f.close()
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

## 推着走到某点；切了画布就停（cv 换了）
func walk_to(target: Vector2, secs := 25.0) -> void:
    var c = m.cv
    c.go_to(target)
    for i in int(secs / DT):
        tick(1)
        if m.cv != c or c.path.is_empty():
            break
    for i in 60:   # 切画布那一下（淡出淡入）等完
        if not m.switching:
            break
        await process_frame

func labels_of(c) -> Array:
    var out: Array = []
    for it in c.cfg.get("flat", []):
        if str(it.get("type", "")) == "label" and c.is_exit_label(str(it["text"])):
            out.append(str(it["text"]))
    return out

func run() -> void:
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    m.court_save.local_path = SAVE
    m.court_save.load_local()
    m.games_save.local_path = "user://test_plaza_games.json"
    m.cloud.fake_no_news = true
    m.ensure_canvas("plaza")
    m.ensure_canvas("lawn")
    m.ensure_canvas("backhall")
    var p = m.plaza
    var c = m.court

    print("1 布局")
    var ids: Array = p.points.keys()
    ids.sort()
    check("六个口 %s" % [ids], ids == ["north_kids", "north_rest", "north_shop", "to_backhall", "to_court", "to_lawn"])
    check("喷泉在正中、挡路", not p._free(Vector2(768, 540)) and not p._free(Vector2(700, 540)) and p._free(Vector2(768, 700)))
    var stand_ok := true
    for pair in [[p.FROM_COURT, "to_court"], [p.FROM_LAWN, "to_lawn"], [p.FROM_BACKHALL, "to_backhall"]]:
        var at: Vector2 = pair[0]
        var d: float = at.distance_to(p.points[pair[1]]["pos"])
        stand_ok = stand_ok and p._free(at) and d >= 48.0
        print("    %s 进来站 %s，离口 %.0f" % [pair[1], at, d])
    check("从三个口进来站的点能站、离口至少 1 米", stand_ok)
    var reach := true
    for id in p.points:
        var path: Array = p.find_path(p.SPAWN, p.points[id]["pos"])
        var end: Vector2 = path[path.size() - 1] if not path.is_empty() else p.SPAWN
        if end.distance_to(p.points[id]["pos"]) >= float(p.points[id]["r"]):
            reach = false
            print("    走不到 ", id)
    check("广场上每个口都走得到", reach)

    print("2 迎宾院 ↔ 广场 ↔ 草坪、后厅")
    m.nickname = "小李"
    await m._enter_court()
    m.dialog.visible = false
    check("迎宾院西北口在 %s，从广场回来站 %s（离口 %.0f、能站）" % [c.spot_pos("to_plaza"), m.COURT_FROM_PLAZA, m.COURT_FROM_PLAZA.distance_to(c.spot_pos("to_plaza"))],
        c.points.has("to_plaza") and c._free(m.COURT_FROM_PLAZA) and m.COURT_FROM_PLAZA.distance_to(c.spot_pos("to_plaza")) >= 48.0)
    await walk_to(c.spot_pos("to_plaza"))
    check("迎宾院往西走到广场 state=%s，站在东口里边 %s" % [m.state, p.pos], m.state == "plaza" and m.cv == p and p.pos == p.FROM_COURT)
    tick(60)
    check("站着 60 帧不弹回迎宾院", m.state == "plaza")
    await walk_to(p.spot_pos("to_lawn"))
    check("广场西口到草坪，站在西南口边 %s" % m.lawn.pos, m.state == "lawn" and m.lawn.pos == m.LAWN_FROM_PLAZA)
    tick(60)
    check("站着 60 帧不弹回广场", m.state == "lawn")
    await walk_to(m.lawn.spot_pos("to_plaza"))
    check("草坪西南口回广场，站在西口里边 %s" % p.pos, m.state == "plaza" and p.pos == p.FROM_LAWN)
    tick(60)
    await walk_to(p.spot_pos("to_backhall"))
    check("广场南口到后厅，站在走廊南口里边 %s" % m.backhall.pos, m.state == "backhall" and m.backhall.pos == m.BACKHALL_FROM_PLAZA)
    tick(60)
    check("站着 60 帧不弹回广场", m.state == "backhall")
    await walk_to(m.backhall.spot_pos("to_plaza"))
    check("后厅走廊南口回广场，站在南口里边 %s" % p.pos, m.state == "plaza" and p.pos == p.FROM_BACKHALL)
    tick(60)

    print("3 北边三个口（待做）")
    var said: Array = []
    for id in ["north_kids", "north_shop", "north_rest"]:
        m.dialog.visible = false
        await walk_to(p.spot_pos(id))
        var t1: String = m.dialog_text.text if m.dialog.visible else ""
        await walk_to(p.spot_pos(id) + Vector2(0, 160))
        m.dialog.visible = false
        await walk_to(p.spot_pos(id))
        var t2: String = m.dialog_text.text if m.dialog.visible else ""
        said.append(t1)
        check("%s：走进去说「%s」、人还在广场；走出来再进去又说" % [id, t1], t1.contains("还在布置") and t2 == t1 and m.state == "plaza")

    print("4 连法和牌子")
    await walk_to(p.spot_pos("to_court"))
    check("广场东口回迎宾院，站在西北口里边 %s" % c.pos, m.state == "court" and c.pos == m.COURT_FROM_PLAZA)
    check("迎宾院没有去草坪的口了，湖边的口照旧", not c.points.has("to_lawn") and c.points.has("to_lake"))
    check("迎宾院东边原来那个口走不出去了", not c._free(Vector2(1510, 780)))
    check("草坪没有回迎宾院的口了", not m.lawn.points.has("to_entrance") and m.lawn.points.has("to_plaza") and m.lawn.points.has("to_backhall"))
    check("后厅原来两个口照旧", m.backhall.points.has("to_hall") and m.backhall.points.has("to_lawn"))
    var pl: Array = labels_of(p)
    check("广场六块牌子 %s" % [pl], pl.size() == 6 and "去迎宾院" in pl and "去草坪" in pl and "去后厅" in pl)
    check("迎宾院、草坪、后厅那头都挂「去喷泉广场」", "去喷泉广场" in labels_of(c) and "去喷泉广场" in labels_of(m.lawn) and "去喷泉广场" in labels_of(m.backhall)
        and not "东小径" in labels_of(c) and not "回迎宾院" in labels_of(m.lawn))

    print("5 老存档")
    check("老存档读进来了（签过到、迎过）", m.court_save.signed_in and m.court_save.welcomed)
    await walk_to(c.spot_pos("to_plaza"))
    await walk_to(p.spot_pos("to_court"))
    check("老存档也能进广场、回迎宾院", m.state == "court")

    DirAccess.remove_absolute(SAVE)
    DirAccess.remove_absolute("user://test_plaza_games.json")
    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
