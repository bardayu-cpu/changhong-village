extends SceneTree
## 宴会厅能走的格子：# 挡住，. 从门口走得到，o 空着但走不到
var hall
var started := false
func _initialize() -> void:
    hall = load("res://scripts/hall.gd").new()
    get_root().add_child(hall)
func _process(_dt: float) -> bool:
    if started:
        return false
    started = true
    hall.build(2, "", SystemFont.new())
    var sz: Vector2i = hall.nav.region.size
    var seen := {}
    var q := [hall._cell_of(hall.SPAWN)]
    seen[q[0]] = true
    while not q.is_empty():
        var c: Vector2i = q.pop_back()
        for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
            var n: Vector2i = c + d
            if hall.nav.is_in_boundsv(n) and not hall.nav.is_point_solid(n) and not seen.has(n):
                seen[n] = true
                q.append(n)
    var free := 0
    var unreach := 0
    for j in sz.y:
        var line := ""
        for i in sz.x:
            var c := Vector2i(i, j)
            if hall.nav.is_point_solid(c):
                line += "#"
            elif seen.has(c):
                line += "."
                free += 1
            else:
                line += "o"
                unreach += 1
        print("%6.1f %s" % [hall.Z0 + (j + 0.5) * hall.CELL, line])
    print("走得到 ", free, " 格，空着走不到 ", unreach, " 格")
    var all_reachable := free > 0 and unreach == 0
    print("RESULT PASS" if all_reachable else "RESULT FAIL")
    quit(0 if all_reachable else 1)
    return true
