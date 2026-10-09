extends SceneTree
## 湖边东头像素成品（build57 d570fb0，第 58 版）的整条路（01 F 10/4 派，03 写）。不改游戏代码。
## 东头月亮门 → 石板路 → 曲桥 → 亭子前沿（亭子点）→ 往西小路（过东头像素画接西头色块那条缝 x≈1536）→ 西头月亮门前 → 西头半岛小亭、游船码头色块，
## 每一段摇杆照寻路走（卡住 2 秒算失败），来回都走；走进出口半径会切场景，算到了。另量：东头像素画的接缝两边走路范围、起点、出口位置
## 用法：Godot --headless --path . --script res://tools/test_lake_chain.gd     最后一行 RESULT PASS 才算过
const Main = preload("res://scripts/main.gd")
const DT := 1.0 / 60.0
var m
var started := false
var ok := true
var cv

func _initialize() -> void:
    m = Main.new()
    m.fast = true
    get_root().add_child(m)
    create_timer(200.0).timeout.connect(func():
        print("RESULT FAIL 200 秒没跑完")
        quit(1))

func _process(_dt: float) -> bool:
    if started:
        return false
    started = true
    run()
    return false

func check(name: String, cond: bool) -> void:
    print(("  好 " if cond else "  不行 ") + name)
    ok = ok and cond

func reenter() -> void:
    m.switching = false
    if m.state != "lake":
        m._show_canvas("lake")
        m._goto("lake")
    cv.walking_enabled = true
    cv.stick = Vector2.ZERO

func walk(target: Vector2) -> Dictionary:
    reenter()
    var path: Array = cv.find_path(cv.pos, target)
    if path.is_empty():
        return {"ok": false, "err": "寻路没路"}
    cv.path.clear()
    var wi := 0
    var best := INF
    var noprog := 0.0
    var total := 0.0
    while wi < path.size():
        var wp: Vector2 = path[wi]
        var d: Vector2 = wp - cv.pos
        if d.length() < 3.0:
            wi += 1
            best = INF
            noprog = 0.0
            continue
        cv.stick = d.normalized()
        cv._process(DT)
        total += DT
        if m.state != "lake":
            cv.stick = Vector2.ZERO
            return {"ok": true, "secs": total, "exit_fired": true}
        var nd: float = (wp - cv.pos).length()
        if nd < best - 0.5:
            best = nd
            noprog = 0.0
        else:
            noprog += DT
        if noprog >= 2.0 or total > 200.0:
            cv.stick = Vector2.ZERO
            return {"ok": false, "err": "卡住", "at": cv.pos, "wp": wp}
    cv.stick = Vector2.ZERO
    return {"ok": true, "secs": total}

func snap(p: Vector2) -> Vector2:
    if cv._free(p):
        return p
    var c: Vector2i = cv._nearest_free(cv._cell_of(p))
    return Vector2((c.x + 0.5) * cv.cell, (c.y + 0.5) * cv.cell)

func run() -> void:
    get_root().size = Vector2i(540, 960)
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await process_frame
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    m.ensure_canvas("lake")
    m._show_canvas("lake")
    m._goto("lake")
    cv = m.lake
    var legs := [
        ["东头月亮门进门处", cv.SPAWN],
        ["石板路", Vector2(2304, 900)],
        ["曲桥头", Vector2(2305, 800)],
        ["曲桥中", Vector2(2335, 725)],
        ["亭子前沿（亭子点）", cv.points["pavilion"]["pos"]],
        ["往西小路（东头）", Vector2(2000, 900)],
        ["东头接西头那条缝（x 1560）", Vector2(1560, 838)],
        ["缝西边", Vector2(1500, 900)],
        ["长凳（点）", cv.points["bench"]["pos"]],
        ["湖中段小路", Vector2(1000, 960)],
        ["西头月亮门前", Vector2(740, 1000)],
        ["西头色块：码头", Vector2(530, 740)],
        ["西头色块：半岛小亭", Vector2(530, 560)],
    ]
    # 10/4 连图（02 E 改）：西头月亮门改去后花园，东头南墙月亮门不再通迎宾院、东头尽头开口去果园 A
    print("东头进门 (%s)；去后花园的口 %s；去果园的口 %s" % [str(cv.SPAWN), str(cv.points["to_garden"]["pos"]), str(cv.points["to_orchard"]["pos"])])
    check("东头进门点能站、西头进门点能站", cv._free(cv.SPAWN) and cv._free(cv.arrival_from("garden")))
    var bad := 0
    var total := 0.0
    for i in range(1, legs.size()):
        var a: Vector2 = snap(legs[i - 1][1])
        var z: Vector2 = snap(legs[i][1])
        reenter()
        cv.reset_to(a)
        var r1 := walk(z)
        var arrived1: bool = (cv.pos - z).length() <= 16.0
        reenter()
        cv.reset_to(z)
        var r2 := walk(a)
        var arrived2: bool = (cv.pos - a).length() <= 16.0 or r2.get("exit_fired", false)
        total += float(r1.get("secs", 0.0)) + float(r2.get("secs", 0.0))
        print("  %s → %s：去 %s（%.1f 秒，到 %s）；回 %s" % [legs[i - 1][0], legs[i][0], "通" if r1["ok"] else str(r1), float(r1.get("secs", 0.0)), str(arrived1), "通" if r2["ok"] else str(r2)])
        if not (r1["ok"] and arrived1 and r2["ok"] and arrived2):
            bad += 1
    check("整条一段一段来回都走得通（%d 段有问题）" % bad, bad == 0)
    # 从东头一口气走到西头出口、再走回
    reenter()
    cv.reset_to(cv.SPAWN)
    var rw := walk(cv.points["to_garden"]["pos"])
    check("东头进门处一口气走到西头月亮门（%.1f 秒，切去后花园或到了半径）" % float(rw.get("secs", 0.0)), rw["ok"] and (rw.get("exit_fired", false) or (cv.pos - cv.points["to_garden"]["pos"]).length() <= 40.0))
    reenter()
    cv.reset_to(cv.arrival_from("garden"))
    var re := walk(cv.points["pavilion"]["pos"])
    check("西头进门处一口气走到亭子前沿（%.1f 秒）" % float(re.get("secs", 0.0)), re["ok"] and (cv.pos - cv.points["pavilion"]["pos"]).length() <= 50.0)
    print("RESULT " + ("PASS" if ok else "FAIL"))
    quit(0 if ok else 1)
