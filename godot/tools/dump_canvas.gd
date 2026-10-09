extends SceneTree
## 把六块画布的「能走的格子」和交互点导成 json，给出对照图用（01 9/20 派的六张俯视对照图）。
## 导的是游戏真在用的那套走路格子（各块画布自己算的），不是照着布局文件重算，免得图和游戏对不上。
## 用法：Godot --headless --path . --script res://tools/dump_canvas.gd -- 输出目录

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
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await process_frame
    var out_dir := "."
    for a in OS.get_cmdline_user_args():
        out_dir = a
    var canvases := {"court": m.court, "banquet": m.hall, "backhall": m.backhall, "lawn": m.lawn, "lake": m.lake, "orchard": m.orchard}
    for name in canvases:
        var cv = canvases[name]
        var size: Array = [int(cv.cfg["size"][0]), int(cv.cfg["size"][1])]
        # 宴会厅（layered_hall）没有交互点这套，是桌椅，取不到就空着
        var pts := []
        var pmap = cv.get("points")
        if pmap is Dictionary:
            for id in pmap:
                pts.append({"id": id, "x": pmap[id]["pos"].x, "y": pmap[id]["pos"].y, "r": pmap[id]["r"]})
        # 能走的格子：直接导游戏自己算好的那份（cfg 里的 walk_grid，一行一个字符串，1 是能走）
        var g: Dictionary = cv.cfg["walk_grid"]
        var d := {"name": name, "size": size, "cell": float(g["cell"]), "cols": int(g["cols"]), "rows": g["rows"],
            "points": pts}
        var sp = cv.get("SPAWN")
        if sp is Vector2:
            d["spawn"] = [sp.x, sp.y]
        var f := FileAccess.open(out_dir + "/" + name + ".json", FileAccess.WRITE)
        f.store_string(JSON.stringify(d))
        f.close()
        print("[dump] ", name, " ", size, " 格 ", g["cell"], " 交互点 ", pts.size())
    quit(0)
