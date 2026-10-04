extends SceneTree
## 湖边波光画出来的像素、每帧多画几次（03 测第 67 版，01 H 10/4 派；要开窗口，headless 不画图）：
##   1 像素：同一位置、小船停住，「全关」「全开」「全关」连拍三张，头尾一样才算这一拍有效；全开比全关多出来的像素：
##     颜色必须是那两种亮一档的水色（176,198,222）（108,143,189）、不透明；原来的颜色必须对得上（108,143,189→176,198,222、56,90,144→108,143,189）；
##     横着连成一段的长度 2～8 格（相邻两个 12 格宽的小格可以连起来，单格 2～4）；一行一段
##   2 档位：2 档跟 1 档各量 40 拍，1 档的亮像素数约一半（0.35～0.65 倍）；0 档一个都没有
##   3 每帧多画几次：东半边、西半边、东西接缝三个位置，全关档 / 全开档来回 3 轮 × 90 帧取中位数；再单量「只有小船」「只有波光」各占多少
## 用法：Godot --path . --resolution 540x960 --script res://tools/check_lake_glint.gd     最后一行「CHECK」是汇总，ok 为 true 才算过
const Ambient = preload("res://scripts/ambient/ambient.gd")
var m
var started := false
var ok := true

func _initialize() -> void:
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    Engine.max_fps = 0
    m = load("res://scripts/main.gd").new()
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

func frames(n: int) -> void:
    for i in n:
        await process_frame

func shot() -> Image:
    await process_frame
    await RenderingServer.frame_post_draw
    var img: Image = get_root().get_texture().get_image()
    img.convert(Image.FORMAT_RGBA8)
    return img

func med(a: Array) -> float:
    var b := a.duplicate()
    b.sort()
    return float(b[b.size() / 2]) if not b.is_empty() else 0.0

func sample(n: int) -> Dictionary:
    var dc: Array = []
    var ob: Array = []
    var ms: Array = []
    var last := Time.get_ticks_usec()
    for i in n:
        await process_frame
        var now := Time.get_ticks_usec()
        ms.append((now - last) / 1000.0)
        last = now
        dc.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
        ob.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
    return {"draw": med(dc), "obj": med(ob), "ms": med(ms)}

func same(a: Image, b: Image) -> bool:
    return a.get_data() == b.get_data()

## 全开比全关多出来的像素分两类：波光那种（全关时是水色原色、全开时恰好是对应的亮一档颜色）和别的（人、鱼竿、乐手的呼吸、亮度噪音，不是波光，只数个数）
## 返回 {glint, other, bad_color, rows}：bad_color = 全开时变成「那两种亮色」可是原色对不上（映射错了）
func diff_glint(off: Image, on: Image) -> Dictionary:
    var to_cols := [Color8(176, 198, 222).to_html(false), Color8(108, 143, 189).to_html(false)]
    var map := {Color8(108, 143, 189).to_html(false): Color8(176, 198, 222).to_html(false), Color8(56, 90, 144).to_html(false): Color8(108, 143, 189).to_html(false)}
    var out := {"glint": 0, "other": 0, "bad_color": 0, "rows": {}}
    var w := off.get_width()
    var h := off.get_height()
    for y in h:
        var run_start := -1
        for x in w + 1:
            var is_glint := false
            if x < w:
                var a := off.get_pixel(x, y)
                var b := on.get_pixel(x, y)
                if a != b:
                    var ah := a.to_html(false)
                    if map.has(ah) and map[ah] == b.to_html(false) and b.a > 0.999:
                        is_glint = true
                        out["glint"] += 1
                    else:
                        out["other"] += 1
                        if b.to_html(false) in to_cols and b.a > 0.999 and not map.has(ah):
                            out["bad_color"] += 1   # 变成了亮水色，可原来不是水色
            if is_glint and run_start < 0:
                run_start = x
            elif not is_glint and run_start >= 0:
                if not out["rows"].has(y):
                    out["rows"][y] = []
                (out["rows"][y] as Array).append([run_start, x - 1])
                run_start = -1
    return out

func run() -> void:
    for i in 1200:
        if m.state == "title":
            break
        await process_frame
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    m.court_save.local_path = "user://check_lake_glint_court.json"
    await m._enter_court()
    m.dialog.visible = false
    m.ensure_canvas("lake")
    m._show_canvas("lake")
    m._goto("lake")
    var lk = m.lake
    lk.walking_enabled = false
    var amb = lk.get_node("ambient")
    var bob = amb.effects.filter(func(e): return e.get("boats") != null)[0]
    bob.set_process(false)   # 小船停住（光看波光）
    var res := {}
    print("1 像素")
    var spots := {"东半边（曲桥南边）": Vector2(2420, 900), "西半边（码头南边）": Vector2(900, 900), "东西接缝": Vector2(1536, 900)}
    var tot_n := 0
    var tot_other := 0
    var tot_bad := 0
    var seg_bad := 0
    var hist := {}
    var segs := 0
    var beats_ok := 0
    var rows_multi := 0
    for name in spots:
        lk.reset_to(spots[name])
        lk.face = "up"
        lk.cam.reset_smoothing()
        await frames(30)
        for k in 12:
            Ambient.set_forced(0)
            await frames(2)
            var a := await shot()
            Ambient.set_forced(2)
            await frames(1)
            var b := await shot()
            Ambient.set_forced(0)
            await frames(1)
            var c := await shot()
            if not same(a, c):
                continue
            beats_ok += 1
            var d := diff_glint(a, b)
            tot_n += int(d["glint"])
            tot_bad += int(d["bad_color"])
            tot_other += int(d["other"])
            for y in d["rows"]:
                var rs: Array = d["rows"][y]
                for r in rs:
                    segs += 1
                    var ln: int = int(r[1]) - int(r[0]) + 1
                    hist[ln] = int(hist.get(ln, 0)) + 1
                    if ln < 2 or ln > 8:
                        seg_bad += 1
    print("    有效的拍 %d 个（三个位置各 12 次试拍）；波光像素合计 %d 个；变成亮水色却原色不是水色的 %d 个；别的变了的像素 %d 个（人呼吸、乐手这些）；亮线 %d 段，长度不在 2～8 的 %d 段" % [beats_ok, tot_n, tot_bad, tot_other, segs, seg_bad])
    check("波光整格不透明、全开时那几格恰好变成对应的亮一档水色（%d 个像素）、没有把别的颜色刷成水色（%d 个）" % [tot_n, tot_bad], beats_ok >= 8 and tot_n > 100 and tot_bad == 0)
    print("    亮线长度分布（格数: 段数）：%s" % str(hist))
    check("亮线几乎都是 2～8 格长的横线（%d 段里 %d 段长度不对，要不到 12%%；被船、荷叶盖掉一截的会变短）" % [segs, seg_bad], segs > 20 and float(seg_bad) < 0.12 * float(segs))
    res["像素"] = {"有效拍": beats_ok, "波光像素": tot_n, "不对": tot_bad, "别的变了": tot_other, "线段": segs, "长度不对": seg_bad}

    print("2 档位")
    lk.reset_to(spots["西半边（码头南边）"])
    lk.cam.reset_smoothing()
    await frames(30)
    var cnt := {}
    for lv in [2, 1, 0]:
        var total := 0
        for k in 40:
            Ambient.set_forced(0)
            await frames(1)
            var a := await shot()
            Ambient.level = lv
            Ambient.forced = -1
            await frames(1)
            var b := await shot()
            total += int(diff_glint(a, b)["glint"])
        cnt[lv] = total
    Ambient.set_forced(-1)
    var ratio: float = float(cnt[1]) / maxf(1.0, float(cnt[2]))
    print("    各 40 拍亮像素：2 档 %d、1 档 %d（%.2f 倍）、0 档 %d" % [cnt[2], cnt[1], ratio, cnt[0]])
    check("1 档亮像素约一半（%.2f 倍，要 0.35～0.65）、0 档一个也没有（%d）" % [ratio, cnt[0]], ratio > 0.35 and ratio < 0.65 and int(cnt[0]) == 0)
    res["档位"] = {"2": cnt[2], "1": cnt[1], "0": cnt[0]}

    print("3 每帧多画几次")
    bob.set_process(true)
    var perf := {}
    for name in spots:
        lk.reset_to(spots[name])
        lk.face = "up"
        lk.cam.reset_smoothing()
        await frames(40)
        var off_d: Array = []
        var on_d: Array = []
        for r in 3:
            Ambient.set_forced(0)
            await frames(10)
            off_d.append(await sample(90))
            Ambient.set_forced(2)
            await frames(10)
            on_d.append(await sample(90))
        var f := func(arr: Array, k: String) -> float:
            return med(arr.map(func(x): return float(x[k])))
        var row := {"关 画图": f.call(off_d, "draw"), "开 画图": f.call(on_d, "draw"), "关 对象": f.call(off_d, "obj"), "开 对象": f.call(on_d, "obj"), "关 毫秒": snappedf(f.call(off_d, "ms"), 0.01), "开 毫秒": snappedf(f.call(on_d, "ms"), 0.01)}
        perf[name] = row
        print("  ", name, " ", JSON.stringify(row))
    Ambient.set_forced(-1)
    res["画图"] = perf
    print("CHECK ", JSON.stringify({"ok": ok, "res": res}))
    quit(0 if ok else 1)
