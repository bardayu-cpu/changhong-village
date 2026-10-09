extends SceneTree
## 倒各块的能走格子（给 03 画「看着是地面却走不了」的叠图用）：Godot --headless --path . --script res://tools/dump_walk_grid.gd -- --dir=目录
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
    var dir := ""
    for a in OS.get_cmdline_user_args():
        if a.begins_with("--dir="):
            dir = a.substr(6)
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
    for k in keys:
        var c = m.court if k == "court" else m._canvas_by(k)
        var f := FileAccess.open("%s/%s.json" % [dir, k], FileAccess.WRITE)
        f.store_string(JSON.stringify({"cell": c.cell, "rows": c.cfg["walk_grid"]["rows"], "size": c.cfg["size"], "obstacles": c.obstacles, "points": c.points.keys()}))
        f.close()
    print("DUMP DONE")
    quit(0)
