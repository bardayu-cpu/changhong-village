extends SceneTree
## 后厅镜头改成 1 倍以后，手机上看得到什么（lounge01 4406d23；01 E 10/3 派，03 写）。不改游戏代码。
## 窗口按手机竖屏 540×960，再过长屏 1170×2532（同比例的 585×1266）、真机 1080×1920、1080×2340；设窗口先等几帧。
## 每个窗口：子画面多大、镜头倍数、看得到画布多大一块（宽×高）；人站在每个关键点上，这个点和两个出口、厨房的点离屏幕边多远；
## 镜头倍数和「整倍放大」差多少（倍数 × 窗口缩放 要是整数，像素才不会一行宽一行窄）。
## 用法：Godot --headless --path . --script res://tools/test_lounge_view.gd     最后一行 RESULT PASS 才算过（只守：关键点都在屏里、不被切）
const Main = preload("res://scripts/main.gd")
var m
var started := false
var ok := true
var b

func _initialize() -> void:
    m = Main.new()
    m.fast = true
    get_root().add_child(m)
    create_timer(240.0).timeout.connect(func():
        print("RESULT FAIL 240 秒没跑完")
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

func run() -> void:
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await frames(2)
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    m.ensure_canvas("backhall")
    m._show_canvas("backhall")
    m._goto("backhall")
    b = m.backhall
    var sv: SubViewport = m.view.get_child(0)
    var spots := {"进场(宴会厅口)": Vector2(100, 780), "草坪口": Vector2(1440, 780), "化妆间门口 to_makeup": b.points["to_makeup"]["pos"], "休息间 lounge": b.points["lounge"]["pos"],
        "娱乐室门口 to_mahjong": b.points["to_mahjong"]["pos"], "厨房 pot": b.points["pot"]["pos"], "回宴会厅 to_hall": b.points["to_hall"]["pos"], "去草坪 to_lawn": b.points["to_lawn"]["pos"],
        "最北(休息间顶)": Vector2(504, 244), "最南(走廊下沿)": Vector2(768, 870), "厨房东头": Vector2(1500, 300)}
    for win in [Vector2i(540, 960), Vector2i(585, 1266), Vector2i(1080, 1920), Vector2i(1080, 2340), Vector2i(1170, 2532)]:
        get_root().size = win
        await frames(4)
        var logic: Vector2 = Vector2(float(win.x), float(win.y)) / (float(win.x) / 540.0)    # canvas_items 拉伸：宽锁 540
        var z: float = b.cam.zoom.x
        var scale_win: float = float(win.x) / 540.0
        var eff: float = z * scale_win
        var vis := Vector2(sv.size.x, sv.size.y) / z
        print("窗口 %dx%d：子画面 %s、镜头倍数 %.4f、看得到画布 %.0f×%.0f（画布 1536×1024），屏上 1 个画布像素 = %.3f 个屏幕像素（整数才不糊/不掉行）" % [win.x, win.y, str(sv.size), z, vis.x, vis.y, eff])
        for k in spots:
            var p: Vector2 = spots[k]
            b.reset_to(p)
            b.cam.reset_smoothing()
            await frames(2)
            var c: Vector2 = b.cam.get_screen_center_position()
            var half: Vector2 = vis * 0.5
            var rect := Rect2(c - half, vis)
            var body := Rect2(p.x - 20.0, p.y - 84.0, 40.0, 92.0)    # 人：脚点往上 84、左右各 20、脚下留 8
            var inside := rect.encloses(body)
            var mx: float = minf(minf(p.x - rect.position.x, rect.end.x - p.x), minf(p.y - rect.position.y, rect.end.y - p.y))
            if not inside or mx < 60.0:
                print("    %s %s：离屏边 %.0f 像素%s（屏里 %s）" % [k, str(p), mx, "" if inside else "，人被切到屏外", str(rect)])
            check("%dx%d 人站在「%s」，整个人（40×92）在屏里" % [win.x, win.y, k], inside)
    # 回到手机竖屏
    get_root().size = Vector2i(540, 960)
    print("RESULT " + ("PASS" if ok else "FAIL"))
    quit(0 if ok else 1)
