extends SceneTree
## 验收：喷泉广场灰盒和各处新连法（蓝图 v0.3 第 1.0 节新总图第 ② 步，阿鱼 10/4「行」；01 F 派）。无界面跑整个 main.gd。
##   （10/4 连图 02 E 改：来回走、北边待做口、老存档都挪到 test_liantu.gd、test_plaza_check.gd；这里只核广场八个口）
##   1 布局：喷泉在正中、挡路；八个口通哪、在哪条边；落点能站、离口至少 1 米、都走得到；八块牌子
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

    # 10/4 连图（02 E 改）：广场的口照阿鱼图转半圈换了边、北边三个「待做」口改成南边三个口通灰盒；
    # 每个口来回走、落点、不弹回去都挪到 test_liantu.gd，这里只核广场自己
    print("1 布局")
    var want := {"to_backhall": "backhall", "to_rest2": "rest2", "to_shop": "shop", "to_kids": "kids", "to_court": "court",
        "to_frontgate": "frontgate", "to_lawn": "lawn", "to_wkitchen": "wkitchen"}
    var got := {}
    for id in p.points:
        got[id] = str(p.points[id]["to"])
    check("八个口、各通哪块 %s" % [got], got == want)
    check("喷泉在正中、挡路", not p._free(Vector2(768, 540)) and not p._free(Vector2(700, 540)) and p._free(Vector2(768, 700)))
    var side_ok := true
    for id in want:
        var q: Vector2 = p.points[id]["pos"]
        var side := "N" if q.y < 100 else ("S" if q.y > 924 else ("W" if q.x < 100 else "E"))
        var exp: String = {"to_backhall": "N", "to_rest2": "S", "to_shop": "S", "to_kids": "S", "to_court": "W", "to_frontgate": "W", "to_lawn": "E", "to_wkitchen": "E"}[id]
        if side != exp:
            side_ok = false
            print("    %s 在 %s 边，该在 %s 边" % [id, side, exp])
    check("口在哪条边照转半圈的阿鱼图：北后厅、南三块、西迎宾院前门、东草坪西餐厨房", side_ok)
    var reach := true
    for id in p.points:
        var land: Vector2 = p.arrival_at(id)
        var path: Array = p.find_path(p.SPAWN, p.points[id]["pos"])
        var end: Vector2 = path[path.size() - 1] if not path.is_empty() else p.SPAWN
        if end.distance_to(p.points[id]["pos"]) >= float(p.points[id]["r"]) or not p._free(land) or land.distance_to(p.points[id]["pos"]) < 48.0:
            reach = false
            print("    %s 走不到或落点不对（落点 %s）" % [id, land])
    check("每个口从出生点走得到、落点能站、离口至少 1 米", reach)
    var pl: Array = labels_of(p)
    check("广场八块牌子 %s" % [pl], pl.size() == 8 and not pl.any(func(x): return str(x).contains("待做")))

    DirAccess.remove_absolute(SAVE)
    DirAccess.remove_absolute("user://test_plaza_games.json")
    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
