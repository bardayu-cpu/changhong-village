extends SceneTree
const Rules = preload("res://scripts/kitchen/kitchen_rules.gd")
var ok := true
func _initialize() -> void:
    for stage in range(1,31):
        var g = Rules.new()
        g.start(stage,stage*773)
        for step in 12000:
            if not g.active: break
            g.deliver_auto()
            for i in g.pots.size():
                if g.pots[i].state == "ready": g.serve_pot(i)
            var assigned: Array = []
            for pot in g.pots:
                if pot.order_id >= 0: assigned.append("%d:%d" % [pot.order_id,pot.dish_index])
            for plate in g.plates: assigned.append("%d:%d" % [plate.order_id,plate.dish_index])
            for order in g.orders:
                for dish_index in order.dishes.size():
                    var key := "%d:%d" % [order.id,dish_index]
                    if order.dishes[dish_index].done or key in assigned: continue
                    for i in g.pots.size():
                        if g.pots[i].state != "empty": continue
                        g.choose_order_dish(i,order.id,dish_index)
                        for item in g.pots[i].required: g.add_ingredient(i,item)
                        assigned.append(key)
                        break
            g.tick(0.1)
        var passed: bool = g.won and g.completed >= g.target and g.orders.is_empty()
        print("PASS " if passed else "FAIL ","关卡 ",stage," 交菜 ",g.completed," 离场 ",g.missed)
        ok = ok and passed
    var abandoned = Rules.new()
    abandoned.start(1,12)
    for i in 400: abandoned.tick(1)
    var failed: bool = not abandoned.active and not abandoned.won and abandoned.missed == 3
    print("PASS " if failed else "FAIL ","三位超时后失败")
    ok = ok and failed
    print("RESULT ","PASS" if ok else "FAIL")
    quit(0 if ok else 1)
