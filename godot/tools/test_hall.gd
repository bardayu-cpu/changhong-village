extends SceneTree
## 验收：宴会厅寻路、摇杆、两个交互点。无界面跑，只看逻辑。

var hall
var hits: Array = []

func step(frames: int, stop_on := "") -> void:
    for i in frames:
        hall._process(1.0 / 60.0)
        if stop_on != "" and stop_on in hits:
            return

var started := false

func _initialize() -> void:
    var Hall = load("res://scripts/hall.gd")
    hall = Hall.new()
    get_root().add_child(hall)

## 等宴会厅挂进场景树以后（第一帧）再搭、再测
func _process(_dt: float) -> bool:
    if started:
        return false
    started = true
    hall.build(2, "测试", SystemFont.new())
    run()
    return false

func run() -> void:
    hall.reached.connect(func(w): hits.append(w))
    var ok := true

    # 1. 从门口点到新人桌前，应该走到并触发 couple
    hall.reset_to(hall.SPAWN)
    hall.go_to(Vector2(0.0, -14.6))
    print("1 去新人桌：路径 ", hall.path.size(), " 段")
    step(3000, "couple")
    var r1: bool = "couple" in hits
    print("  触发 couple：", r1, "  停在 ", hall.pos)
    ok = ok and r1

    # 2. 出口：arm 之后点门口，应该触发 exit
    hall.arm_exit()
    hall.go_to(Vector2(0.0, 3.3))
    print("2 去门口：路径 ", hall.path.size(), " 段")
    step(3000, "exit")
    var r2: bool = "exit" in hits
    print("  触发 exit：", r2, "  停在 ", hall.pos)
    ok = ok and r2

    # 3. 随机点 40 个地方：能走到的都要有路，且不卡死、不穿过障碍
    var rng := RandomNumberGenerator.new()
    rng.seed = 7
    var reach := 0
    var tried := 0
    var inside := 0
    for i in 40:
        hall.couple_armed = false
        hall.exit_armed = false
        hall.reset_to(Vector2(0.0, 0.5))
        var target := Vector2(rng.randf_range(hall.X0, hall.X1), rng.randf_range(hall.Z0, hall.Z1))
        if not hall._free(target):
            continue
        tried += 1
        hall.go_to(target)
        for f in 2400:
            hall._process(1.0 / 60.0)
            if not hall._free(hall.pos, 0.2):
                inside += 1
                break
            if hall.path.is_empty():
                break
        if hall.pos.distance_to(target) < 0.6:
            reach += 1
        else:
            print("  没走到 ", target, " 停在 ", hall.pos, " 目标格是否能走：", not hall.nav.is_point_solid(hall._cell_of(target)))
    print("3 随机点：试 ", tried, " 个，走到 ", reach, " 个，走进障碍 ", inside, " 次")
    ok = ok and inside == 0 and reach >= int(tried * 0.9)

    # 4. 摇杆：从门口一直往前推 4 秒，应该沿红毯往里走，不穿墙
    hall.reset_to(hall.SPAWN)
    hall.stick = Vector2(0.0, -1.0)
    step(240)
    hall.stick = Vector2.ZERO
    print("4 摇杆往前 4 秒：从 z=", hall.SPAWN.y, " 走到 z=", snappedf(hall.pos.y, 0.01))
    ok = ok and hall.pos.y < hall.SPAWN.y - 8.0 and hall._free(hall.pos, 0.2)

    # 5. 摇杆斜推撞桌子：应该贴着桌边滑，不会进桌子
    hall.reset_to(Vector2(0.9, -6.5))
    print("  起点在空地上：", hall._free(hall.pos, 0.2))
    hall.stick = Vector2(1.0, -0.3).normalized()
    step(180)
    hall.stick = Vector2.ZERO
    print("5 摇杆斜推：停在 ", hall.pos, "  在空地上：", hall._free(hall.pos, 0.2))
    ok = ok and hall._free(hall.pos, 0.2)

    print("RESULT ", "PASS" if ok else "FAIL")
    quit()
