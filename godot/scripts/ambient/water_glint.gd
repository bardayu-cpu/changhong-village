extends Sprite2D
## 湖面波光（05 10/4，01 H 派）：把像素画背景里水面那一块再画一遍，着色器 shaders/water_glint.gdshader 只留下一闪一闪的几段亮线。
## 一块水面一个节点、一次绘制；整格、不插值，1 美术像素 = 1 画布像素。贴在背景上面、人和零件下面（船、荷叶盖在亮线上）。
## 档位见 ambient.gd：2 照常；1 亮的机会减半；0 藏掉

var density := 0.05
var amb: Script

## bg：背景那张 Sprite（px_background_…）；g：配置（rect 是这张背景图上水面那一块 [x, y, w, h]，map 是 [[原色], [亮一档的色]] 两对）
func setup(bg: Sprite2D, g: Dictionary) -> void:
    amb = load("res://scripts/ambient/ambient.gd")
    texture = bg.texture
    centered = false
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    var r: Array = g["rect"]
    region_enabled = true
    region_rect = Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
    position = bg.position + Vector2(float(r[0]), float(r[1]))
    density = float(g.get("density", density))
    var m := ShaderMaterial.new()
    m.shader = load("res://shaders/water_glint.gdshader")
    var mp: Array = g["map"]
    for i in mini(mp.size(), 2):
        m.set_shader_parameter("from%d" % i, _c(mp[i][0]))
        m.set_shader_parameter("to%d" % i, _c(mp[i][1]))
    var cl: Array = g.get("cell", [12, 6])
    m.set_shader_parameter("cell", Vector2(float(cl[0]), float(cl[1])))
    m.set_shader_parameter("rate", float(g.get("rate", 3.0)))
    m.set_shader_parameter("density", density)
    material = m

static func _c(a: Array) -> Color:
    return Color8(int(a[0]), int(a[1]), int(a[2]), 255)

func _process(_dt: float) -> void:
    var lv: int = amb.level
    visible = lv > 0
    var want := density if lv >= 2 else density * 0.5
    if not is_equal_approx(float(material.get_shader_parameter("density")), want):
        material.set_shader_parameter("density", want)
