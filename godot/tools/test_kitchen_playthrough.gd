extends SceneTree
const Rules = preload("res://scripts/kitchen/kitchen_rules.gd")
var ok := true
func _initialize() -> void:
    for stage in range(1,31):
        var g = Rules.new()
        g.start(stage,stage*773)
        for step in 12000:
            if not g.active: break
            for plate in g.plates.duplicate(true):
                for o in g.orders.duplicate(true):
                    if g.deliver(plate.id,o.id): break
            var wanted: Array = []
            for o in g.orders:
                for d in o.dishes:
                    if not d.done: wanted.append(d.recipe)
            for p in g.pots:
                if p.recipe in wanted: wanted.erase(p.recipe)
            for plate in g.plates:
                if plate.recipe in wanted: wanted.erase(plate.recipe)
            for i in g.pots.size():
                var p: Dictionary = g.pots[i]
                if p.state == "ready": g.serve_pot(i)
                elif p.state == "empty" and not wanted.is_empty():
                    var id: String = wanted.pop_front()
                    g.choose(i,id)
                    for ingredient in Rules.recipe(id).ingredients: g.add_ingredient(i,ingredient)
                    g.heat(i,Rules.recipe(id).heat)
            g.tick(0.1)
        var pass_stage: bool = g.won and g.completed >= g.target and g.orders.is_empty()
        print("PASS " if pass_stage else "FAIL ","关卡 ",stage," 交菜 ",g.completed," 离场 ",g.missed)
        ok = ok and pass_stage
    var abandoned = Rules.new()
    abandoned.start(1,12)
    for i in 400: abandoned.tick(1)
    var failed: bool = not abandoned.active and not abandoned.won and abandoned.missed == 3
    print("PASS " if failed else "FAIL ","三位超时后失败")
    ok = ok and failed
    print("RESULT ","PASS" if ok else "FAIL")
    quit(0 if ok else 1)
