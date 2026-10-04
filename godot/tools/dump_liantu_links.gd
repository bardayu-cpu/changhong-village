extends SceneTree
## 倒出每块画布的口子表（口在哪、靠哪条边、到了对面站哪、靠哪条边）。03 看第 65 版用，只列不判：Godot --headless --path godot --script res://tools/dump_liantu_links.gd
const Main = preload("res://scripts/main.gd")
var m
var started := false

func _initialize() -> void:
    m = Main.new()
    m.fast = true
    get_root().add_child(m)
    create_timer(120.0).timeout.connect(func():
        print("RESULT FAIL 120 秒没跑完")
        quit(1))

func _process(_dt: float) -> bool:
    if started:
        return false
    started = true
    run()
    return false

func canvas_of(k: String):
    if k == "court":
        return m.court
    if k == "banquet":
        return m.hall
    return m._canvas_by(k)

func side_of(p: Vector2, sz: Vector2) -> String:
    var d := {"W": p.x, "E": sz.x - p.x, "N": p.y, "S": sz.y - p.y}
    var best := "W"
    for k in d:
        if float(d[k]) < float(d[best]):
            best = k
    return best

func run() -> void:
    get_root().size = Vector2i(540, 960)
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
    await m._enter_court()
    for k in keys:
        var c = canvas_of(k)
        var sz := Vector2(float(c.cfg["size"][0]), float(c.cfg["size"][1]))
        print("== %s 画布 %s 出生 %s" % [k, str(sz), str(c.SPAWN)])
        for pid in c.points:
            var pt: Dictionary = c.points[pid]
            var to := str(pt["to"])
            if to == "":
                print("   %s (%.0f,%.0f) r%.0f 说话 %s 靠 %s" % [pid, pt["pos"].x, pt["pos"].y, pt["r"], pt["say"], side_of(pt["pos"], sz)])
                continue
            var land := Vector2.ZERO
            var tsz := Vector2.ZERO
            if to != "banquet":
                var t = canvas_of(to)
                tsz = Vector2(float(t.cfg["size"][0]), float(t.cfg["size"][1]))
                if str(pt["via"]) != "":
                    land = t.arrival_at(str(pt["via"]))
                else:
                    land = t.arrival_from(k)
            print("   %s (%.0f,%.0f) r%.0f 靠 %s → %s via=%s 落 (%.0f,%.0f) 靠 %s" % [pid, pt["pos"].x, pt["pos"].y, pt["r"], side_of(pt["pos"], sz), to, str(pt["via"]), land.x, land.y, side_of(land, tsz) if tsz != Vector2.ZERO else "?"])
    var h = m.hall
    print("== banquet 门 door %s r%.0f；side_door %s r%.0f arrive %s；exits %s" % [str(h.door), h.door_r, str(h.side_door), h.side_door_r, str(h.side_arrive), str(h.exits)])
    print("   hall cfg 键 ", h.cfg.keys())
    print("   hall SPAWN ", h.SPAWN)
    print("RESULT PASS")
    quit(0)
