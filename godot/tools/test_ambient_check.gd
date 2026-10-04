extends SceneTree
## 宴会厅宫灯动效（05 做、第 66 版合进来），03 自己重测（01 G 10/4 派，不改游戏代码；不看 05 的 test_ambient，另起量法）：
##   1 降级的换档规矩，一秒一次喂帧数：连续 3 秒 < 50 帧降一档；连续 3 秒 < 40 帧直接全关（不经过一档）；
##     中间夹一秒好的就从头数；正好 50、正好 40 不算低；连续 10 秒 ≥ 58 才升一档，每升一档重新数 10 秒；50～58 之间不升不降；强制 0 / 2 不受帧数影响，取消强制回全开
##   2 全关停在中档：20 盏灯在任何时刻都画「中」那种大小；全开时各盏大小会变、20 秒里每盏三种大小都轮到
##   3 位置：宴会厅里 art_lantern.png 的积木数 = 光点数 = 20；每个光点落在灯图（24,40）、那一格是不透明的亮色（灯罩）
##   4 只在宴会厅跑：切去迎宾院，动效节点停（can_process 假）；回宴会厅恢复；没写配置的场景不挂
##   5 换档只重画：模拟 60 秒每帧，只在某盏灯换档那一帧才要重画；量重画帧的比例
## 用法：Godot --headless --path . --script res://tools/test_ambient_check.gd     最后一行 RESULT PASS 才算过
const Main = preload("res://scripts/main.gd")
const Ambient = preload("res://scripts/ambient/ambient.gd")

var m
var started := false
var ok := true

func _initialize() -> void:
    m = Main.new()
    m.fast = true
    get_root().add_child(m)
    create_timer(120.0).timeout.connect(func():
        print("RESULT FAIL 120 秒没跑完")
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

func feed(fps: float, secs: int) -> void:
    for i in secs:
        Ambient.step(fps)

func count_lanterns(v) -> int:
    var n := 0
    if v is Dictionary:
        for k in v:
            if str(k) == "image" and str(v[k]).get_file() == "art_lantern.png":
                n += 1
            else:
                n += count_lanterns(v[k])
    elif v is Array:
        for x in v:
            n += count_lanterns(x)
    return n

func run() -> void:
    get_root().size = Vector2i(540, 960)
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    m.cloud.fake_no_news = true
    m.nickname = "小李"
    var h = m.hall
    var amb = h.get_node_or_null("ambient")
    check("宴会厅挂了动效节点", amb != null)
    var lg = amb.get_child(0)

    print("1 降级的换档规矩")
    Ambient.set_forced(-1)
    check("起点：全开（2 档）", Ambient.level == 2)
    feed(45.0, 2)
    check("连续 2 秒 45 帧：还是 2 档", Ambient.level == 2)
    feed(45.0, 1)
    check("第 3 秒 45 帧：降到 1 档", Ambient.level == 1)
    feed(45.0, 6)
    check("再 6 秒 45 帧：留在 1 档（不会自己掉到 0）", Ambient.level == 1)
    feed(35.0, 3)
    check("1 档上连续 3 秒 35 帧：全关（0 档）", Ambient.level == 0)
    Ambient.set_forced(-1)
    feed(35.0, 3)
    check("从全开直接连续 3 秒 35 帧：一步到 0 档（不经过 1 档）", Ambient.level == 0)
    Ambient.set_forced(-1)
    feed(35.0, 2)
    feed(60.0, 1)
    feed(35.0, 2)
    check("低、低、好、低、低：中间夹一秒好的，重新数，还是 2 档", Ambient.level == 2)
    feed(50.0, 10)
    check("正好 50 帧不算低（连续 10 秒 50 帧）：还是 2 档", Ambient.level == 2)
    feed(40.0, 10)
    check("正好 40 帧不算「全关」，但低于 50：降到 1 档而不是 0 档", Ambient.level == 1)
    feed(57.0, 30)
    check("50～58 之间（57 帧）30 秒：不升不降，还是 1 档", Ambient.level == 1)
    feed(58.0, 9)
    check("58 帧 9 秒：还不升", Ambient.level == 1)
    feed(58.0, 1)
    check("第 10 秒 58 帧：升到 2 档（正好 58 算好）", Ambient.level == 2)
    Ambient.set_forced(-1)
    feed(35.0, 3)
    feed(60.0, 9)
    check("0 档上 60 帧 9 秒：还不升", Ambient.level == 0)
    feed(60.0, 1)
    check("第 10 秒：升到 1 档", Ambient.level == 1)
    feed(60.0, 9)
    check("1 档上又数 10 秒才升（9 秒还不升）", Ambient.level == 1)
    feed(60.0, 1)
    check("再 1 秒：升回 2 档", Ambient.level == 2)
    Ambient.set_forced(0)
    feed(120.0, 30)
    check("强制 0：120 帧 30 秒也不升", Ambient.level == 0)
    Ambient.set_forced(2)
    feed(10.0, 30)
    check("强制 2：10 帧 30 秒也不降", Ambient.level == 2)
    Ambient.set_forced(-1)
    check("取消强制：回到全开", Ambient.level == 2)

    print("2 全关停在中档；全开会变")
    var n_lamps: int = lg.points.size()
    var mid: int = int(lg.cycle[1 % lg.cycle.size()])
    Ambient.set_forced(0)
    var all_mid := true
    for t in [0.0, 0.7, 1.9, 5.3, 12.1, 33.3]:
        for i in n_lamps:
            if lg.size_of(i, t) != mid:
                all_mid = false
    check("全关：%d 盏灯在 6 个不同时刻都画「中」那种大小（第 %d 种）" % [n_lamps, mid], all_mid and n_lamps == 20)
    Ambient.set_forced(2)
    var seen := {}
    var changed := 0
    for i in n_lamps:
        seen[i] = {}
    var prev: Array = []
    for i in n_lamps:
        prev.append(lg.size_of(i, 0.0))
    var t := 0.0
    while t < 20.0:
        t += 1.0 / 60.0
        for i in n_lamps:
            var s: int = lg.size_of(i, t)
            seen[i][s] = true
            if s != prev[i]:
                changed += 1
                prev[i] = s
    var all3 := true
    for i in n_lamps:
        if (seen[i] as Dictionary).size() != 3:
            all3 = false
    check("全开：20 秒里每盏灯三种大小都轮到、共换档 %d 次（%d 盏，平均每盏每秒 %.2f 次）" % [changed, n_lamps, float(changed) / float(n_lamps) / 20.0], all3 and changed >= n_lamps * 14)
    Ambient.set_forced(-1)

    print("3 位置")
    var n_art := count_lanterns(h.cfg)
    print("    场景数据里 art_lantern.png 的积木：%d 个；光点 %d 个" % [n_art, n_lamps])
    check("积木数 = 光点数 = 20", n_art == 20 and n_lamps == 20)
    var art_img: Image = load("res://assets/layered/scene_roman_banquet_55/art_lantern.png").get_image() if ResourceLoader.exists("res://assets/layered/scene_roman_banquet_55/art_lantern.png") else null
    if art_img == null:
        for p in ["res://assets/layered/scene_roman_banquet_55/art/art_lantern.png", "res://assets/ambience/art_lantern.png"]:
            if ResourceLoader.exists(p):
                art_img = load(p).get_image()
    var shade_ok := false
    if art_img != null:
        if art_img.is_compressed():
            art_img.decompress()
        art_img.convert(Image.FORMAT_RGBA8)
        var px: Color = art_img.get_pixel(24, 40)
        shade_ok = px.a8 == 255 and (px.r8 + px.g8 + px.b8) / 3 > 180
        print("    灯图 %s，(24,40) 那一格 %s" % [str(art_img.get_size()), str(px)])
    check("灯图上（24,40）那一格不透明、是亮色（灯罩正中）", shade_ok)
    var inside := true
    for p in lg.points:
        if absf((p as Vector2).x - roundf(p.x)) > 0.001 or absf((p as Vector2).y - roundf(p.y)) > 0.001 or p.x < 0.0 or p.y < 0.0 or p.x > 1536.0 or p.y > 2091.0:
            inside = false
    check("20 个光点都是整数格、都在宴会厅里", inside)

    print("4 只在宴会厅跑")
    m._show_canvas("court")
    m._goto("court")
    for i in 3:
        await process_frame
    check("切去迎宾院：动效节点停了（can_process %s）" % str(amb.can_process()), not amb.can_process())
    m._show_canvas("banquet")
    m._goto("banquet")
    for i in 3:
        await process_frame
    check("回宴会厅：动效节点又跑（can_process %s）" % str(amb.can_process()), amb.can_process())
    var none_scene = Ambient.attach(m.court, "scene_not_in_config", [])
    check("没写配置的场景不挂（回 null）", none_scene == null)

    print("5 换档才重画")
    Ambient.set_forced(2)
    var redraw_frames := 0
    var shown: Array = []
    for i in n_lamps:
        shown.append(lg.size_of(i, 0.0))
    var tt := 0.0
    var frames := 3600
    for f in frames:
        tt += 1.0 / 60.0
        var need := false
        for i in n_lamps:
            if lg.size_of(i, tt) != int(shown[i]):
                need = true
        if need:
            redraw_frames += 1
            for i in n_lamps:
                shown[i] = lg.size_of(i, tt)
    print("    60 秒 3600 帧里要重画的有 %d 帧（%.0f%%），其余帧不用重画" % [redraw_frames, 100.0 * float(redraw_frames) / float(frames)])
    check("要重画的帧占 %.0f%%（20 盏灯各自约每秒换一档，所以大约每 3 帧一次，不是每帧）" % (100.0 * float(redraw_frames) / float(frames)), redraw_frames < frames * 0.6)
    Ambient.set_forced(-1)

    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
