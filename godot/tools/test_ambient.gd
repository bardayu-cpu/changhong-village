extends SceneTree
## 验收：场景动效公共架子 + 宴会厅宫灯呼吸（05 10/4，清单 回执/动效清单-1004.md）。无界面跑整个 main.gd：
## 1 宴会厅挂上了动效，20 盏宫灯都找到，光心在每盏灯图上 (24,40)（灯罩正中），一个节点一次画完、加法混合
## 2 亮度在 alpha ± breathe 里起伏，各盏错开；全关档停在平均亮度
## 3 降级：连续 3 秒低于 50 帧降一档，低于 40 帧全关，连续 10 秒 58 帧以上升一档；强制开关
## 4 切到别的画布，宴会厅的动效停（不跑 _process）
## 5 配置里没写的场景不挂（迎宾院现在没有）
## 用法：Godot --headless --path . --script res://tools/test_ambient.gd
## 最后一行 RESULT PASS 才算过

const Main = preload("res://scripts/main.gd")
const Ambient = preload("res://scripts/ambient/ambient.gd")

var m
var ok := true

func _initialize() -> void:
    run()

func check(name: String, cond: bool) -> void:
    print(("  好 " if cond else "  不行 ") + name)
    ok = ok and cond

func run() -> void:
    await process_frame
    m = Main.new()
    m.fast = true
    root.add_child(m)
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    var hall = m.hall
    var amb = hall.get_node_or_null("ambient")
    check("宴会厅挂上了动效", amb != null)
    if amb == null:
        print("RESULT FAIL")
        quit(1)
        return
    var lg = amb.get_child(0) if amb.get_child_count() > 0 else null
    check("挂了 1 样（宫灯呼吸）", amb.get_child_count() == 1 and lg != null and lg.points.size() == 20)
    var want: Array = []
    for o in hall.cfg["occluders"]:
        if str(o.get("image", "")).get_file() == "art_lantern.png":
            want.append(Vector2(float(o["x"]) + 24.0, float(o["y"]) + 40.0))
    check("20 盏光心都在灯罩正中（零件左上角 + (24,40)）", want.size() == 20 and lg.points == want)
    check("加法混合、压在零件上面一点（z 1）", lg.material is CanvasItemMaterial and lg.material.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD and lg.z_index == 1)
    # 亮度起伏
    Ambient.set_forced(-1)
    var lo := 1.0
    var hi := 0.0
    for k in 200:
        var a: float = lg.glow_alpha(0, k * 0.05)
        lo = minf(lo, a)
        hi = maxf(hi, a)
    check("亮度在 0.14～0.30 里起伏（%.2f～%.2f）" % [lo, hi], lo >= 0.14 - 0.001 and hi <= 0.30 + 0.001 and hi - lo > 0.1)
    check("各盏不同步", absf(lg.glow_alpha(0, 1.0) - lg.glow_alpha(1, 1.0)) > 0.001 or absf(lg.glow_alpha(0, 2.0) - lg.glow_alpha(1, 2.0)) > 0.001)
    # 降级
    Ambient.set_forced(-1)
    for i in 3: Ambient.step(45.0)
    check("连续 3 秒 45 帧：降到 1 档", Ambient.level == 1)
    for i in 3: Ambient.step(35.0)
    check("连续 3 秒 35 帧：全关", Ambient.level == 0)
    check("全关：亮度停在平均", is_equal_approx(lg.glow_alpha(3, 7.7), lg.alpha))
    for i in 9: Ambient.step(60.0)
    check("9 秒 60 帧：还不升", Ambient.level == 0)
    Ambient.step(60.0)
    check("10 秒 60 帧：升一档", Ambient.level == 1)
    for i in 10: Ambient.step(60.0)
    check("再 10 秒：全开", Ambient.level == 2)
    Ambient.step(30.0)
    Ambient.step(60.0)
    Ambient.step(30.0)
    check("偶尔一秒掉帧不降", Ambient.level == 2)
    Ambient.set_forced(0)
    for i in 20: Ambient.step(60.0)
    check("强制关：帧数再好也不开", Ambient.level == 0)
    Ambient.set_forced(-1)
    check("恢复自动：全开", Ambient.level == 2)
    # 切画布
    m._show_canvas("banquet")
    await process_frame
    check("在宴会厅：动效在跑", amb.can_process())
    m._show_canvas("court")
    await process_frame
    check("切到迎宾院：宴会厅的动效停", not amb.can_process())
    check("迎宾院配置里没写，不挂", m.court.get_node_or_null("ambient") == null)
    print("RESULT PASS" if ok else "RESULT FAIL")
    quit(0 if ok else 1)
