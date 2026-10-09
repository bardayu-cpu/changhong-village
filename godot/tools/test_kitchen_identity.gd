extends SceneTree
const Rules = preload("res://scripts/kitchen/kitchen_rules.gd")
var ok := true
func check(label: String, value: bool) -> void:
    print(("PASS " if value else "FAIL ")+label)
    ok = ok and value
func unique(ids: Array) -> bool:
    var seen := {}
    for id in ids:
        if seen.has(id): return false
        seen[id] = true
    return true
func finish_order(g, id: int) -> void:
    var matches: Array = g.orders.filter(func(o): return o.id == id)
    if matches.is_empty(): return
    var order: Dictionary = matches[0]
    for index in order.dishes.size():
        var dish: Dictionary = order.dishes[index]
        g.next_id += 1
        var plate := {"id":g.next_id,"recipe":dish.recipe,"ingredients":dish.ingredients.duplicate(),"order_id":id,"dish_index":index}
        g.plates.append(plate)
        g.deliver(plate.id,id)
func _initialize() -> void:
    var random_unique := true
    var transition_unique := true
    for seed_value in 100:
        var g = Rules.new()
        g.start(30,seed_value+1)
        g.target = 1000
        g.spawn_in = 9999.0
        for cycle in 20:
            while g.orders.size() < 3:
                var before: int = g.orders.size()
                g.add_order()
                if g.orders.size() == before: break
            random_unique = random_unique and unique(g.orders.map(func(o): return o.character))
            transition_unique = transition_unique and g.orders.all(func(o): return not g.departing_identities.has(str(o.character)))
            if not g.orders.is_empty(): finish_order(g,g.orders[0].id)
            g.add_order()
            transition_unique = transition_unique and unique(g.orders.map(func(o): return o.character)) and g.orders.all(func(o): return not g.departing_identities.has(str(o.character)))
            g.tick(0.31)
    check("100种随机开局及2000次轮换，队列内没有重复人物",random_unique)
    check("端菜与离场期间不会生成同一个人",transition_unique)
    var single = Rules.new()
    single.character_catalog = [single.character_catalog[0]]
    single.start(30,77)
    single.target = 100
    single.spawn_in = 9999.0
    var id: String = single.orders[0].character
    finish_order(single,single.orders[0].id)
    single.add_order()
    check("仅一个人时，端菜尚未离场不重新出现",single.orders.is_empty() and single.departing_identities.has(id))
    single.tick(0.4)
    single.paused = true
    var left: float = single.departing_identities[id]
    single.tick(2.0)
    single.add_order()
    check("暂停保留离场人物身份占用",single.departing_identities[id] == left and single.orders.is_empty())
    single.paused = false
    single.tick(0.51)
    single.add_order()
    check("完全离场之后，同一个人才可再接单",single.orders.size() == 1 and single.orders[0].character == id and single.departing_identities.is_empty())
    single.orders[0].left = 0.01
    single.tick(0.02)
    single.add_order()
    check("生气离场期间也不重新出现",single.orders.is_empty() and single.departing_identities.has(id))
    single.start(30,99)
    check("重开一局清理旧的离场身份占用",single.orders.size() == 1 and single.departing_identities.is_empty())
    var all_reserved = Rules.new()
    all_reserved.start(30,73)
    all_reserved.orders.clear()
    for person in all_reserved.character_catalog: all_reserved.departing_identities[str(person.id)] = Rules.DEPARTURE_SECONDS
    all_reserved.add_order()
    check("六人都占用时等待，不生成分身也不空池崩溃",all_reserved.orders.is_empty())
    print("RESULT ","PASS" if ok else "FAIL")
    quit(0 if ok else 1)
