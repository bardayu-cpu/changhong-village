extends RefCounted
## 厨房规则：时间只由 tick 推进，UI 不直接改变锅、订单和金币。
signal delivered(coins: int)
signal changed

const RECIPES := [
    {"id":"beef", "name":"跷脚牛肉", "ingredients":["汤底","牛肉","葱花"], "heat":2, "seconds":8.0, "window":6.0, "coins":3, "unlock":1, "region":"苏七家乡菜"},
    {"id":"tofu", "name":"西坝豆腐", "ingredients":["汤底","豆腐","葱花"], "heat":1, "seconds":11.0, "window":7.0, "coins":4, "unlock":3, "region":"苏七家乡菜"},
    {"id":"noodles", "name":"肥肠粉", "ingredients":["汤底","粉条","肥肠"], "heat":2, "seconds":10.0, "window":6.0, "coins":4, "unlock":5, "region":"苏七家乡菜"},
    {"id":"mapo", "name":"麻婆豆腐", "ingredients":["红油","豆腐","肉末"], "heat":3, "seconds":9.0, "window":5.0, "coins":5, "unlock":7, "region":"川菜"},
    {"id":"shrimp", "name":"白灼虾", "ingredients":["清水","鲜虾","姜片"], "heat":3, "seconds":7.0, "window":4.0, "coins":6, "unlock":10, "region":"粤菜"},
    {"id":"pork", "name":"红烧肉", "ingredients":["酱汁","五花肉","冰糖"], "heat":1, "seconds":14.0, "window":6.0, "coins":7, "unlock":13, "region":"上海菜"}
]
const TITLES := ["见习厨师", "厨房学徒", "熟练厨师", "掌勺师傅", "名厨", "烹饪大师", "大宗师"]
var rng := RandomNumberGenerator.new()
var level := 1
var pots: Array = []
var orders: Array = []
var plates: Array = []
var next_id := 0
var completed := 0
var missed := 0
var earned := 0
var target := 4
var active := false
var won := false
var paused := false
var spawn_in := 0.0
var message := ""

static func recipe(id: String) -> Dictionary:
    for r in RECIPES:
        if r.id == id:
            return r
    return {}

static func title_for(stage: int) -> String:
    return TITLES[mini((maxi(stage, 1) - 1) / 3, TITLES.size() - 1)]

func available() -> Array:
    return RECIPES.filter(func(r): return int(r.unlock) <= level)

func start(stage: int, seed_value: int = 0) -> void:
    level = maxi(stage, 1)
    rng.seed = seed_value if seed_value != 0 else Time.get_ticks_usec()
    pots.clear()
    orders.clear()
    plates.clear()
    completed = 0
    missed = 0
    earned = 0
    next_id = 0
    target = 4 + mini(level, 8)
    active = true
    won = false
    paused = false
    spawn_in = 5.0
    for i in mini(1 + level / 2, 3):
        pots.append(empty_pot())
    add_order()
    message = "先选菜谱，再点食材加进锅里"
    changed.emit()

func empty_pot() -> Dictionary:
    return {"recipe":"", "ingredients":[], "heat":2, "cook":0.0, "late":0.0, "state":"empty", "wrong":false}

func add_order() -> void:
    if completed >= target or orders.size() >= mini(1 + level / 2, 3):
        return
    var dishes: Array = []
    var pool := available()
    var count := 1 if level < 4 else rng.randi_range(1, 2 if level < 8 else 3)
    for i in count:
        dishes.append({"recipe":pool[rng.randi_range(0, pool.size()-1)].id, "done":false})
    next_id += 1
    var patience := 48.0 + count * 16.0
    orders.append({"id":next_id, "female":rng.randf() > 0.5, "dishes":dishes, "left":patience, "total":patience,"age":0.0})

func choose(index: int, id: String) -> bool:
    if not can_act() or index < 0 or index >= pots.size(): return false
    var r := recipe(id)
    if r.is_empty() or int(r.unlock) > level or pots[index].state != "empty": return false
    pots[index].recipe = id
    pots[index].state = "prep"
    message = "按菜谱顺序加入食材：" + " → ".join(r.ingredients)
    changed.emit()
    return true

func add_ingredient(index: int, ingredient: String) -> bool:
    if not can_act() or index < 0 or index >= pots.size(): return false
    var p: Dictionary = pots[index]
    if p.state != "prep": return false
    var r := recipe(p.recipe)
    var step: int = p.ingredients.size()
    if step >= r.ingredients.size(): return false
    if ingredient != str(r.ingredients[step]):
        p.wrong = true
        p.state = "invalid"
        message = "加错食材了，清锅后重新做"
    else:
        p.ingredients.append(ingredient)
        if p.ingredients.size() == r.ingredients.size():
            p.state = "cooking"
            message = "开始煮了，调好火，熟了及时盛出"
        else:
            message = "下一步加入：" + str(r.ingredients[p.ingredients.size()])
    changed.emit()
    return true

func heat(index: int, value: int) -> void:
    if not can_act() or index < 0 or index >= pots.size(): return
    pots[index].heat = clampi(value, 1, 3)
    changed.emit()

func tick(dt: float) -> void:
    if not can_act() or dt <= 0: return
    for p in pots:
        if p.state not in ["cooking","ready"]: continue
        var r := recipe(p.recipe)
        var speed := 1.0 if int(p.heat) == int(r.heat) else (0.55 if int(p.heat) < int(r.heat) else 1.5)
        var advance := dt * speed
        if p.state == "cooking":
            var needed: float = maxf(0.0, float(r.seconds) - float(p.cook))
            p.cook = minf(float(r.seconds), float(p.cook) + advance)
            if advance >= needed:
                p.state = "ready"
                p.late = advance - needed
        elif p.state == "ready":
            p.late += advance
        if p.state == "ready" and float(p.late) >= float(r.window):
            p.state = "burnt"
            message = "有一锅糊了，需要清锅重做"
    for i in range(orders.size() - 1, -1, -1):
        orders[i]["age"] = float(orders[i].get("age",0.0)) + dt
        orders[i].left -= dt
        if orders[i].left <= 0:
            orders.remove_at(i)
            missed += 1
            message = "服务员等太久，生气离开了"
    if missed >= 3:
        active = false
        message = "三位服务员没有等到菜，再试一次吧"
        changed.emit()
        return
    if completed >= target and orders.is_empty():
        active = false
        won = true
        message = "本关完成！厨艺更上一层"
        changed.emit()
        return
    spawn_in -= dt
    if spawn_in <= 0:
        add_order()
        spawn_in = maxf(4.0, 8.0 - level * 0.2)
    changed.emit()

func serve_pot(index: int) -> bool:
    if not can_act() or index < 0 or index >= pots.size(): return false
    var p: Dictionary = pots[index]
    if p.state in ["empty", "invalid", "burnt"]:
        message = "这锅不能交餐，先清锅重新做"
        return false
    if p.state != "ready":
        pots[index] = empty_pot()
        message = "提前盛出了，菜还没熟！这一份需要重做"
        changed.emit()
        return false
    if plates.size() >= 6:
        message = "盛菜台满了，先把做好的菜交出去"
        return false
    next_id += 1
    plates.append({"id":next_id, "recipe":p.recipe})
    pots[index] = empty_pot()
    message = "出锅了！点成菜，再点需要它的服务员"
    changed.emit()
    return true

func clear_pot(index: int) -> void:
    if not can_act() or index < 0 or index >= pots.size(): return
    pots[index] = empty_pot()
    message = "锅已清理，可以重新做菜"
    changed.emit()

func deliver(plate_id: int, order_id: int) -> bool:
    if not can_act(): return false
    var pi := -1
    var oi := -1
    for i in plates.size():
        if int(plates[i].id) == plate_id: pi = i
    for i in orders.size():
        if int(orders[i].id) == order_id: oi = i
    if pi < 0 or oi < 0: return false
    var order: Dictionary = orders[oi]
    var slot := -1
    for i in order.dishes.size():
        if not order.dishes[i].done and order.dishes[i].recipe == plates[pi].recipe:
            slot = i
            break
    if slot < 0:
        message = "这位服务员不需要这道菜"
        return false
    var reward := int(recipe(plates[pi].recipe).coins)
    order.dishes[slot].done = true
    plates.remove_at(pi)
    completed += 1
    earned += reward
    # 先消费成菜并登记订单，再发奖励信号，防止重复点按重复发币。
    delivered.emit(reward)
    message = "交菜成功，获得 %d 金币" % reward
    if order.dishes.all(func(d): return d.done): orders.remove_at(oi)
    if completed >= target and orders.is_empty():
        active = false
        won = true
        message = "本关完成！厨艺更上一层"
    changed.emit()
    return true

func can_act() -> bool:
    return active and not paused
