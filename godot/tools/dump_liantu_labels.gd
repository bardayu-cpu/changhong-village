extends SceneTree
## 倒各块的「去…」牌（字、位置、大小）：Godot --headless --path godot --script res://tools/dump_liantu_labels.gd。03 看第 65 版用，只列不判
const Main = preload("res://scripts/main.gd")
var m
var started := false
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
func run() -> void:
    get_root().size = Vector2i(540, 960)
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    var keys: Array = ["backhall", "lawn", "lake", "orchard", "parking", "plaza"] + m.AREA_IDS
    for k in keys:
        m.ensure_canvas(k)
    for k in ["court"] + keys:
        var c = m.court if k == "court" else m._canvas_by(k)
        print("== ", k)
        for l in c.labels.get_children():
            if l is Label:
                print("   「%s」 %s 尺寸 %s" % [(l as Label).text, str((l as Control).position), str((l as Control).size)])
    quit(0)
