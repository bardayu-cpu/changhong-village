extends SceneTree
## 第 68 版路牌总表（07 10/4）：十四块每块「去…」「回…」牌，把游戏里那块牌子原样复制出来（同字体、同底色、同大小），按块一行排成一张表截下来。
## 要有窗口：Godot --path . --resolution 1500x1000 --script res://tools/shot_signs68.gd -- --out=图.png
const Main = preload("res://scripts/main.gd")
var m
var started := false
var opt := {"out": "", "ver": "第 69 版"}

func _initialize() -> void:
    for a in OS.get_cmdline_user_args():
        if a.begins_with("--") and "=" in a:
            var kv := a.substr(2).split("=", true, 1)
            opt[kv[0]] = kv[1]
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
    var keys: Array = ["court", "backhall", "lawn", "lake", "orchard", "parking", "plaza"] + m.AREA_IDS
    for k in keys:
        if k != "court":
            m.ensure_canvas(k)
    var layer := CanvasLayer.new()
    layer.layer = 100
    get_root().add_child(layer)
    var bg := ColorRect.new()
    bg.color = Color("#cfc4ad")   # 浅地面色，牌子的半透明木牌底看得出
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    layer.add_child(bg)
    var title := Label.new()
    title.text = str(opt.get("ver", "第 69 版")) + "路牌总表：往上、往左箭头在字前，往右、往下箭头在字后（游戏里的牌子原样复制，同字体、同底色、同大小）"
    title.add_theme_font_override("font", m.font)
    title.add_theme_font_size_override("font_size", 22)
    title.add_theme_color_override("font_color", Color("#2b1d16"))
    title.position = Vector2(20, 12)
    layer.add_child(title)
    var y := 56.0
    var total := 0
    for k in keys:
        var c = m.court if k == "court" else m._canvas_by(k)
        var row := Label.new()
        row.text = "迎宾院" if k == "court" else str(c.cfg.get("title", k))
        row.add_theme_font_override("font", m.font)
        row.add_theme_font_size_override("font_size", 20)
        row.add_theme_color_override("font_color", Color("#2b1d16"))
        row.position = Vector2(20, y + 4)
        layer.add_child(row)
        var x := 150.0
        for l in c.labels.get_children():
            if not l is Label or not l.has_meta("dir"):
                continue
            var d := (l as Label).duplicate() as Label
            d.position = Vector2(x, y)
            layer.add_child(d)
            d.size = d.get_combined_minimum_size()
            x += d.size.x + 18.0
            total += 1
        y += 50.0
    for i in 6:
        await process_frame
    await RenderingServer.frame_post_draw
    get_root().get_texture().get_image().save_png(opt["out"])
    print("SHOT DONE ", total)
    quit()
