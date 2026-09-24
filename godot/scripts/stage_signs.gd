extends Node2D
## 婚礼台上的字（阿鱼 9/24 v11：「舞台上可以增加时间：开席时间：2025 年 06 月 15 日，爱女：阿鱼 & 贤婿：Toretto」，
## 「舞台的下方有个滚动的 led 屏，滚动播出当前有多少人在场」）。01 定：字用字体写，不画进图。
## 横幅：挂在婚礼台顶上的一条红布，两行金字；LED 屏：贴在婚礼台正面台沿上，黑底橘黄点阵字从右往左滚。
## 位置、字都从场景配置 scene.json 的 stage 读（tools/layout_55/make_layout55.py 写），没有 stage 这块就什么都不画。
## 礼金那一行 01 说先不做（等阿鱼定写「谁送了多少」还是只写「谁送了」加总数）

const RED := Color("#a51d1d")
const GOLD := Color("#f2c55c")
const GOLD_DARK := Color("#9c6a1f")
const LED_BG := Color("#140806")
const LED_ON := Color("#ffb13b")
const LED_FMT := "现在 %d 人在场"
const LED_GAP := "　　·　　"

var font: Font
var banner: PanelContainer
var led: Control
var led_text: Label
var led_speed := 40.0     # 每秒滚多少像素（画布像素）
var count := -1

func setup(f: Font, cfg: Dictionary) -> void:
    font = f
    if cfg.has("banner"):
        _banner(cfg["banner"])
    if cfg.has("led"):
        _led(cfg["led"])

func _label(text: String, size: int, color: Color) -> Label:
    var l := Label.new()
    l.text = text
    if font != null:
        l.add_theme_font_override("font", font)
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return l

func _banner(b: Dictionary) -> void:
    var r: Array = b["rect"]
    banner = PanelContainer.new()
    banner.name = "banner"
    var sb := StyleBoxFlat.new()
    sb.bg_color = RED
    sb.border_color = GOLD_DARK
    sb.set_border_width_all(2)
    sb.border_width_top = 0
    sb.corner_radius_bottom_left = 4
    sb.corner_radius_bottom_right = 4
    sb.content_margin_top = 2
    sb.content_margin_bottom = 2
    sb.shadow_color = Color(0, 0, 0, 0.35)
    sb.shadow_size = 3
    sb.shadow_offset = Vector2(0, 2)
    banner.add_theme_stylebox_override("panel", sb)
    banner.position = Vector2(float(r[0]), float(r[1]))
    banner.size = Vector2(float(r[2]), float(r[3]))
    banner.custom_minimum_size = banner.size
    banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 0)
    v.alignment = BoxContainer.ALIGNMENT_CENTER
    v.mouse_filter = Control.MOUSE_FILTER_IGNORE
    banner.add_child(v)
    for line in b.get("lines", []):
        v.add_child(_label(str(line), int(b.get("font_size", 16)), GOLD))
    add_child(banner)

func _led(c: Dictionary) -> void:
    var r: Array = c["rect"]
    led_speed = float(c.get("speed", led_speed))
    led = Panel.new()
    led.name = "led"
    var sb := StyleBoxFlat.new()
    sb.bg_color = LED_BG
    sb.border_color = Color("#3a2a20")
    sb.set_border_width_all(2)
    led.add_theme_stylebox_override("panel", sb)
    led.position = Vector2(float(r[0]), float(r[1]))
    led.size = Vector2(float(r[2]), float(r[3]))
    led.clip_contents = true
    led.mouse_filter = Control.MOUSE_FILTER_IGNORE
    led_text = _label("", int(c.get("font_size", 18)), LED_ON)
    led_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    led_text.size = Vector2(10, led.size.y)
    led_text.position = Vector2(led.size.x, 0)
    led.add_child(led_text)
    # 点阵：每隔 2 像素一道暗线，横竖都有，看着像 LED 灯珠
    var dots := TextureRect.new()
    var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
    img.fill(Color(0, 0, 0, 0))
    img.set_pixel(1, 0, Color(0, 0, 0, 0.55))
    img.set_pixel(0, 1, Color(0, 0, 0, 0.55))
    img.set_pixel(1, 1, Color(0, 0, 0, 0.55))
    dots.texture = ImageTexture.create_from_image(img)
    dots.stretch_mode = TextureRect.STRETCH_TILE
    dots.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    dots.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
    dots.size = led.size
    dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
    led.add_child(dots)
    add_child(led)
    set_count(0)

## 在场人数变了才换字（换字不从头滚，接着滚）
func set_count(n: int) -> void:
    if led_text == null or n == count:
        return
    count = n
    var one := LED_FMT % n
    # 一屏放不下两遍就接着拼，滚起来首尾相接
    led_text.text = one + LED_GAP + one + LED_GAP
    led_text.size = Vector2(led_text.get_combined_minimum_size().x, led.size.y)

func led_line() -> String:
    return LED_FMT % count if count >= 0 else ""

func _process(dt: float) -> void:
    if led_text == null:
        return
    led_text.position.x -= led_speed * dt
    # 滚过半条（一遍字加间隔）就挪回来，看着是无缝一直滚
    var half := led_text.size.x * 0.5
    if led_text.position.x < -half:
        led_text.position.x += half
