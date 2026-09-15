extends SceneTree
## 验收：分层宴会厅（layered_hall.gd）的寻路、摇杆、两个交互点、遮挡前后。无界面跑，只看逻辑。
## 用法：Godot --headless --path . --script res://tools/test_layered.gd

var hall
var hits: Array = []
var started := false

func step(frames: int, stop_on := "") -> void:
    for i in frames:
        hall._process(1.0 / 60.0)
        if stop_on != "" and stop_on in hits:
            return

func _initialize() -> void:
    hall = load("res://scripts/layered_hall.gd").new()
    get_root().add_child(hall)

## 等场景挂进场景树以后（第一帧）再搭、再测
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
    var w: float = hall.cfg["size"][0]
    var h: float = hall.cfg["size"][1]

    # 0. 进场点、新人桌前、门口都能站
    print("0 进场点能站：", hall._free(hall.SPAWN), "  新人 ", hall.COUPLE_SPOT, "  门口 ", hall.door)
    ok = ok and hall._free(hall.SPAWN)

    # 1. 从门口点到新人桌前，应该走到并触发 couple
    hall.reset_to(hall.SPAWN)
    hall.go_to(hall.COUPLE_SPOT)
    print("1 去新人桌：路径 ", hall.path.size(), " 段")
    step(3000, "couple")
    var r1: bool = "couple" in hits
    print("  触发 couple：", r1, "  停在 ", hall.pos)
    ok = ok and r1

    # 2. 出口：arm 之后点门口，应该触发 exit
    hall.arm_exit()
    hall.go_to(hall.door)
    print("2 去门口：路径 ", hall.path.size(), " 段")
    step(3000, "exit")
    var r2: bool = "exit" in hits
    print("  触发 exit：", r2, "  停在 ", hall.pos)
    ok = ok and r2

    # 3. 随机点 60 个地方：能站的都要走到，且一步都不踩进不能走的格子
    var rng := RandomNumberGenerator.new()
    rng.seed = 7
    var reach := 0
    var tried := 0
    var inside := 0
    for i in 60:
        hall.couple_armed = false
        hall.exit_armed = false
        hall.reset_to(hall.SPAWN)
        var target := Vector2(rng.randf_range(0.0, w), rng.randf_range(0.0, h))
        if not hall._free(target):
            continue
        tried += 1
        hall.go_to(target)
        for f in 2400:
            hall._process(1.0 / 60.0)
            if not hall._free(hall.pos):
                inside += 1
                break
            if hall.path.is_empty():
                break
        if hall.pos.distance_to(target) < 6.0:
            reach += 1
        else:
            print("  没走到 ", target, " 停在 ", hall.pos)
    print("3 随机点：试 ", tried, " 个，走到 ", reach, " 个，走进障碍 ", inside, " 次")
    ok = ok and inside == 0 and reach == tried

    # 4. 摇杆：从门口一直往前推 4 秒，应该沿红毯往里走
    hall.reset_to(hall.SPAWN)
    hall.stick = Vector2(0.0, -1.0)
    step(240)
    hall.stick = Vector2.ZERO
    print("4 摇杆往前 4 秒：从 y=", hall.SPAWN.y, " 走到 y=", snappedf(hall.pos.y, 0.1))
    ok = ok and hall.pos.y < hall.SPAWN.y - 250.0 and hall._free(hall.pos)

    # 5. 摇杆斜推撞桌子：应该贴着桌边滑，不会进桌子
    hall.reset_to(Vector2(600, 700))
    print("  起点在空地上：", hall._free(hall.pos))
    hall.stick = Vector2(-1.0, 0.4).normalized()
    step(180)
    hall.stick = Vector2.ZERO
    print("5 摇杆斜推：停在 ", hall.pos, "  在空地上：", hall._free(hall.pos))
    ok = ok and hall._free(hall.pos)

    # 6. 前后：人站在桌子后面（脚在桌子着地线以上）时，桌子要画在人前面；站到桌子前面，人在前
    var t4: Dictionary = {}
    for o in hall.cfg["occluders"]:
        if o["id"] == "table_4":
            t4 = o
    var foot: float = t4["foot"]
    hall.reset_to(Vector2(452, foot - 150.0))
    hall._process(0.0)
    var behind: bool = hall.player.position.y < foot
    hall.reset_to(Vector2(452, foot + 20.0))
    hall._process(0.0)
    var front: bool = hall.player.position.y > foot
    print("6 桌子 4 前后：站桌后被挡 ", behind, "  站桌前挡桌 ", front)
    ok = ok and behind and front

    # 7. 人的大小：越往里越小
    var near_h: float = hall._px_h(900.0)
    var far_h: float = hall._px_h(330.0)
    print("7 人高：靠门口 ", snappedf(near_h, 0.1), " 像素，新人桌前 ", snappedf(far_h, 0.1), " 像素")
    ok = ok and near_h > far_h

    print("RESULT ", "PASS" if ok else "FAIL")
    quit()
