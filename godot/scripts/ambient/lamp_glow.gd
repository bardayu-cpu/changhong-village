extends Node2D
## 灯光明暗呼吸：每盏灯上叠一圈暖光（加法混合），亮度慢慢起伏，各盏节奏错开。
## 所有灯在这一个节点里一次画完：同一张光圈图、同一种混合，手机上只多一次绘制。
## 光圈是运行时生成的渐变，不加图。档位见 ambient.gd：2 照常；1 少刷几次；0 停在静态亮光、不再刷

const FPS_FULL := 20.0     # 呼吸很慢，一秒刷 20 次看不出一跳一跳
const FPS_LOW := 8.0

var points: Array = []     # 每盏灯的光心（画布坐标）
var radius := 44.0
var alpha := 0.22          # 平均亮度
var breathe := 0.08        # 上下起伏多少
var periods: Array = []    # 每盏一圈几秒
var phases: Array = []
var tex: GradientTexture2D
var _t := 0.0
var _acc := 0.0
var _still := false
var amb: Script            # ambient.gd（读档位）；互相 preload 会绕圈，这里搭的时候 load 一次

func setup(pts: Array, g: Dictionary) -> void:
    amb = load("res://scripts/ambient/ambient.gd")
    points = pts
    radius = float(g.get("r", radius))
    alpha = float(g.get("alpha", alpha))
    breathe = float(g.get("breathe", breathe))
    var pr: Array = g.get("period", [3.2, 4.6])
    var rng := RandomNumberGenerator.new()
    rng.seed = 1004                      # 每次进来同一盏灯同一个节奏，截图对得上
    for i in points.size():
        periods.append(rng.randf_range(float(pr[0]), float(pr[1])))
        phases.append(rng.randf() * TAU)
    var c: Array = g.get("color", [1.0, 0.78, 0.42])
    var gr := Gradient.new()
    gr.set_color(0, Color(c[0], c[1], c[2], 1.0))
    gr.set_color(1, Color(c[0], c[1], c[2], 0.0))
    tex = GradientTexture2D.new()
    tex.gradient = gr
    tex.width = 64
    tex.height = 64
    tex.fill = GradientTexture2D.FILL_RADIAL
    tex.fill_from = Vector2(0.5, 0.5)
    tex.fill_to = Vector2(1.0, 0.5)
    var m := CanvasItemMaterial.new()
    m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    material = m
    z_index = int(g.get("z", 1))         # 压在零件、人上面一点点（光），在名牌、飘落下面

## 第 i 盏这一刻的亮度
func glow_alpha(i: int, t: float) -> float:
    if amb.level <= 0:
        return alpha
    return alpha + breathe * sin(TAU * t / float(periods[i]) + float(phases[i]))

func _process(dt: float) -> void:
    _t += dt
    if amb.level <= 0:
        if not _still:
            _still = true
            queue_redraw()
        return
    _still = false
    _acc += dt
    if _acc >= 1.0 / (FPS_FULL if amb.level >= 2 else FPS_LOW):
        _acc = 0.0
        queue_redraw()

func _draw() -> void:
    var s := Vector2(radius, radius) * 2.0
    for i in points.size():
        draw_texture_rect(tex, Rect2(points[i] - s / 2.0, s), false, Color(1, 1, 1, glow_alpha(i, _t)))
