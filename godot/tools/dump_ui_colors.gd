extends SceneTree
## 倒一份「界面长什么颜色」的清单（庄Z2 10/5，罗-1 验收用）：开游戏、把各块画布都搭起来、开几样界面（对话框、全景地图），
## 把树上每个界面节点的颜色、字号、框样式（StyleBoxFlat 的底色边色边宽圆角；像素框 StyleBoxTexture 的图按内容算个指纹）、
## ColorRect / Polygon2D 的颜色、modulate 一行一样倒出来，按路径排好。改界面颜色的写法前后各倒一份，逐行比，一行不差才算画面没变。
## 用法：Godot --headless --path . --script res://tools/dump_ui_colors.gd -- --out=清单.txt
const Main = preload("res://scripts/main.gd")
var m
var started := false
var lines: PackedStringArray = []

func _initialize() -> void:
    m = Main.new()
    m.fast = true
    get_root().add_child(m)

func _process(_dt: float) -> bool:
    if started:
        return false
    started = true
    run()
    return false

func frames(n: int) -> void:
    for i in n:
        await process_frame

func _sb(sb: StyleBox) -> String:
    if sb == null:
        return "-"
    if sb is StyleBoxFlat:
        var f := sb as StyleBoxFlat
        return "flat bg=%s edge=%s w=%d,%d,%d,%d r=%d,%d,%d,%d shadow=%s/%d" % [f.bg_color.to_html(), f.border_color.to_html(),
            f.border_width_left, f.border_width_top, f.border_width_right, f.border_width_bottom,
            f.corner_radius_top_left, f.corner_radius_top_right, f.corner_radius_bottom_right, f.corner_radius_bottom_left,
            f.shadow_color.to_html(), f.shadow_size]
    if sb is StyleBoxTexture:
        var t := sb as StyleBoxTexture
        var img: Image = t.texture.get_image() if t.texture != null else null
        return "tex %s %s mod=%s" % [str(img.get_size()) if img else "-", img.get_data().hex_encode().md5_text() if img else "-", t.modulate_color.to_html()]
    if sb is StyleBoxEmpty:
        return "empty"
    return sb.get_class()

func _theme(t: Theme, tag: String) -> void:
    if t == null:
        return
    for type in t.get_type_list():
        for n in t.get_color_list(type):
            lines.append("%s theme %s color %s = %s" % [tag, type, n, t.get_color(n, type).to_html()])
        for n in t.get_stylebox_list(type):
            lines.append("%s theme %s sb %s = %s" % [tag, type, n, _sb(t.get_stylebox(n, type))])
        for n in t.get_font_size_list(type):
            lines.append("%s theme %s size %s = %d" % [tag, type, n, t.get_font_size(n, type)])
    lines.append("%s theme default_size = %d" % [tag, t.default_font_size])

func _walk(n: Node, path: String) -> void:
    var p := path + "/" + (str(n.name) if not str(n.name).begins_with("@") else n.get_class())
    if n is Control:   # 场景里一闪一闪的标记透明度一直在变，不记；界面节点的照记
        var ci := n as CanvasItem
        if ci.modulate != Color.WHITE or ci.self_modulate != Color.WHITE:
            lines.append("%s mod=%s self=%s" % [p, ci.modulate.to_html(), ci.self_modulate.to_html()])
    if n is Control:
        var c := n as Control
        _theme(c.theme, p)
        for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color", "font_shadow_color",
                "font_outline_color", "font_placeholder_color", "caret_color", "selection_color", "font_selected_color"]:
            if c.has_theme_color_override(k):
                lines.append("%s color %s = %s" % [p, k, c.get_theme_color(k).to_html()])
        for k in ["font_size", "normal_font_size"]:
            if c.has_theme_font_size_override(k):
                lines.append("%s size %s = %d" % [p, k, c.get_theme_font_size(k)])
        for k in ["panel", "normal", "hover", "pressed", "focus", "disabled", "hover_pressed", "read_only", "background", "fill"]:
            if c.has_theme_stylebox_override(k):
                lines.append("%s sb %s = %s" % [p, k, _sb(c.get_theme_stylebox(k))])
        if c is ColorRect:
            lines.append("%s rect %s" % [p, (c as ColorRect).color.to_html()])
    elif n is Polygon2D:
        lines.append("%s poly %s" % [p, (n as Polygon2D).color.to_html()])
    for ch in n.get_children():
        _walk(ch, p)

func run() -> void:
    var out := "user://ui_colors.txt"
    for a in OS.get_cmdline_user_args():
        if a.begins_with("--out="):
            out = a.substr(6)
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    for k in ["backhall", "lawn", "lake", "orchard", "parking", "plaza"] + m.AREA_IDS:
        m.ensure_canvas(k)
    await frames(4)
    _walk(m.ui, "ui")
    _theme(m.ui.theme if m.ui is Control else null, "ui-root")
    var f := FileAccess.open(out, FileAccess.WRITE)
    lines.sort()
    f.store_string("\n".join(lines) + "\n")
    f.close()
    print("DUMP %d 行 → %s" % [lines.size(), out])
    quit(0)
