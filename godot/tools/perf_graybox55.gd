extends SceneTree
## 量帧率（01 D 9/29「报电脑上约 550 人时的帧率」）：真的 55 桌灰盒厅（不是 perf_hall55.gd 那种纯色块试验），
## 进厅后人从大门一路蛇形走到婚礼台前再走回来，镜头跟着扫过全部 55 张桌；关垂直同步，量每秒帧率、这一秒里最慢一帧、画图调用次数。
## 要开窗口跑（headless 不画图，量不出帧率）：
##   Godot --path . --resolution 540x960 --script res://tools/perf_graybox55.gd -- --secs=20 [--feast=pre|feast]
##   --feast：亲友强制开席前（在厅里走动）／开席（坐下、敬酒、打牌）；不给就按北京时间
## 最后一行是汇总

const Main = preload("res://scripts/main.gd")

var m
var started := false
var secs := 20.0
var feast := ""

func _initialize() -> void:
    for a in OS.get_cmdline_user_args():
        if a.begins_with("--secs="):
            secs = float(a.substr(7))
        elif a.begins_with("--feast="):
            feast = a.substr(8)
    DirAccess.remove_absolute(ProjectSettings.globalize_path(Main.HALL55_FLAG))
    m = Main.new()
    m.fast = true
    get_root().add_child(m)

func _process(_dt: float) -> bool:
    if started:
        return false
    started = true
    run()
    return false

func run() -> void:
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    m.feast_force = feast
    await m._set_hall55(true, false)
    await m._enter_banquet()
    await create_timer(1.5).timeout
    m.dialog.visible = false
    var h = m.hall
    h.couple_armed = false
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    var nrel: int = h.life.relatives.rels.size() if h.life.relatives != null else 0
    var people: int = h.life.guests.size() + h.life.waiters.size() + h.resident_nodes.size() + nrel + 1 + 2   # 宾客、服务员、坐着的真人、亲友、自己、新人
    print("厅里的人：NPC 宾客 %d、服务员 %d、坐着的真人 %d、亲友 %d（%s）、自己 1、新人 2，共 %d" % [
        h.life.guests.size(), h.life.waiters.size(), h.resident_nodes.size(), nrel,
        "开席" if h.life.relatives != null and h.life.relatives.feast else "开席前", people])
    var sz := Vector2(float(h.cfg["size"][0]), float(h.cfg["size"][1]))
    var y0: float = h.SPAWN.y - 60.0     # 别踩进大门那圈（一踩就出厅）
    var y1 := 560.0
    var t := 0.0
    var t_start := Time.get_ticks_msec()
    var last_us := Time.get_ticks_usec()
    var slow := 0.0          # 这一秒里最慢一帧（毫秒）
    var frame_ms: Array = []
    var next := 1.0
    var fps: Array = []
    var proc: Array = []
    var draws: Array = []
    while t < secs:
        await process_frame
        t = float(Time.get_ticks_msec() - t_start) / 1000.0
        var now := Time.get_ticks_usec()
        var ms := float(now - last_us) / 1000.0
        last_us = now
        slow = maxf(slow, ms)
        if t > 1.0:
            frame_ms.append(ms)
        # 去程、回程各一半时间；x 左右摆（西墙 150 到东边 1390，东侧门那圈留开）
        var k := fmod(t / secs * 2.0, 2.0)
        var f := k if k <= 1.0 else 2.0 - k
        h.pos = Vector2(770.0 + sin(t * 1.3) * 620.0, lerpf(y0, y1, f))
        if t >= next:
            next += 1.0
            fps.append(Engine.get_frames_per_second())
            proc.append(slow)
            slow = 0.0
            draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
            print("  %2d 秒：%3d 帧/秒  最慢一帧 %.1f 毫秒  画图调用 %d  镜头 y %.0f" % [fps.size(), fps[-1], proc[-1], draws[-1], h.cam.position.y])
    fps.remove_at(0)   # 第一秒还在热身
    var lo: float = fps.min()
    var avg := 0.0
    for v in fps:
        avg += v
    avg /= fps.size()
    proc.remove_at(0)
    var pmax: float = proc.max()
    frame_ms.sort()
    var p99: float = frame_ms[int(frame_ms.size() * 0.99)]
    var over := 0
    for v in frame_ms:
        if v > 1000.0 / 60.0:
            over += 1
    var dmax: float = draws.max()
    print("汇总：%d 人，窗口 %s，关垂直同步，平均 %.0f 帧/秒，最低 %.0f；%d 帧里 99%% 的帧在 %.1f 毫秒内，最慢一帧 %.1f 毫秒，慢过 60 帧（16.7 毫秒）的 %d 帧；画图调用最多 %d" % [
        people, get_root().size, avg, lo, frame_ms.size(), p99, pmax, over, dmax])
    DirAccess.remove_absolute(ProjectSettings.globalize_path(Main.HALL55_FLAG))
    quit(0)
