extends SceneTree
## 截画布：给一块画布区域、缩放，出一张图（00 10/2 批、01 E 派；收编 03 的 render_north_1to1.patch）。
## 不改 main.gd：像测试那样把 main 起起来、进 55 桌厅，然后把厅那块子画面设成要的大小、镜头对准那块，存子画面。
## 一般别直接跑，用 tools/shot.sh（先把截图专用的 worktree 更新到指定提交、导入跑完、核过才截）。
##
## 用法（要有窗口，不能 --headless：headless 不出画面）：
##   Godot --path . --resolution 540x960 --script res://tools/shot_canvas.gd -- --out=图.png [下面这些]
##   --rect=x,y,w,h   画布上哪一块（整厅坐标，默认 0,0,1536,1024 = 北边那块）
##   --zoom=1         缩放：出图大小 = w×zoom、h×zoom（1 就是一比一）
##   --people=0       0 不放人（宾客、亲友、服务员、新人、自己、桌上的菜和牌都藏；红绸飘落也藏，除非给了 --fx），1 照常
##   --ui=0           0 只存厅那块子画面（没有界面）；1 存整个窗口（手机屏那样，带界面）：人站在 rect 中心，镜头照游戏自己的跟人走，缩放照手机

##   --hall=55        哪个厅：55（55 桌大厅）、44（第 44 版 12 桌厅）
##   --stand=rect     rect：人站在 rect 中心（--ui=1 时）；keep：人留在进厅时游戏放的地方（自己那桌边），截「进厅第一眼」
##   --feast=         空 = 照北京时间；feast 强制开席；pre 强制开席前（只有 --people=1 才看得出）；给了就快进 60 秒让亲友走到位
##   --preset=        给了就不走上面那套：照 main.gd 的截图预设（_setup_shot，跟 capture.sh 同一套）摆好整屏截（厨房、后厅这些），
##                    其余参数都不管。例：--preset=k04_start、--preset=kitchen_play_lv4、--preset=backhall
##   --lm_dir=        罗曼山庄的人（lm_people.gd）换一个文件夹读（绝对路径），比如拿假图看全换上的样子；空 = 照旧读游戏里的
##   --fx=            空 = 不飘；feast / entry / toast 放那一阵飘落（hall_festive.gd），快进 --fx_t 秒（默认 1.0）再截
## 出完打一行「SHOT SAVED <路径> <宽>x<高>」；出错打「SHOT FAILED 原因」，退出码 1

const Main = preload("res://scripts/main.gd")

var m
var started := false
var opt := {"rect": "0,0,1536,1024", "zoom": "1", "people": "0", "ui": "0", "hall": "55", "feast": "", "out": "", "stand": "rect", "fx": "", "fx_t": "1.0", "preset": "", "lm_dir": ""}

func _initialize() -> void:
    for a in OS.get_cmdline_user_args():
        if a.begins_with("--") and "=" in a:
            var kv := a.substr(2).split("=", true, 1)
            opt[kv[0]] = kv[1]
    if str(opt["lm_dir"]) != "":
        var LMPeople = load("res://scripts/lm_people.gd")
        if LMPeople != null:
            LMPeople.dir = str(opt["lm_dir"]).trim_suffix("/") + "/"
            LMPeople.clear_cache()
    m = Main.new()
    m.fast = true
    get_root().add_child(m)

func _process(_dt: float) -> bool:
    if started:
        return false
    started = true
    run()
    return false

func fail(why: String) -> void:
    print("SHOT FAILED ", why)
    quit(1)

func frames(n: int) -> void:
    for i in n:
        await process_frame

func run() -> void:
    if str(opt["out"]) == "":
        fail("没给 --out=")
        return
    var r: PackedStringArray = str(opt["rect"]).split(",")
    if r.size() != 4:
        fail("--rect 要 x,y,w,h")
        return
    var rect := Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
    var zoom: float = float(opt["zoom"])
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await frames(2)
    if str(opt["preset"]) != "":
        await m._setup_shot(str(opt["preset"]))
        await frames(50)
        await RenderingServer.frame_post_draw
        var pimg: Image = get_root().get_texture().get_image()
        if pimg.save_png(str(opt["out"])) != OK:
            fail("存不下 %s" % opt["out"])
            return
        print("SHOT SAVED ", opt["out"], " ", pimg.get_width(), "x", pimg.get_height())
        quit(0)
        return
    # 进厅：照 big_* 截图预设那条路（main.gd _setup_shot），只这一次切厅、不写本机开关
    m.nickname = "小李"
    await m._set_hall_variant("55" if str(opt["hall"]) == "55" else "", false)
    m.cloud.fake_no_news = true
    m.cloud.fake_arrival_mode = "card"
    await m._enter_banquet()
    await create_timer(2.0).timeout
    m.dialog.visible = false
    var hall = m.hall
    if str(opt["hall"]) == "55" and not hall.big:
        fail("没进 55 桌厅（这个提交的场景不对？）")
        return
    hall.couple_armed = false
    if str(opt["feast"]) != "":
        m._set_feast_force(str(opt["feast"]))
        var rel = hall.life.relatives
        if rel != null:
            for i in int(60.0 / 0.05):
                rel._process(0.05)   # 快进 60 秒：开席的亲友走回座位坐下、开席前的散开（跟 big_*_feast 截图预设一样）
    # 带界面的（手机屏）：人站在镜头对着的地方（跟截图预设一样，人在屏幕正中）；不带界面的：人站台前（藏不藏另说）
    var stand_at: Vector2 = rect.get_center() if str(opt["ui"]) != "0" else hall.COUPLE_SPOT + Vector2(0, 80)
    if str(opt["stand"]) != "keep":   # keep：人留在进厅时游戏放的地方（自己那桌边），截「进厅第一眼」用
        hall.reset_to(hall._cell_pos(hall._nearest_free(hall._cell_of(stand_at))))
    if str(opt["people"]) == "0":
        m._hide_people_for_shot()
        if hall.get("festive") != null and str(opt["fx"]) == "":
            hall.festive.visible = false   # 不放人的截图是「背景 + 零件」（03 拿它对 GPT 的色块），红绸飘落也藏
    var out_size := Vector2i(int(round(rect.size.x * zoom)), int(round(rect.size.y * zoom)))
    var sv: SubViewport = m.view.get_child(0)
    if str(opt["ui"]) == "0":
        hall.set_process(false)
        m.view.stretch = false
        sv.size = out_size
        await frames(5)
    if str(opt["ui"]) == "0":
        hall.cam.limit_left = -100000
        hall.cam.limit_top = -100000
        hall.cam.limit_bottom = 100000
        hall.cam.limit_right = 100000
        hall.cam.zoom = Vector2(zoom, zoom)
        hall.cam.position = rect.get_center()
        hall.cam.reset_smoothing()
    else:
        # 手机屏：镜头照游戏自己的跟人走法（缩放、贴边、跟人都跟截图预设一样），人站在 rect 中心最近能站的那格；--zoom 不管用
        hall.snap_cam()
    if str(opt["fx"]) != "":
        var fest = hall.get("festive")
        if fest == null:
            fail("这个提交的宴会厅没有飘落（hall_festive.gd）")
            return
        await frames(2)
        fest.request(str(opt["fx"]), [hall.pos, hall.pos + Vector2(70, 0)])
        for i in int(float(opt["fx_t"]) / 0.05):
            fest._step_fall(0.05)
    await frames(10)
    await RenderingServer.frame_post_draw
    var img: Image = (sv.get_texture() if str(opt["ui"]) == "0" else get_root().get_texture()).get_image()
    var err := img.save_png(str(opt["out"]))
    if err != OK:
        fail("存不下 %s（错误 %d）" % [opt["out"], err])
        return
    print("SHOT SAVED ", opt["out"], " ", img.get_width(), "x", img.get_height())
    quit(0)
