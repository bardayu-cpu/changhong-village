extends RefCounted
## 厨房规则：时间只由 tick 推进，UI 不直接改变锅、订单和金币。
signal delivered(coins: int)
signal changed
signal order_departed(order: Dictionary, completed_order: bool)

const Catalog = preload("res://scripts/kitchen/kitchen_catalog.gd")
const DEPARTURE_SECONDS := 0.9
const CONFIG_PATH := "res://data/kitchen/gameplay.json"
static var RECIPES: Array = _default_config().get("recipes",[])
var recipe_catalog: Array = RECIPES.duplicate(true)
var character_catalog: Array = _default_config().get("characters",[])

static func _default_config() -> Dictionary:
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
    return Catalog.resolve_setup(parsed) if parsed is Dictionary else {}

func configure(config: Dictionary) -> bool:
    # Validate before replacing live configuration; assets do not control recipe unlocks.
    if active: return false
    var rows: Array = config.get("recipes",[])
    var people: Array = config.get("characters",[])
    var ids: Array = []
    if rows.is_empty() or people.is_empty(): return false
    for row in rows:
        if not row is Dictionary: return false
        if not row.has("id") or not row.has("name"): return false
        if str(row.id).is_empty() or row.id in ids: return false
        if not bool(row.get("enabled",true)):
            ids.append(row.id)
            continue
        for key in ["ingredients","seconds","window","coins","unlock"]:
            if not row.has(key): return false
        if str(row.id).is_empty() or row.id in ids or not row.ingredients is Array or row.ingredients.is_empty(): return false
        if float(row.seconds) <= 0 or float(row.window) <= 0 or int(row.coins) < 0 or int(row.unlock) < 1: return false
        for variant in row.get("variants",[row.ingredients]):
            if not variant is Array or variant.is_empty(): return false
        ids.append(row.id)
    var person_ids: Array = []
    for person in people:
        if not person is Dictionary or str(person.get("id","")).is_empty() or person.id in person_ids: return false
        person_ids.append(person.id)
    recipe_catalog = rows.duplicate(true)
    character_catalog = people.duplicate(true)
    return true

func recipe_data(id: String) -> Dictionary:
    for row in recipe_catalog:
        if str(row.id) == id: return row
    return {}

const TITLES := ["见习厨师", "厨房学徒", "熟练厨师", "掌勺师傅", "名厨", "烹饪大师", "大宗师"]
var rng := RandomNumberGenerator.new()
var level := 1
var pots: Array = []
var orders: Array = []
# An identity belongs to one person. Retain it until their visible departure finishes.
var departing_identities: Dictionary = {}
var plates: Array = []
var next_id := 0
var completed := 0
var missed := 0
var earned := 0
var served_counts: Dictionary = {}
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
    return recipe_catalog.filter(func(r): return bool(r.get("enabled",true)) and int(r.unlock) <= level)

func start(stage: int, seed_value: int = 0) -> void:
    level = maxi(stage, 1)
    rng.seed = seed_value if seed_value != 0 else Time.get_ticks_usec()
    pots.clear()
    orders.clear()
    departing_identities.clear()
    plates.clear()
    completed = 0
    missed = 0
    earned = 0
    served_counts.clear()
    next_id = 0
    target = 4 + mini(level, 8)
    active = true
    won = false
    paused = false
    spawn_in = 5.0
    for i in mini(1 + level / 2, 3):
        pots.append(empty_pot())
    if available().is_empty():
        active = false
        message = "本等级的菜谱配置尚未就绪"
    else:
        add_order()
        message = "先选菜谱，再点食材加进锅里"
    changed.emit()

func empty_pot() -> Dictionary:
    return {"recipe":"", "ingredients":[], "required":[], "order_id":-1, "dish_index":-1, "heat":2, "cook":0.0, "late":0.0, "state":"empty", "wrong":false}

func _variant_for(recipe_id: String) -> Array:
    var row := recipe_data(recipe_id)
    var variants: Array = row.get("variants",[row.ingredients])
    return variants[rng.randi_range(0,variants.size()-1)].duplicate()

func add_order() -> void:
    if completed >= target or orders.size() >= mini(1 + level / 2, 3):
        return
    var occupied: Array = orders.map(func(o): return str(o.get("character","")))
    var people: Array = character_catalog.filter(func(person): return not str(person.id) in occupied and not departing_identities.has(str(person.id)))
    if people.is_empty(): return
    var dishes: Array = []
    var pool := available()
    if pool.is_empty(): return
    # Start with one dish in the apprentice's single station. As more stations
    # unlock, a waiter may ask for two and then three dishes in the same order.
    var count := rng.randi_range(1,mini(1 + level / 2,3))
    for i in count:
        var recipe_id: String = pool[rng.randi_range(0, pool.size()-1)].id
        dishes.append({"recipe":recipe_id, "ingredients":_variant_for(recipe_id), "done":false})
    next_id += 1
    var patience := 48.0 + count * 16.0
    var slot := 0
    var used_slots: Array = orders.map(func(o): return int(o.get("slot",0)))
    while slot in used_slots: slot += 1
    var identity: Dictionary = people[rng.randi_range(0,people.size()-1)]
    orders.append({"slot":slot,"id":next_id, "character":str(identity.id), "female":str(identity.get("gender","")) == "female", "dishes":dishes, "left":patience, "total":patience,"age":0.0,"leaving":0.0})

func choose(index: int, id: String) -> bool:
    if not can_act() or index < 0 or index >= pots.size(): return false
    var r := recipe_data(id)
    if r.is_empty() or int(r.unlock) > level or pots[index].state != "empty": return false
    pots[index].recipe = id
    pots[index].required = r.ingredients.duplicate()
    pots[index].state = "prep"
    message = "按菜谱顺序加入食材：" + " → ".join(r.ingredients)
    changed.emit()
    return true

func choose_order_dish(index: int, order_id: int, dish_index: int) -> bool:
    if not can_act() or index < 0 or index >= pots.size() or pots[index].state != "empty": return false
    for order in orders:
        if int(order.id) != order_id or dish_index < 0 or dish_index >= order.dishes.size(): continue
        var dish: Dictionary = order.dishes[dish_index]
        if dish.done: return false
        order.confirm_left = 0.7
        pots[index].recipe = str(dish.recipe)
        pots[index].required = dish.get("ingredients",recipe_data(str(dish.recipe)).ingredients).duplicate()
        pots[index].order_id = order_id
        pots[index].dish_index = dish_index
        pots[index].state = "prep"
        message = "照订单加入：" + " → ".join(pots[index].required)
        changed.emit()
        return true
    return false

func add_ingredient(index: int, ingredient: String) -> bool:
    if not can_act() or index < 0 or index >= pots.size(): return false
    var p: Dictionary = pots[index]
    if p.state != "prep": return false
    var required: Array = p.required if not p.required.is_empty() else recipe_data(p.recipe).ingredients
    var step: int = p.ingredients.size()
    if step >= required.size(): return false
    if ingredient != str(required[step]):
        p.wrong = true
        p.state = "invalid"
        message = "加错食材了，清锅后重新做"
    else:
        p.ingredients.append(ingredient)
        if p.ingredients.size() == required.size():
            p.state = "cooking"
            message = "正在烧，熟了点锅盛出"
        else:
            message = "下一步加入：" + str(required[p.ingredients.size()])
    changed.emit()
    return true

func heat(index: int, value: int) -> void:
    # v2 玩法固定火力；保留接口供旧存档和旧测试调用。
    if not can_act() or index < 0 or index >= pots.size(): return
    pots[index].heat = 2

func tick(dt: float) -> void:
    if not can_act() or dt <= 0: return
    for identity in departing_identities.keys():
        departing_identities[identity] = float(departing_identities[identity])-dt
        if float(departing_identities[identity]) <= 0.0: departing_identities.erase(identity)
    for p in pots:
        if p.state not in ["cooking","ready"]: continue
        var r := recipe_data(p.recipe)
        var advance := dt
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
            message = str(r.get("overcook_text","有一锅糊了，需要清锅重做"))
    for i in range(orders.size() - 1, -1, -1):
        orders[i]["age"] = float(orders[i].get("age",0.0)) + dt
        orders[i]["confirm_left"] = maxf(0,float(orders[i].get("confirm_left",0.0))-dt)
        orders[i].left -= dt
        if orders[i].left <= 0:
            var departed: Dictionary = orders[i].duplicate(true)
            orders.remove_at(i)
            departing_identities[str(departed.get("character",""))] = DEPARTURE_SECONDS
            order_departed.emit(departed,false)
            missed += 1
            message = "服务员等太久，生气离开了"
    if missed >= 3:
        active = false
        message = "有 %d 位服务员没等到菜，再试一次吧" % missed
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
    plates.append({"id":next_id, "recipe":p.recipe, "ingredients":p.required.duplicate(), "order_id":p.order_id, "dish_index":p.dish_index})
    pots[index] = empty_pot()
    message = "装好盘了，点交菜"
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
        if not order.dishes[i].done and order.dishes[i].recipe == plates[pi].recipe and _same_ingredients(order.dishes[i],plates[pi]):
            slot = i
            break
    if slot < 0:
        message = "这位服务员不需要这道菜"
        return false
    var served_recipe: String = plates[pi].recipe
    var reward := int(recipe_data(served_recipe).coins)
    order.dishes[slot].done = true
    order.last_dish = served_recipe
    plates.remove_at(pi)
    completed += 1
    earned += reward
    served_counts[served_recipe] = int(served_counts.get(served_recipe,0)) + 1
    # 先消费成菜并登记订单，再发奖励信号，防止重复点按重复发币。
    delivered.emit(reward)
    message = "交菜成功，获得 %d 金币" % reward
    if order.dishes.all(func(d): return d.done):
        var departed: Dictionary = order.duplicate(true)
        orders.remove_at(oi)
        departing_identities[str(departed.get("character",""))] = DEPARTURE_SECONDS
        order_departed.emit(departed,true)
    if completed >= target and orders.is_empty():
        active = false
        won = true
        message = "本关完成！厨艺更上一层"
    changed.emit()
    return true

func _same_ingredients(dish: Dictionary, plate: Dictionary) -> bool:
    var wanted: Array = dish.get("ingredients",recipe_data(str(dish.recipe)).ingredients)
    var cooked: Array = plate.get("ingredients",recipe_data(str(plate.recipe)).ingredients)
    # Ingredients represent the same serving even if the garnish order differs.
    return wanted.size() == cooked.size() and wanted.all(func(item): return item in cooked)

func deliver_auto(plate_id: int = -1) -> bool:
    if not can_act() or plates.is_empty(): return false
    var candidates: Array = plates.duplicate(true)
    if plate_id >= 0:
        candidates = candidates.filter(func(p): return int(p.id) == plate_id)
        if candidates.is_empty(): return false
    var sent := false
    for plate in candidates:
        var matches: Array = orders.filter(func(o): return o.dishes.any(func(d): return not d.done and d.recipe == plate.recipe and _same_ingredients(d,plate)))
        if matches.is_empty(): continue
        # Prefer the original order only after checking its exact recipe and ingredients.
        matches.sort_custom(func(a,b):
            if int(a.id) == int(plate.get("order_id",-1)): return true
            if int(b.id) == int(plate.get("order_id",-1)): return false
            return float(a.left) < float(b.left))
        if deliver(int(plate.id),int(matches[0].id)): sent = true
    if not sent:
        message = "暂时没有配料完全相同的订单"
        changed.emit()
    return sent

func can_act() -> bool:
    return active and not paused
