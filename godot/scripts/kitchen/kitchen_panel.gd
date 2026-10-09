extends Control
## 手机竖屏可玩原型。玩法和 UI 分开，后续美术替换不会改变计时规则。
signal closed
const Art = preload("res://scripts/kitchen/kitchen_art.gd")
const Rules = preload("res://scripts/kitchen/kitchen_rules.gd")
const UsedRects = preload("res://scripts/used_rects.gd")
var rules = Rules.new()
var wallet
var game_font: Font
var unlocked := 1
var selected_pot := 0
var selected_plate := -1
var panel: Control
var status: Label
var timers: Array = []
var order_labels: Array = []
var patience_bars: Array = []
var saved_path := "user://suqi_kitchen.json"
var round_saved := false
var learned_this_round: Array[String] = []
var visibility_bridge
var visibility_epoch := -1
var figures: Array = []
var departures: Array = []
var playfield: Control
var coin_label: Label
var menu_texture_cache: Dictionary = {}
const UISkin = preload("res://scripts/games/ui_skin.gd")
# 第 1 关（教学那关）的引导（04 10/2：刚进来没一句话、先点原料没反应；03：规则里那两句被滤掉了）：
# 锅和原料之间一行大字，照现在该做的那一步说；做对一步就换下一句；点错了先说为什么（2 秒）再回到这一步。第 2 关起不出
var guide: Label
var guide_flash := ""
var guide_flash_t := 0.0
const GUIDE_FS := 42   # 参考坐标里的字号，乘 540/941 ≈ 24 像素

func open(save, f: Font) -> void:
    wallet = save
    game_font = f
    theme = Theme.new()
    theme.default_font = f
    theme.default_font_size = 24
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    z_index = 20
    if FileAccess.file_exists(saved_path):
        var d = JSON.parse_string(FileAccess.get_file_as_string(saved_path))
        if d is Dictionary: unlocked = clampi(int(d.get("unlocked",1)),1,30)
    rules.delivered.connect(func(n): wallet.earn(n))
    rules.order_departed.connect(_on_order_departed)
    resized.connect(_layout)
    _menu()

func _base(title: String) -> void:
    status = null
    for c in get_children(): c.queue_free()
    var veil := ColorRect.new()
    veil.color = Color("241e22")
    add_child(veil)
    veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    panel = Control.new()
    add_child(panel)
    panel.size = Vector2(540,960)
    _layout()
    var bg = ColorRect.new()
    bg.color = Color("241e22")
    bg.size = Vector2(540,960)
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(bg)
    var backdrop := TextureRect.new()
    backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    backdrop.texture = preload("res://scripts/canvas_assets.gd").texture("res://assets/kitchen/mobile/background/base_kitchen_no_fire.png")
    backdrop.size = Vector2(540,960)
    backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(backdrop)
    if title != "":
        var shade := ColorRect.new()
        shade.color = Color(0.08,0.035,0.02,0.70)
        shade.position = Vector2(0,0)
        shade.size = Vector2(540,105)
        panel.add_child(shade)
        _label(title,Rect2(24,20,490,40),26,Color("ffd894"))

func _layout() -> void:
    if not is_instance_valid(panel): return
    var s := minf(size.x / 540.0, size.y / 960.0)
    panel.scale = Vector2(s,s)
    panel.position = (size - Vector2(540,960)*s)*0.5

func _label(text: String, rect: Rect2, fs := 19, color := Color("fff0d0")) -> Label:
    var l = Label.new()
    l.text = text
    l.position = rect.position
    l.size = rect.size
    l.add_theme_font_override("font",game_font)
    l.add_theme_font_size_override("font_size",fs)
    l.add_theme_color_override("font_color",color)
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    panel.add_child(l)
    return l

func _button(text: String, rect: Rect2, action: Callable, accent := false) -> Button:
    var b = Button.new()
    b.text = text
    b.position = rect.position
    b.size = rect.size
    b.add_theme_font_override("font",game_font)
    b.add_theme_font_size_override("font_size",18)
    var style = StyleBoxFlat.new()
    style.bg_color = Color("936039") if accent else Color("443538")
    style.border_color = Color("d6aa65")
    style.set_border_width_all(2)
    style.set_corner_radius_all(7)
    b.add_theme_stylebox_override("normal",style)
    b.pressed.connect(action)
    panel.add_child(b)
    return b

func _box(rect: Rect2, bg := Color("3b180fe8"), border := Color("f0a83d"), radius := 7) -> Panel:
    var p := Panel.new()
    p.position = rect.position
    p.size = rect.size
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.border_color = border
    style.set_border_width_all(2)
    style.set_corner_radius_all(radius)
    p.add_theme_stylebox_override("panel",style)
    panel.add_child(p)
    return p

func _panel_label(parent: Control, text: String, rect: Rect2, fs := 16, color := Color("fff0d0")) -> Label:
    var l := Label.new()
    l.text = text
    l.position = rect.position
    l.size = rect.size
    l.add_theme_font_override("font",game_font)
    l.add_theme_font_size_override("font_size",fs)
    l.add_theme_color_override("font_color",color)
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    parent.add_child(l)
    return l

func _menu() -> void:
    _base("灶火与手艺")
    _label("%s · 第 %d 关" % [Rules.title_for(unlocked),unlocked],Rect2(24,112,490,48),22)
    _label("按菜谱加料，熟了盛出交菜。",Rect2(24,175,485,40),18)
    Art.put_piece(panel,"hat_icon",Rect2(402,325,84,62))
    var start_button := _button("开始第 %d 关" % unlocked,Rect2(24,440,492,66),func(): _start(unlocked),true)
    start_button.set_meta("kitchen_action","start")
    var picker := OptionButton.new()
    picker.position = Vector2(24,526)
    picker.size = Vector2(314,58)
    picker.add_theme_font_override("font",game_font)
    picker.add_theme_font_size_override("font_size",20)
    for stage in range(1,unlocked+1): picker.add_item("重玩第 %d 关" % stage)
    picker.select(unlocked-1)
    panel.add_child(picker)
    _button("开始重玩",Rect2(354,526,162,58),func(): _start(picker.selected+1))
    _button("回后厅",Rect2(24,852,492,60),_close)

func _start(stage: int) -> void:
    selected_pot = 0
    selected_plate = -1
    round_saved = false
    learned_this_round.clear()
    departures.clear()
    rules.start(stage)
    _render()

func _notification(what: int) -> void:
    if bool(get_meta("capture_mode",false)): return
    if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
        _pause_for_background()

func _pause_for_background() -> void:
    if rules == null or not rules.active or rules.paused: return
    rules.paused = true
    rules.message = "已暂停，回到游戏后点继续"
    if is_instance_valid(status): call_deferred("_render")

func _poll_visibility() -> void:
    if not (OS.has_feature("web") or OS.has_feature("wechat")): return
    if visibility_bridge == null:
        visibility_bridge = JavaScriptBridge.get_interface("__suqiKitchenVisibility")
    if visibility_bridge == null: return
    var epoch := int(visibility_bridge.epoch())
    if str(visibility_bridge.hidden()) == "1" or (visibility_epoch >= 0 and epoch != visibility_epoch):
        _pause_for_background()
    visibility_epoch = epoch

func _toggle_pause() -> void:
    rules.paused = not rules.paused
    rules.message = "已暂停，锅和服务员一起等待" if rules.paused else "继续做菜，留意每一口锅的火候"
    _render()

func _process(dt: float) -> void:
    _poll_visibility()
    if guide_flash_t > 0.0:
        guide_flash_t -= dt
        if guide_flash_t <= 0.0 and is_instance_valid(guide): guide.text = guide_text()
    if not is_instance_valid(status): return
    var old_states: Array = rules.pots.map(func(p): return p.state)
    var old_ids: Array = rules.orders.map(func(o): return o.id)
    rules.tick(dt)
    if is_instance_valid(playfield) and not rules.paused: Art.update_animations(playfield,dt)
    if old_states != rules.pots.map(func(p): return p.state) or old_ids != rules.orders.map(func(o): return o.id): _render()
    _update_waiter_motion(dt)
    if not rules.active:
        if not departures.is_empty():
            if is_instance_valid(status): status.text = rules.message
            _update_live_labels()
            return
        if not round_saved:
            round_saved = true
            if rules.won:
                for r in rules.recipe_catalog:
                    if bool(r.get("enabled",true)) and int(r.unlock) > unlocked and int(r.unlock) <= rules.level + 1:
                        learned_this_round.append(str(r.name))
                unlocked = maxi(unlocked, mini(30,rules.level+1))
                var f = FileAccess.open(saved_path, FileAccess.WRITE)
                if f: f.store_string(JSON.stringify({"version":1,"unlocked":unlocked}))
            _result()
        return
    if is_instance_valid(status): status.text = rules.message
    _update_live_labels()

func _update_waiter_motion(dt: float) -> void:
    for figure in figures:
        if is_instance_valid(figure.node):
            _refresh_actor_action(figure.node,figure.order,int(figure.order.get("slot",0)))
            figure.node.position.x = maxf(0.0,0.6-float(figure.order.get("age",0.0)))*60.0
            if is_instance_valid(figure.overlay):
                figure.overlay.position = figure.node.position
                _refresh_tray(figure.overlay,figure.order,int(figure.order.get("slot",0)))
    var expired := false
    if not rules.paused:
        for departure in departures:
            departure.elapsed = float(departure.elapsed)+dt
            if is_instance_valid(departure.node):
                departure.order.action = "carrying" if bool(departure.completed) and departure.elapsed < 0.25 else "leaving"
                _refresh_actor_action(departure.node,departure.order,int(departure.slot))
                departure.node.position.x = maxf(0.0,float(departure.elapsed)-0.25)*240.0
                departure.node.modulate.a = clampf((Rules.DEPARTURE_SECONDS-float(departure.elapsed))/0.3,0,1)
                if is_instance_valid(departure.overlay):
                    departure.overlay.position = departure.node.position
                    departure.overlay.modulate = departure.node.modulate
                    _refresh_tray(departure.overlay,departure.order,int(departure.slot))
            if departure.elapsed >= Rules.DEPARTURE_SECONDS: expired = true
    if expired:
        departures = departures.filter(func(d): return d.elapsed < Rules.DEPARTURE_SECONDS)
        _render()

func _render() -> void:
    _base("")
    timers.clear()
    order_labels.clear()
    patience_bars.clear()
    figures.clear()
    playfield = Control.new()
    playfield.name = "ApprovedKitchenCanvas"
    playfield.size = Art.UI_REFERENCE_SIZE
    playfield.scale = Vector2(540.0/941.0,960.0/1672.0)
    playfield.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(playfield)

    _source_fill(Rect2(Vector2.ZERO,Art.UI_REFERENCE_SIZE),Color(0.045,0.025,0.012,0.22))
    Art.put_piece(playfield,"sign",Art.REFERENCE_REGIONS.sign)
    Art.put_piece(playfield,"rank_frame",Art.REFERENCE_REGIONS.rank_frame)
    Art.put_piece(playfield,"coin_frame",Art.REFERENCE_REGIONS.coin_frame)
    _source_fill(Rect2(305,19,250,42),Color("351909"))
    _source_fill(Rect2(615,19,266,42),Color("351909"))
    Art.put_piece(playfield,"hat_icon",Rect2(309,18,54,40))
    Art.put_piece(playfield,"coin_icon",Rect2(616,18,50,41))
    _source_label(Rules.title_for(rules.level),Rect2(383,21,178,40),32,Color("fff0c2"))
    _source_label("累计金币",Rect2(677,24,119,36),26,Color("fff0c2"))
    coin_label = _source_label(str(int(wallet.coins)),Rect2(798,21,84,40),32,Color("ffd15c"))
    var pause := _source_hit(Rect2(900,83,33,34),_toggle_pause)
    pause.set_meta("kitchen_action","pause")
    var pause_text := _source_label("Ⅱ",Rect2(900,83,33,34),26)
    pause_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

    # All people start at the approved head height and end behind the front of the counter.
    for order in rules.orders:
        var slot := int(order.get("slot",rules.orders.find(order)))
        var actor := _waiter_actor(order,slot)
        figures.append({"node":actor,"overlay":null,"order":order,"base":actor.position})
    for departure in departures:
        departure.order.action = "carrying" if bool(departure.completed) and departure.elapsed < 0.25 else "leaving"
        var actor := _waiter_actor(departure.order,int(departure.slot))
        actor.position.x = maxf(0.0,float(departure.elapsed)-0.25)*240.0
        actor.modulate.a = clampf((Rules.DEPARTURE_SECONDS-float(departure.elapsed))/0.3,0,1)
        departure.node = actor

    # Clean foreground counter covers the lower body; no full-body waiter is raised above it.
    var foreground := TextureRect.new()
    foreground.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    var foreground_texture := AtlasTexture.new()
    foreground_texture.atlas = load("res://assets/kitchen/mobile/background/base_kitchen_no_fire.png")
    var ratio := foreground_texture.atlas.get_size()/Art.UI_REFERENCE_SIZE
    foreground_texture.region = Rect2(Vector2(0,555)*ratio,Vector2(941,205)*ratio)
    foreground.texture = foreground_texture
    foreground.position = Vector2(0,650)
    foreground.size = Vector2(941,205)
    foreground.mouse_filter = Control.MOUSE_FILTER_IGNORE
    playfield.add_child(foreground)

    for order in rules.orders:
        _draw_order(order,int(order.get("slot",0)))
    # Trays are at the serving plane in front of the counter. Keep received food visible
    # at the edge of adjacent order cards; all coordinates still come from each pose.
    for figure in figures:
        figure.overlay = _tray_layer(figure.order,int(figure.order.get("slot",0)))
    for departure in departures:
        departure.overlay = _tray_layer(departure.order,int(departure.slot))
        departure.overlay.position = departure.node.position
        departure.overlay.modulate = departure.node.modulate

    var station_first_child := playfield.get_child_count()
    for i in rules.pots.size():
        _station_surface(i)
        var pot: Dictionary = rules.pots[i]
        var wok_rect := Rect2(14+i*308,694,286,239)
        var available_rows: Array = rules.available()
        var row: Dictionary = rules.recipe_data(str(pot.recipe))
        if row.is_empty() and not available_rows.is_empty(): row = available_rows[0]
        var group := str(row.get("visual_group",pot.recipe))
        var station := str(row.get("visual_station_id",row.get("station_id","wok")))
        var hot := station in ["stock_wok","steamer","grill"]
        if pot.state in ["cooking","ready"] and hot:
            # Heat is fixed; draw a separate fire behind this unlocked hot station.
            Art.put_configured(playfield,"effect/flame",Rect2(69+i*308,869,180,66),false)
        Art.put_configured(playfield,"station/"+station+"/body",wok_rect)
        if pot.state != "empty":
            var stage := "burnt" if pot.state == "invalid" else str(pot.state)
            var dish_id := str(row.get("dish_id",pot.recipe))
            var content := Art.put_configured(playfield,"content/"+dish_id+"/"+stage,_station_content_rect(station,stage,i))
            content.set_meta("pot_visual",i)
            content.set_meta("recipe_id",dish_id)
            if stage in ["cooking","ready"]:
                if station == "cold_mix":
                    Art.put_configured(playfield,"effect/cold_glint",Rect2(232+i*308,824,34,38),false)
                elif station == "grill":
                    Art.put_configured(playfield,"effect/sizzle",Rect2(114+i*308,790,100,64),false)
                elif stage == "cooking":
                    Art.put_configured(playfield,"effect/steam",Rect2(104+i*308,720,94,94),false)
            if stage == "burnt" and station != "cold_mix":
                Art.put_configured(playfield,"effect/smoke",Rect2(92+i*308,698,124,116),false)
            elif stage == "ready":
                Art.put_configured(playfield,"effect/ready_sparkle",Rect2(227+i*308,752,62,54),false)
        var pot_hit := _source_hit(Rect2(14+i*308,748,286,199),func():
            selected_pot=i
            if rules.pots[i].state in ["burnt","invalid"]: rules.clear_pot(i)
            _render())
        pot_hit.set_meta("pot_index",i)
        if i == selected_pot:
            var underline := Line2D.new()
            underline.points = PackedVector2Array([Vector2(28+i*308,957),Vector2(285+i*308,957)])
            underline.width = 3
            underline.default_color = Color("ffcf69")
            playfield.add_child(underline)
        var badge_rect := Rect2(70+i*308,976,230,108)
        var ready: bool = pot.state == "ready"
        var badge := _source_box(badge_rect,Color("9e2117") if ready else (Color("8a510b") if pot.state == "cooking" else Color("383536")),Color("f5cb79"))
        var label := _panel_label(badge,"",Rect2(6,26,218,50),32,Color("fff5dd"))
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.autowrap_mode = TextServer.AUTOWRAP_OFF
        timers.append({"label":label,"index":i})
        if ready:
            var serve_hit := _source_hit(badge_rect,func():
                selected_pot = i
                rules.serve_pot(i)
                _render())
            serve_hit.set_meta("kitchen_action","serve")
            serve_hit.set_meta("serve_pot_index",i)
            pot_hit.set_meta("ready_mark",true)
            _source_label("✦",Rect2(33+i*308,1013,34,38),30,Color("ffe890"))

    # All levels retain three visual station positions; unopened positions
    # stay locked, preserving the apprentice's single usable pot.
    for index in range(rules.pots.size(),3):
        _station_surface(index)
        var locked := Art.put_configured(playfield,"station/stock_wok/body",Rect2(14+index*308,694,286,239))
        locked.modulate = Color(0.42,0.39,0.34)
        locked.set_meta("locked_station",index)
        var badge := _source_box(Rect2(70+index*308,976,230,108),Color("342b25"),Color("967448"))
        var label := _panel_label(badge,"未解锁",Rect2(6,26,218,50),26,Color("c0a175"))
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

    # Move each complete station, its input region and status action together.
    for child_index in range(station_first_child,playfield.get_child_count()):
        var node := playfield.get_child(child_index)
        node.position.y += 86
        if node.has_meta("base_position"):
            node.set_meta("base_position",node.get_meta("base_position")+Vector2(0,86))

    # Eight fixed layout slots hold data-selected ingredients, not eight permanent ingredient types.
    var ingredients := _tray_ingredients()
    for index in ingredients.size():
        var ingredient: String = ingredients[index]
        var rect := _ingredient_slot_rect(index)
        var ingredient_box := _wood_box(playfield,rect)
        ingredient_box.set_meta("ingredient_wood_box",ingredient)
        Art.put_configured(playfield,"ingredient/"+ingredient,Rect2(rect.position+Vector2(8,8),Vector2(rect.size.x-16,rect.size.y-52)))
        _source_label(ingredient,Rect2(rect.position+Vector2(8,rect.size.y-42),Vector2(rect.size.x-16,34)),24,Color("ffe2ad"))
        var hit := _source_hit(rect,func(): _tap_ingredient(ingredient))
        hit.set_meta("kitchen_action",ingredient)
    _draw_serving_counter()
    Art.put_configured(playfield,"ui/deliver",Art.UI_REGIONS.deliver)
    var delivery_hit := _source_hit(Art.UI_REGIONS.deliver,func():
        rules.deliver_auto(selected_plate)
        selected_plate = -1
        _render())
    delivery_hit.set_meta("kitchen_action","deliver")
    guide = null
    if rules.level == 1:
        _source_fill(Rect2(150,1166,640,50),Color(0.12,0.06,0.03,0.78))
        guide = _source_label("",Rect2(150,1164,640,54),GUIDE_FS,Color("ffe9b0"))
        guide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        guide.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        guide.autowrap_mode = TextServer.AUTOWRAP_OFF
        guide.add_theme_color_override("font_outline_color",Color("3a1a0a"))
        guide.add_theme_constant_override("outline_size",4)
        guide.set_meta("kitchen_guide",true)
    status = _source_label("",Rect2(22,1593,896,39),24,Color("ffefc6"))
    status.add_theme_color_override("font_outline_color",Color("542811"))
    status.add_theme_constant_override("outline_size",3)
    if rules.paused: _pause_overlay()
    _update_live_labels()

func _station_content_rect(station: String, stage: String, index: int) -> Rect2:
    # Each complete food layer is fitted to the empty station's actual working surface.
    # Coordinates are reference pixels, so phone scaling applies to all layers together.
    var area: Rect2 = {
        "stock_wok":Rect2(53,750,206,114),
        "steamer":Rect2(42,721,173,109),
        "grill":Rect2(41,728,230,113),
        "cold_mix":Rect2(53,755,194,107),
        "candy_press":Rect2(31,739,137,98)
    }.get(station,Rect2(53,750,206,114))
    if station == "candy_press" and stage in ["ready","burnt"]:
        area = Rect2(142,768,137,110)
    area.position.x += index*308
    return area

func _source_fill(rect: Rect2, color: Color) -> void:
    var fill := ColorRect.new()
    fill.position = rect.position
    fill.size = rect.size
    fill.color = color
    fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
    playfield.add_child(fill)

func _source_label(text: String, rect: Rect2, fs: int, color := Color("fff0d0")) -> Label:
    return _panel_label(playfield,text,rect,fs,color)

func _source_box(rect: Rect2, bg: Color, border: Color) -> Panel:
    var box := Panel.new()
    box.position = rect.position
    box.size = rect.size
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.border_color = border
    style.set_border_width_all(3)
    style.set_corner_radius_all(9)
    box.add_theme_stylebox_override("panel",style)
    playfield.add_child(box)
    return box

func _source_hit(rect: Rect2, action: Callable) -> Button:
    var hit := Button.new()
    hit.position = rect.position
    hit.size = rect.size
    hit.flat = true
    for state_name in ["normal","hover","pressed","focus","disabled"]:
        hit.add_theme_stylebox_override(state_name,StyleBoxEmpty.new())
    hit.pressed.connect(action)
    playfield.add_child(hit)
    return hit

func _tray_ingredients() -> Array[String]:
    var ingredients: Array[String] = []
    var pot: Dictionary = rules.pots[selected_pot]
    if not str(pot.recipe).is_empty():
        for item in rules.recipe_data(str(pot.recipe)).ingredients:
            if not str(item) in ingredients: ingredients.append(str(item))
    else:
        for row in rules.available():
            for item in row.ingredients:
                if not str(item) in ingredients and ingredients.size() < 8: ingredients.append(str(item))
    if ingredients.size() > 8:
        var first := mini((pot.ingredients.size() / 8)*8,((ingredients.size()-1)/8)*8)
        return ingredients.slice(first,first+8)
    return ingredients

func _draw_dish(parent: Node, id: String, rect: Rect2) -> void:
    Art.put_configured(parent,"dish/"+id,rect)

func _waiter_foot(slot: int) -> Vector2:
    # Modern full-body sprites have wider faces/trays than the old reference half figures.
    # Keep faces and the received dishes to the left of each order column.
    return Vector2([154.0,462.0,770.0][clampi(slot,0,2)],810.0)

func _waiter_actor(order: Dictionary, slot: int) -> Control:
    var actor := Control.new()
    actor.mouse_filter = Control.MOUSE_FILTER_IGNORE
    actor.size = Art.UI_REFERENCE_SIZE
    actor.clip_contents = false
    playfield.add_child(actor)
    _refresh_actor_action(actor,order,slot)
    return actor

func _refresh_actor_action(actor: Control, order: Dictionary, slot: int) -> void:
    var identity: String = str(order.get("character","server_female_1" if bool(order.get("female",false)) else "server_male_1"))
    var action := str(order.get("action","confirm" if float(order.get("confirm_left",0.0)) > 0 else "carrying" if order.has("last_dish") else "waiting"))
    var key := "character/"+identity+"/"+action
    if actor.get_meta("character_asset","") == key: return
    for child in actor.get_children(): child.queue_free()
    actor.set_meta("character_asset",key)
    Art.put_anchored(actor,key,_waiter_foot(slot))

func _received_dishes(order: Dictionary) -> Array:
    return order.dishes.filter(func(dish): return bool(dish.done)).map(func(dish): return str(dish.recipe))

func _tray_layer(order: Dictionary, slot: int) -> Control:
    var layer := Control.new()
    layer.size = Art.UI_REFERENCE_SIZE
    layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.set_meta("waiter_tray_order",order.id)
    playfield.add_child(layer)
    _refresh_tray(layer,order,slot)
    return layer

func _refresh_tray(layer: Control, order: Dictionary, slot: int) -> void:
    var received: Array = _received_dishes(order)
    var action := str(order.get("action","confirm" if float(order.get("confirm_left",0.0)) > 0 else "carrying" if not received.is_empty() else "waiting"))
    var fingerprint := action+"/"+"/".join(received)
    if layer.get_meta("tray_contents","") == fingerprint: return
    for child in layer.get_children(): child.queue_free()
    layer.set_meta("tray_contents",fingerprint)
    # Same dish IDs as orders/plates; received servings only, never the whole requested menu.
    var identity: String = str(order.get("character","server_male_1"))
    var key := "character/"+identity+"/"+action
    var entry: Dictionary = Art.visual_assets.get(key,{})
    if not bool(entry.get("approved",false)) or not entry.has("tray_surface"): return
    var reference_scale := float(entry.get("scale_in_reference",1.0))
    var anchor: Array = entry.get("foot_anchor",[0,0])
    var surface: Array = entry.tray_surface
    var actor_origin := _waiter_foot(slot)-Vector2(float(anchor[0]),float(anchor[1]))*reference_scale
    var tray_rect := Rect2(actor_origin+Vector2(float(surface[0]),float(surface[1]))*reference_scale,Vector2(float(surface[2]),float(surface[3]))*reference_scale)
    layer.set_meta("tray_surface_rect",tray_rect)
    # Food is aligned to this action's actual empty tray, in the same coordinates as the body.
    for i in received.size():
        var cell_width := tray_rect.size.x/float(received.size())
        var height := minf(82.0,cell_width*0.85)
        var dish_rect := Rect2(Vector2(tray_rect.position.x+i*cell_width,tray_rect.position.y+tray_rect.size.y-height),Vector2(cell_width-2,height))
        var dish := Art.put_configured(layer,"dish/"+str(received[i]),dish_rect)
        dish.set_meta("tray_dish",received[i])
    if bool(order.get("impatient",false)):
        var emotion := _panel_label(layer,"等太久了",Rect2(28+slot*308,273,145,32),24,Color("d84526"))
        emotion.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _wood_box(parent: Control, rect: Rect2, selected := false) -> Panel:
    var box := Panel.new()
    box.position = rect.position
    box.size = rect.size
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var frame := StyleBoxFlat.new()
    frame.bg_color = Color("663717")
    frame.border_color = Color("ffd08b") if selected else Color("b98749")
    frame.set_border_width_all(4 if selected else 3)
    frame.set_corner_radius_all(2)
    box.add_theme_stylebox_override("panel",frame)
    parent.add_child(box)
    var inset := ColorRect.new()
    inset.position = Vector2(6,6)
    inset.size = Vector2(maxf(0,rect.size.x-12),maxf(0,rect.size.y-12))
    inset.color = Color("482713")
    inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
    box.add_child(inset)
    for index in 4:
        var grain := ColorRect.new()
        grain.position = Vector2(10+index%2*6,14+index*(rect.size.y-24)/4.0)
        grain.size = Vector2(maxf(0,rect.size.x-26-index%2*13),2)
        grain.color = Color(0.78,0.48,0.22,0.15)
        grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
        box.add_child(grain)
    return box

func _station_surface(index: int) -> void:
    # Reuse the approved kitchen's actual stone/wood surface, rather than a
    # featureless color panel, under each independently positioned station.
    var source := Rect2(6+index*308,680,300,398)
    _source_box(source,Color("49423b"),Color("977953"))
    var stone := TextureRect.new()
    stone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    var atlas := AtlasTexture.new()
    atlas.atlas = load("res://assets/kitchen/mobile/background/base_kitchen_no_fire.png")
    var ratio := atlas.atlas.get_size()/Art.UI_REFERENCE_SIZE
    atlas.region = Rect2((source.position+Vector2(4,4))*ratio,(source.size-Vector2(8,8))*ratio)
    stone.texture = atlas
    stone.position = source.position+Vector2(4,4)
    stone.size = source.size-Vector2(8,8)
    stone.modulate = Color(0.80,0.78,0.74)
    stone.mouse_filter = Control.MOUSE_FILTER_IGNORE
    playfield.add_child(stone)

func _ingredient_slot_rect(index: int) -> Rect2:
    return Rect2(18+(index%4)*177,1210+(index/4)*147,174,138)

func _draw_serving_counter() -> void:
    # Three separate place settings belong to the three service positions.
    for slot in 3:
        var empty := Art.put_configured(playfield,"plate/empty",Rect2(18+slot*308,646,280,108))
        empty.set_meta("serving_counter_plate",true)
        empty.set_meta("empty_counter_plate_slot",slot)
    # Prepared servings are distributed across the counter with two usable
    # touch targets per place setting; the rules still match the actual order.
    var allocations: Array = [[],[],[]]
    for plate in rules.plates:
        var slot := 1
        for order in rules.orders:
            if int(order.id) == int(plate.order_id):
                slot = int(order.get("slot",1))
                break
        if allocations[slot].size() >= 2:
            for alternate in 3:
                if allocations[alternate].size() < 2:
                    slot = alternate
                    break
        allocations[slot].append(plate)
    for slot in 3:
        var servings: Array = allocations[slot]
        var width := 280.0/maxf(1.0,servings.size())
        for index in servings.size():
            var plate: Dictionary = servings[index]
            var rect := Rect2(18+slot*308+index*width,646,width-3,108)
            if selected_plate == int(plate.id):
                var marker := _source_box(rect,Color(0.0,0.0,0.0,0.0),Color("ffd08b"))
                marker.set_meta("selected_serving_plate",plate.id)
            var picture := Art.put_configured(playfield,"dish/"+str(plate.recipe),Rect2(rect.position+Vector2(5,5),rect.size-Vector2(10,10)))
            _trim_menu_padding(picture)
            picture.set_meta("serving_counter_plate",true)
            picture.set_meta("prepared_counter_slot",slot)
            var hit := _source_hit(rect,func(): selected_plate=int(plate.id); _render())
            hit.set_meta("plate_id",plate.id)

func _trim_menu_padding(node: Control) -> void:
    # Fixed menu pictures use the full visible sprite, without transparent outer
    # padding. Source textures and other kitchen presentations stay untouched.
    if not node is TextureRect or node.texture == null: return
    var key: int = node.texture.get_instance_id()
    if not menu_texture_cache.has(key):
        var source: Texture2D = node.texture
        # 不从显卡读图（README：get_image 在微信里崩）：裁多少照电脑上算好的 assets/used_rects.json（tools/bake_used.py）；没算过的不裁
        var used: Rect2i = UsedRects.rect(source.resource_path)
        if used.size == Vector2i.ZERO: return
        var cropped := AtlasTexture.new()
        cropped.atlas = source
        cropped.region = Rect2(used)
        menu_texture_cache[key] = cropped
    node.texture = menu_texture_cache[key]
    # These recipe/ingredient assets are stills. Avoid the generic animator
    # replacing their menu-only crop with the full padded source every frame.
    node.remove_meta("frames")

func _draw_order(order: Dictionary, slot: int) -> void:
    # Each person has a horizontal row of picture recipes above their head.
    # Only reward and the shared clock use numbers; food and ingredients use art.
    var count: int = order.dishes.size()
    var gap := 8.0
    var narrow_three := count == 3 and panel.scale.x*playfield.scale.x < 0.5
    var card_width: float = 140.0 if narrow_three else [276.0,140.0,92.0][clampi(count-1,0,2)]
    var card_height := 108.0 if narrow_three else 196.0
    var board_width := 288.0 if narrow_three else count*card_width+(count-1)*gap
    var base := Rect2(10.0+slot*308.0+(292.0-board_width)/2.0,126 if narrow_three else 146,board_width,220 if narrow_three else 237)
    var board := Control.new()
    board.position = base.position
    board.size = base.size
    board.mouse_filter = Control.MOUSE_FILTER_IGNORE
    playfield.add_child(board)
    board.set_meta("waiter_order_board",true)
    board.set_meta("order_id",order.id)
    board.set_meta("source_rect",base)
    var pending: Dictionary = {}
    var pot: Dictionary = rules.pots[selected_pot]
    for dish_index in count:
        var dish: Dictionary = order.dishes[dish_index]
        if pending.is_empty() and not bool(dish.done): pending = dish
        var selected := int(pot.order_id) == int(order.id) and int(pot.dish_index) == dish_index
        var card_position := Vector2((dish_index%2)*(card_width+gap),(dish_index/2)*112) if narrow_three else Vector2(dish_index*(card_width+gap),0)
        var card := _wood_box(board,Rect2(card_position,Vector2(card_width,card_height)),selected and not bool(dish.done))
        # Warm paper inside a wood rim matches the approved illustrated menu.
        var paper: ColorRect = card.get_child(0)
        paper.color = Color("f5e1bb")
        card.set_meta("order_card",true)
        card.set_meta("order_dish_done",bool(dish.done))
        card.set_meta("order_recipe",str(dish.recipe))
        card.set_meta("source_rect",Rect2(base.position+card.position,card.size))
        card.set_meta("narrow_menu_rows",narrow_three)
        var recipe: Dictionary = rules.recipe_data(str(dish.recipe))
        var dish_picture := Art.put_configured(card,"dish/"+str(dish.recipe),Rect2(5,4,card_width-10,56 if narrow_three else 136))
        _trim_menu_padding(dish_picture)
        dish_picture.set_meta("order_dish_picture",true)
        var required: Array = dish.get("ingredients",recipe.ingredients)
        card.set_meta("order_recipe_ingredients",required.duplicate())
        var columns := mini(required.size(),4)
        var rows := ceili(float(required.size())/maxf(1.0,columns))
        var ingredient_size := minf(42.0,(card_width-10.0)/maxf(1.0,columns))
        var ingredient_left := (card_width-columns*ingredient_size)/2.0
        var ingredient_height := (24.0 if narrow_three else 30.0)/maxf(1.0,rows)
        for index in required.size():
            var icon := Art.put_configured(card,"ingredient/"+str(required[index]),Rect2(ingredient_left+(index%columns)*ingredient_size,(60.0 if narrow_three else 140.0)+(index/columns)*ingredient_height,ingredient_size,ingredient_height))
            _trim_menu_padding(icon)
            icon.set_meta("ingredient_icon",required[index])
            icon.set_meta("ingredient_step",index)
        var reward_width := 50.0
        var reward_left := (card_width-reward_width)/2.0
        Art.put_piece(card,"coin_icon",Rect2(reward_left,85 if narrow_three else 173,19,19))
        var reward := _panel_label(card,str(int(recipe.get("coins",0))),Rect2(reward_left+24,83 if narrow_three else 171,29,25),24,Color("63300f"))
        reward.autowrap_mode = TextServer.AUTOWRAP_OFF
        reward.set_meta("order_reward",int(recipe.get("coins",0)))
        var click := Button.new()
        click.flat = true
        click.size = card.size
        click.disabled = bool(dish.done)
        for state_name in ["normal","hover","pressed","focus","disabled"]:
            click.add_theme_stylebox_override(state_name,StyleBoxEmpty.new())
        for state_name in ["hover","pressed","focus"]:
            var touch_style := StyleBoxFlat.new()
            touch_style.bg_color = Color(0.72,0.40,0.13,0.10 if state_name == "hover" else 0.18 if state_name == "pressed" else 0.0)
            if state_name == "focus":
                touch_style.border_color = Color("b76b25")
                touch_style.set_border_width_all(2)
            click.add_theme_stylebox_override(state_name,touch_style)
        click.set_meta("order_dish",true)
        click.set_meta("order_id",order.id)
        click.set_meta("dish_index",dish_index)
        click.pressed.connect(func():
            if rules.choose_order_dish(selected_pot,int(order.id),dish_index): _render()
            else: _hint_wrong("先点一口空锅，再点要做的菜"))
        card.add_child(click)
        if dish.done: card.modulate = Color(0.72,0.72,0.70,1)
    var clock_position := Vector2(148,164) if narrow_three else Vector2(0,199)
    var clock_width := 126.0 if narrow_three else board_width
    var clock_box := _wood_box(board,Rect2(clock_position,Vector2(clock_width,38)))
    var timer := _panel_label(clock_box,"",Rect2(3,0,clock_width-6,28),24,Color("ffe0aa"))
    timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    timer.set_meta("waiter_patience_timer",true)
    if not pending.is_empty():
        order_labels.append({"label":timer,"order":order,"dish":pending,"show_patience":true})
    var track := ColorRect.new()
    track.position = Vector2(10,29)
    track.size = Vector2(clock_width-20,8)
    track.color = Color("24190d")
    track.mouse_filter = Control.MOUSE_FILTER_IGNORE
    clock_box.add_child(track)
    var fill := ColorRect.new()
    fill.size = track.size
    fill.color = Color("76aa37")
    fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
    track.add_child(fill)
    patience_bars.append({"fill":fill,"width":track.size.x,"order":order})

func _update_live_labels() -> void:
    if is_instance_valid(coin_label): coin_label.text = str(int(wallet.coins))
    for entry in timers:
        if not is_instance_valid(entry.label): continue
        var pot: Dictionary = rules.pots[entry.index]
        var caption := "空锅"
        var seconds := 0
        if pot.state == "prep": caption = "加料"
        elif pot.state == "cooking":
            caption = "烹饪"
            seconds = ceili(maxf(0,float(rules.recipe_data(str(pot.recipe)).seconds)-float(pot.cook)))
        elif pot.state == "ready":
            caption = "盛出"
            seconds = ceili(maxf(0,float(rules.recipe_data(str(pot.recipe)).window)-float(pot.late)))
        elif pot.state == "burnt":
            caption = "变质 · 重做" if str(rules.recipe_data(str(pot.recipe)).get("visual_group","")) == "cold_mix" else "烧焦 · 重做"
        elif pot.state == "invalid": caption = "加错 · 重做"
        entry.label.text = "%s %02d:%02d" % [caption,seconds/60,seconds%60] if pot.state in ["cooking","ready"] else caption
    for entry in order_labels:
        if is_instance_valid(entry.label):
            var seconds := maxi(0,ceili(float(entry.order.left)))
            entry.label.text = "◴ %02d:%02d" % [seconds/60,seconds%60] if entry.show_patience and not entry.dish.done else ""
    for entry in patience_bars:
        if not is_instance_valid(entry.fill): continue
        var fraction := clampf(float(entry.order.left)/maxf(0.01,float(entry.order.total)),0.0,1.0)
        entry.fill.size.x = float(entry.width)*fraction
        entry.fill.color = Color("bc4c36") if fraction < 0.25 else Color("c4953f") if fraction < 0.5 else Color("739849")
    if is_instance_valid(status): status.text = _feedback_text()
    if is_instance_valid(guide): guide.text = guide_flash if guide_flash_t > 0.0 else guide_text()

## 第 1 关：照现在该做的那一步说一句（流程：点服务员头上要的菜 → 照菜下面的小图一样样点原料 → 烧 → 熟了点锅下面「盛出」→ 点「交菜」）
func guide_text() -> String:
    if rules.paused or not rules.active: return ""
    for p in rules.pots:
        if p.state == "ready": return "熟了！点锅下面的「盛出」"
    if not rules.plates.is_empty(): return "装好盘了，点右下角「交菜」"
    var pot: Dictionary = rules.pots[selected_pot]
    match str(pot.state):
        "prep":
            var need: Array = pot.required
            var have: int = pot.ingredients.size()
            return "点原料：%s" % str(need[have]) if have < need.size() else ""
        "cooking": return "正在烧，熟了点锅盛出"
        "burnt", "invalid": return "这锅坏了，点一下锅清掉重做"
    for o in rules.orders:
        for d in o.dishes:
            if not d.done: return "点服务员头上要的那道菜"
    return "等服务员来点菜"

## 点错了先说为什么（第 1 关在大字那行闪 2 秒；别的关照旧在底下那行）
func _hint_wrong(text: String) -> void:
    rules.message = text
    guide_flash = text
    guide_flash_t = 2.0
    _update_live_labels()

## 点原料：锅里正在加料就加；不是的话说该先干什么（原来锅不在加料时原料格直接点不动、也不说为什么）
func _tap_ingredient(ingredient: String) -> void:
    var pot: Dictionary = rules.pots[selected_pot]
    if pot.state == "prep":
        rules.add_ingredient(selected_pot,ingredient)
        guide_flash_t = 0.0
        _render()
        return
    match str(pot.state):
        "empty": _hint_wrong("先点服务员头上要的菜，再放原料")
        "cooking": _hint_wrong("这锅正在烧，等熟了点「盛出」")
        "ready": _hint_wrong("熟了，先点锅下面的「盛出」")
        _: _hint_wrong("这锅坏了，点一下锅清掉重做")

func _feedback_text() -> String:
    # Pictures and state badges already explain routine progress. Only the next
    # ingredient, rewards and actionable mistakes need an additional message.
    var message: String = rules.message
    if message.begins_with("下一步加入："): return message
    if message.begins_with("按菜谱顺序加入食材：") or message.begins_with("照订单加入："):
        var pot: Dictionary = rules.pots[selected_pot]
        if pot.state == "prep" and not pot.required.is_empty(): return "先加："+str(pot.required[0])
        return ""
    if message.begins_with("交菜成功，获得 "): return "+ "+message.trim_prefix("交菜成功，获得 ")
    if message in ["先选菜谱，再点食材加进锅里","正在烧，熟了点锅盛出","装好盘了，点交菜","锅已清理，可以重新做菜","本关完成！厨艺更上一层","继续做菜，留意每一口锅的火候"] or rules.paused: return ""
    return message

func _on_order_departed(order: Dictionary, completed_order: bool) -> void:
    var leaving := order.duplicate(true)
    leaving.action = "carrying" if completed_order else "leaving"
    leaving.impatient = not completed_order
    departures.append({"order":leaving,"slot":order.get("slot",0),"completed":completed_order,"elapsed":0.0,"node":null,"overlay":null})

func _pause_overlay() -> void:
    var veil := ColorRect.new()
    veil.color = Color(0.1,0.05,0.02,0.7)
    veil.size = Art.UI_REFERENCE_SIZE
    playfield.add_child(veil)
    _source_box(Rect2(180,590,580,350),Color("3d2114"),Color("d7a658"))
    var text := _source_label("已暂停",Rect2(210,625,520,55),32)
    text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    var resume := _source_hit(Rect2(230,715,480,74),_toggle_pause)
    resume.set_meta("kitchen_action","pause")
    _source_label("继续做菜",Rect2(350,730,280,50),32)
    _source_hit(Rect2(230,820,480,74),_close)
    _source_label("回后厅",Rect2(350,835,280,50),30)

func _exit_confirmation() -> void:
    _base("要离开这次接单吗？")
    status = null
    _label("已赚取的金币保留。\n本局未完成的订单和锅中食材不保留。",Rect2(24,220,492,100),23)
    _button("继续做菜",Rect2(24,430,492,60),func(): rules.paused=false; _render(),true)
    _button("结束本局 · 回到选关",Rect2(24,520,492,60),func(): rules.active=false; _menu())

## 结算卡（04 10/2：字飘在背景上没底板）：垫小游戏外壳那张卡片 MG-U05（base_ui_card_v1.png，米色纸、九宫格），
## 字照旧游戏写，纸是浅的所以用深色字；标题、交了几道、学会了、这局做的菜、金币都居中
func _result() -> void:
    _base("")
    status = null
    guide = null
    var card := Panel.new()
    var sb = UISkin.card_box()
    if sb != null: card.add_theme_stylebox_override("panel",sb)
    card.position = Vector2(40,70)
    card.size = Vector2(460,560)
    card.mouse_filter = Control.MOUSE_FILTER_IGNORE
    card.set_meta("kitchen_result_card",true)
    panel.add_child(card)
    var lines: Array = []
    lines.append([("接单完成" if rules.won else "这次先歇一歇"),40,UISkin.CARD_HEAD])
    lines.append(["交了 %d 道菜" % rules.completed,30,UISkin.CARD_INK])
    if not rules.won: lines.append([rules.message,22,UISkin.CARD_INK])
    if not learned_this_round.is_empty(): lines.append(["学会了 %s" % "、".join(learned_this_round),30,UISkin.CARD_HEAD])
    var dishes: Array = []
    for id in rules.served_counts:
        dishes.append("%s ×%d" % [rules.recipe_data(id).name,rules.served_counts[id]])
    if not dishes.is_empty(): lines.append(["　".join(dishes),26,UISkin.CARD_INK])
    lines.append(["+ %d 金币" % rules.earned,36,Color("8a4b00")])
    var y := 92.0
    for line in lines:
        var l := _panel_label(card,str(line[0]),Rect2(UISkin.CARD_ML-8,y,460-2*(UISkin.CARD_ML-8),int(line[1])*2.4),int(line[1]),line[2])
        l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        l.set_meta("kitchen_result_line",true)
        y += maxf(float(line[1])*1.7,l.get_combined_minimum_size().y+12.0)
    _button("继续下一关" if rules.won else "再试一次",Rect2(40,660,460,66),func(): _start(mini(30,rules.level+1) if rules.won else rules.level),true)
    _button("回到选关",Rect2(40,750,460,60),_menu)

func _close() -> void:
    rules.active = false
    closed.emit()
    queue_free()
