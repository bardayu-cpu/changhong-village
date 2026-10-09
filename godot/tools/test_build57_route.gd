extends SceneTree
## 第 57 版（build57 bd139d9）的出入口和路线（01 F 10/3 派，03 写）。不改游戏代码；存档指到临时文件。
##   （10/4 连图 02 E 照新路线改）
##   1 开头往哪走：每次都开车进来、停车场自己车旁下车；没进过迎宾院的金箭头指去迎宾院的口
##   2 画布之间的来回：停车场东口 ↔ 迎宾院西北口：到哪、站在哪
##   3 没吃完就出大门：不拦、到前门、往西回停车场不指车、不弹【待补】字样；吃完出大门过前门回停车场、指自己的车
##   4 第一次走进迎宾院才说「到啦～」、进过一次存档记 court_seen
## 整条路线（新号 15 步）跑 test_first_visit.gd（02 照停车场改过），不在这里重复。
## 用法：Godot --headless --path . --script res://tools/test_build57_route.gd     最后一行 RESULT PASS 才算过
const Main = preload("res://scripts/main.gd")
const CourtCopy = preload("res://scripts/court_copy.gd")
const DT := 1.0 / 60.0

var m
var started := false
var ok := true

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

func frames(n: int) -> void:
    for i in n:
        await process_frame

func tick(n: int) -> void:
    for i in n:
        m.cv._process(DT)
        m._process(DT)

func walk_to(target: Vector2, secs := 60.0) -> void:
    m.cv.go_to(target)
    for i in int(secs / DT):
        tick(1)
        if m.cv.path.is_empty() or m.switching:
            break

func wait_state(s: String, secs := 6.0) -> void:
    for i in int(secs * 60.0):
        if m.state == s and not m.switching:
            await frames(2)
            return
        await process_frame

func reset_save(seen: bool, welcomed: bool, signed: bool, whisper := false) -> void:
    m.court_save.court_seen = seen
    m.court_save.welcomed = welcomed
    m.court_save.signed_in = signed
    m.court_save.whisper_done = whisper

func run() -> void:
    get_root().size = Vector2i(540, 960)
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await frames(2)
    m.court_save.local_path = "user://test_b57_route_court.json"
    m.games_save.local_path = "user://test_b57_route_games.json"
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    m.cloud.fake_blessings = []

    # 10/4 连图（02 E 照新路线改，01 G 派）：每次进山庄都先自动开车停进停车场（fast 下直接到车旁）；停车场东口去迎宾院、迎宾院西北口回停车场；
    # 湖边改从后花园、果园进（停车场、迎宾院不再直通湖边，这两条挪进 test_liantu.gd 的「每个口来回走」）；迎宾院大门出去是前门，往西进停车场找车
    print("1 开头往哪走")
    reset_save(false, false, false)
    await m._start_play()
    await wait_state("parking")
    var pk = m.parking
    check("新存档：开车进来停好，从停车场自己车旁下车（%s）、金箭头指去迎宾院的口、不指车" % str(pk.pos), m.state == "parking" and pk.pos == pk.SPAWN and pk.gate_hint and not pk.car_hint)
    reset_save(false, true, false)
    await m._start_play()
    await wait_state("parking")
    check("老存档（迎过了、没记 court_seen）：也是开车进来停车场下车（%s），不指大门" % str(pk.pos), m.state == "parking" and pk.pos == pk.SPAWN and not pk.gate_hint)
    reset_save(false, false, true)
    await m._start_play()
    await wait_state("parking")
    check("老存档（签过到）：停车场下车", m.state == "parking")
    reset_save(true, false, false)
    await m._start_play()
    await wait_state("parking")
    check("记过进过迎宾院：停车场下车", m.state == "parking")
    check("seen_court() 老存档三种都算进过", (func():
        reset_save(false, true, false)
        var a: bool = m.court_save.seen_court()
        reset_save(false, false, true)
        var b: bool = m.court_save.seen_court()
        reset_save(true, false, false)
        var c: bool = m.court_save.seen_court()
        reset_save(false, false, false)
        return a and b and c and not m.court_save.seen_court()).call())

    print("2 画布之间来回")
    reset_save(false, false, false)
    await m._start_play()
    await wait_state("parking")
    walk_to(pk.spot_pos("to_court"))
    await wait_state("court")
    await frames(3)
    var c = m.court
    check("停车场东口 → 迎宾院西北口里边（%s）" % str(c.pos), m.state == "court" and c.pos.distance_to(c.arrival_from("parking")) < 1.0)
    check("第一次走进迎宾院：说「到啦～」、记 court_seen", m.dialog.visible and m.dialog_text.text == m.LINE_ARRIVE and m.court_save.court_seen)
    walk_to(c.spot_pos("to_parking"))
    await wait_state("parking")
    check("迎宾院西北口 → 停车场东口里边（%s）" % str(pk.pos), m.state == "parking" and pk.pos.distance_to(pk.arrival_from("court")) < 1.0)
    walk_to(pk.spot_pos("to_court"))
    await wait_state("court")

    print("3 出大门去前门、回停车场")
    reset_save(true, true, false, false)
    m.court_save.gate_open()
    check("没吃完（没签到没写悄悄话）：大门不开", not m.court_save.gate_open())
    walk_to(c.SPAWN)
    walk_to(c.spot_pos("gate") + Vector2(0, -150))
    walk_to(c.spot_pos("gate"))
    await wait_state("frontgate")
    var fg = m.areas["frontgate"]
    check("没吃完往外走：不拦，到了前门（%s）" % str(fg.pos), m.state == "frontgate")
    var txt: String = m.dialog_text.text if m.dialog.visible else ""
    check("没吃完弹的话不带开发字样（「%s」）" % txt.replace("\n", "／"), not txt.contains("待") and not txt.contains("预留"))
    walk_to(fg.spot_pos("to_parking"))
    await wait_state("parking")
    check("前门西口 → 停车场：没吃完不指车（car_hint 关）、不指大门（进过了）", not pk.car_hint and not pk.gate_hint)
    walk_to(pk.spot_pos("to_court"))
    await wait_state("court")
    m.court_save.signed_in = true
    m.court_save.whisper_done = true
    check("签过到、写过悄悄话：大门开了", m.court_save.gate_open())
    walk_to(c.SPAWN)
    walk_to(c.spot_pos("gate") + Vector2(0, -150))
    walk_to(c.spot_pos("gate"))
    await wait_state("frontgate")
    walk_to(fg.spot_pos("to_parking"))
    await wait_state("parking")
    check("吃完出大门、过前门回停车场，金箭头指自己的车（%s）" % str(pk.pos), m.state == "parking" and pk.car_hint)
    walk_to(pk.spot_pos("my_car"))
    await frames(3)
    check("走到车旁：说送别那两句、箭头收", m.dialog_text.text.begins_with(CourtCopy.text("gate_bye")) and not pk.car_hint)

    print("RESULT " + ("PASS" if ok else "FAIL"))
    quit(0 if ok else 1)
