extends Node2D
## 场景动效的总节点（05 10/4，01 G 派；清单 godot/回执/动效清单-1004.md）：每块画布搭完调一次 attach，照 data/ambient.json 里这块场景
## 写的几样挂上去（现在只有宴会厅宫灯呼吸）。效果全用代码画，不加图。
## 位置照场景数据里的零件找（比如宫灯照 art_lantern.png 那几块积木），不写死坐标：场景重排、零件挪了也跟着走。
## 不在的画布 process_mode 是停的（main.gd），挂在下面的效果跟着停。
##
## 降级（所有画布共用一个档位）：2 全开；1 降一档（以后的飘落、小动物停，灯光少刷几次）；0 全关（灯光只留静态亮光）
##   连续 LOW_SECS 秒低于 LOW_FPS 降一档，连续 LOW_SECS 秒低于 OFF_FPS 直接全关，连续 OK_SECS 秒到 OK_FPS 升一档。
##   宴会厅自己还有一套（layered_hall 的掉帧兜底，管宾客和飘落），两套各管各的。
##   调试版日志面板「动效」按钮、启动参数 --ambient=off / on 能强制开关；--ambient=none 一样都不挂（跟没加动效以前比、量性能用）。

const LampGlow = preload("res://scripts/ambient/lamp_glow.gd")
const CONFIG := "res://data/ambient.json"

const LOW_FPS := 50.0
const OFF_FPS := 40.0
const OK_FPS := 58.0
const LOW_SECS := 3
const OK_SECS := 10

static var level := 2          # 现在的档位
static var forced := -1        # -1 自己判；0、2 强制（调试按钮、启动参数）
static var _low_n := 0
static var _off_n := 0
static var _ok_n := 0

var _acc := 0.0

## 画布搭完调：scene 是场景数据里的 scene 名，items 是这块画布的零件（每件有 image、x、y、foot）
static func attach(canvas: Node2D, scene: String, items: Array) -> Node2D:
    var all = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
    if not all is Dictionary or not all.has(scene) or "--ambient=none" in OS.get_cmdline_user_args():
        return null
    var conf: Dictionary = all[scene]
    if forced < 0:
        for a in OS.get_cmdline_user_args():
            if a == "--ambient=off":
                forced = 0
            elif a == "--ambient=on":
                forced = 2
        if forced >= 0:
            level = forced
    var root = load("res://scripts/ambient/ambient.gd").new()
    root.name = "ambient"
    canvas.add_child(root)
    for g in conf.get("lamp_glow", []):
        var pts := find_points(items, str(g["image"]), Vector2(g["at"][0], g["at"][1]))
        if pts.is_empty():
            push_warning("[suqi] 动效：%s 里找不到 %s，灯光没挂" % [scene, g["image"]])
            continue
        var lg := LampGlow.new()
        lg.setup(pts, g)
        root.add_child(lg)
    print("[suqi] 动效：%s 挂了 %d 样" % [scene, root.get_child_count()])
    return root

## 零件里图名对得上的那几件，各取图上 at 那一点（零件左上角 + at）
static func find_points(items: Array, image: String, at: Vector2) -> Array:
    var out: Array = []
    for o in items:
        if o is Dictionary and str(o.get("image", "")).get_file() == image:
            out.append(Vector2(float(o["x"]), float(o["y"])) + at)
    return out

## 每秒一次：照帧数换档。拆成纯函数好测
static func step(fps: float) -> void:
    if forced >= 0:
        level = forced
        return
    _low_n = _low_n + 1 if fps < LOW_FPS else 0
    _off_n = _off_n + 1 if fps < OFF_FPS else 0
    _ok_n = _ok_n + 1 if fps >= OK_FPS else 0
    var was := level
    if _off_n >= LOW_SECS:
        level = 0
    elif _low_n >= LOW_SECS and level > 1:
        level = 1
    elif _ok_n >= OK_SECS and level < 2:
        level += 1
    if level != was:
        _low_n = 0
        _off_n = 0
        _ok_n = 0
        print("[suqi] 动效降级：%d → %d（%.0f 帧）" % [was, level, fps])

static func set_forced(v: int) -> void:
    forced = v
    level = v if v >= 0 else 2
    _low_n = 0
    _off_n = 0
    _ok_n = 0

func _process(dt: float) -> void:
    _acc += dt
    if _acc >= 1.0:
        _acc = 0.0
        step(Engine.get_frames_per_second())
