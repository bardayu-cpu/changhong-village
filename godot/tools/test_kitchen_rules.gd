extends SceneTree
const Rules = preload("res://scripts/kitchen/kitchen_rules.gd")
var ok := true
var coins := 0
func check(label: String, condition: bool) -> void:
    print(("PASS " if condition else "FAIL ") + label)
    ok = ok and condition
func cook(g, index: int, id := "beef") -> void:
    g.choose(index, id)
    for ingredient in Rules.recipe(id).ingredients: g.add_ingredient(index, ingredient)
    g.heat(index, int(Rules.recipe(id).heat))
func _initialize() -> void:
    var g = Rules.new()
    g.delivered.connect(func(n): coins += n)
    g.start(1, 42)
    check("首关一锅一菜", g.pots.size() == 1 and g.orders[0].dishes.size() == 1)
    cook(g, 0)
    g.tick(7)
    check("提前出锅失败", not g.serve_pot(0) and g.plates.is_empty() and coins == 0)
    cook(g, 0)
    g.tick(8)
    check("到时熟了仍可盛出", g.pots[0].state == "ready" and g.serve_pot(0))
    var pid: int = g.plates[0].id
    var oid: int = g.orders[0].id
    check("有效交菜立即发金币", g.deliver(pid, oid) and coins == 3)
    check("重复点击不重复发币", not g.deliver(pid, oid) and coins == 3)
    cook(g, 0)
    g.tick(15)
    check("超时糊锅不能交菜", g.pots[0].state == "burnt" and not g.serve_pot(0))
    g.clear_pot(0)
    g.choose(0, "beef")
    g.add_ingredient(0, "豆腐")
    check("错料拒绝出餐", g.pots[0].state == "invalid" and not g.serve_pot(0))
    g.start(8, 42)
    check("高级三锅", g.pots.size() == 3)
    g.orders = [{"id":101,"female":true,"dishes":[{"recipe":"beef","done":false},{"recipe":"tofu","done":false},{"recipe":"beef","done":false}],"left":50.0,"total":50.0},{"id":102,"female":false,"dishes":[{"recipe":"beef","done":false}],"left":50.0,"total":50.0}]
    g.spawn_in = 1000.0
    cook(g,0)
    cook(g,1)
    g.tick(8)
    g.serve_pot(0)
    g.serve_pot(1)
    check("可先交后排服务员", g.deliver(g.plates[0].id,102) and g.orders.size() == 1)
    check("部分交菜保留订单", g.deliver(g.plates[0].id,101) and g.orders.size() == 1 and g.orders[0].dishes[0].done)
    var earned_before := coins
    g.orders[0].left = 0.1
    g.tick(0.2)
    check("等待超时离场且不追回金币", g.missed == 1 and not g.deliver(999,101) and coins == earned_before)
    g.start(8,99)
    cook(g,0)
    var before: float = g.pots[0].cook
    g.paused = true
    var wait_before: float = g.orders[0].left
    g.tick(100)
    check("暂停同时冻结锅与订单", g.pots[0].cook == before and g.orders[0].left == wait_before)
    check("暂停拒绝操作", not g.serve_pot(0) and not g.choose(1,"beef"))
    g.paused = false
    for i in 100:
        g.orders.clear()
        g.add_order()
        check("单人订单不超过三道 %d" % i, g.orders[0].dishes.size() <= 3)
    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
