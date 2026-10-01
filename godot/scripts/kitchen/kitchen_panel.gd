extends Control
## 手机竖屏可玩原型。玩法和 UI 分开，后续美术替换不会改变计时规则。
signal closed
const Art = preload("res://scripts/kitchen/kitchen_art.gd")
const Rules = preload("res://scripts/kitchen/kitchen_rules.gd")
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
var saved_path := "user://suqi_kitchen.json"
var round_saved := false
var render_due := false
var figures: Array = []

func open(save, f: Font) -> void:
    wallet = save
    game_font = f
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    z_index = 20
    if FileAccess.file_exists(saved_path):
        var d = JSON.parse_string(FileAccess.get_file_as_string(saved_path))
        if d is Dictionary: unlocked = clampi(int(d.get("unlocked",1)),1,30)
    rules.delivered.connect(func(n): wallet.earn(n))
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
    backdrop.texture = preload("res://scripts/canvas_assets.gd").texture("res://assets/kitchen/kitchen_room_v1.png")
    backdrop.size = Vector2(540,960)
    backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    backdrop.modulate = Color(0.27,0.23,0.23,1)
    panel.add_child(backdrop)
    _label(title,Rect2(24,20,490,40),26,Color("ffd894"))
    _label("罗曼山庄 · 后厨",Rect2(24,62,480,28),18,Color("d2bca3"))

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

func _menu() -> void:
    _base("灶火与手艺")
    _label("%s  ·  已开放第 %d 关" % [Rules.title_for(unlocked),unlocked],Rect2(24,112,490,48),24)
    _label("系好围裙，开始接单。\n照看火候，把热腾腾的菜交给服务员。",Rect2(24,175,485,80),22)
    _label("第一关：一口锅，跷脚牛肉\n提前出锅没熟，拖得太久会糊。\n每交一道合格菜，立即获得金币。",Rect2(24,285,350,115),21)
    Art.put(panel,"chef",Rect2(382,275,130,150))
    _button("穿上厨师套装 · 开始第 %d 关" % unlocked,Rect2(24,440,492,66),func(): _start(unlocked),true)
    var picker := OptionButton.new()
    picker.position = Vector2(24,526)
    picker.size = Vector2(314,58)
    picker.add_theme_font_override("font",game_font)
    picker.add_theme_font_size_override("font_size",20)
    for stage in range(1,unlocked+1): picker.add_item("重玩第 %d 关" % stage)
    picker.select(unlocked-1)
    panel.add_child(picker)
    _button("开始重玩",Rect2(354,526,162,58),func(): _start(picker.selected+1))
    _label("菜谱将随关卡解锁\n苏七家乡菜 → 川菜 → 粤菜 → 上海菜",Rect2(24,630,490,85),20)
    _button("脱下围裙 · 返回厨房",Rect2(24,852,492,60),_close)

func _start(stage: int) -> void:
    selected_pot = 0
    selected_plate = -1
    round_saved = false
    rules.start(stage)
    _render()

func _process(dt: float) -> void:
    if not is_instance_valid(status): return
    var old_states: Array = rules.pots.map(func(p): return p.state)
    var old_ids: Array = rules.orders.map(func(o): return o.id)
    rules.tick(dt)
    if not rules.active:
        if not round_saved:
            round_saved = true
            if rules.won:
                unlocked = maxi(unlocked, mini(30,rules.level+1))
                var f = FileAccess.open(saved_path, FileAccess.WRITE)
                if f: f.store_string(JSON.stringify({"version":1,"unlocked":unlocked}))
            _result()
        return
    if old_states != rules.pots.map(func(p): return p.state) or old_ids != rules.orders.map(func(o): return o.id):
        _render()
    if is_instance_valid(status): status.text = rules.message
    for figure in figures:
        if is_instance_valid(figure.node):
            figure.node.position.y = figure.y + sin(Time.get_ticks_msec()/500.0+figure.phase)*1.5
            figure.node.position.x = figure.x + (1.0-minf(1.0,float(figure.order.get("age",0.0))/0.6))*45.0
            figure.node.modulate = Color("ffb391") if figure.order.left < figure.order.total*0.3 else Color.WHITE
    for entry in timers:
        if not is_instance_valid(entry.label): continue
        var p: Dictionary = rules.pots[entry.index]
        var r := Rules.recipe(p.recipe)
        var text := "空锅"
        if p.state == "prep": text = "等待加料"
        elif p.state == "cooking": text = "煮制 %.1f 秒" % maxf(0,float(r.seconds)-float(p.cook))
        elif p.state == "ready": text = "熟了！余 %.1f 秒" % maxf(0,float(r.window)-float(p.late))
        elif p.state == "burnt": text = "烧糊了！"
        elif p.state == "invalid": text = "配料有误"
        entry.label.text = text
    for entry in order_labels:
        if is_instance_valid(entry.label):
            entry.label.text = ("着急了 %d 秒" if entry.order.left < entry.order.total*0.3 else "等待 %d 秒") % maxi(0,ceili(entry.order.left))

func _render() -> void:
    _base("第 %d 关 · %s" % [rules.level, Rules.title_for(rules.level)])
    timers.clear()
    order_labels.clear()
    figures.clear()
    _label("已交 %d/%d 道   本局 +%d 金   离场 %d/3" % [rules.completed,rules.target,rules.earned,rules.missed],Rect2(24,100,492,32),18)
    _button("继续" if rules.paused else "暂停",Rect2(418,20,98,48),func(): rules.paused = not rules.paused; _render())
    for i in rules.orders.size():
        var o: Dictionary = rules.orders[i]
        var x: int = 24 + i * 166
        var figure := Art.put(panel,"female" if o.female else "male",Rect2(x+26,132,106,90))
        figures.append({"node":figure,"y":132.0,"x":float(x+26),"order":o,"phase":float(o.id)})
        var text := ""
        for d in o.dishes:
            text += ("✓ " if d.done else "· ") + str(Rules.recipe(d.recipe).name) + "\n"
        _button(text.strip_edges(),Rect2(x,222,158,72),func():
            if selected_plate >= 0:
                rules.deliver(selected_plate,int(o.id))
                selected_plate = -1
                _render()
            else:
                rules.message = "先在盛菜台选一道成菜，再点服务员交餐",false)
        var l := _label("",Rect2(x,296,160,26),17,Color("efbb78"))
        order_labels.append({"label":l,"order":o})
    for i in rules.pots.size():
        var p: Dictionary = rules.pots[i]
        var x: int = 24 + i*166
        var name := "选择菜谱" if p.recipe == "" else str(Rules.recipe(p.recipe).name)
        var pot_button := _button("",Rect2(x,335,158,74),func(): selected_pot=i; _render(),i==selected_pot)
        Art.put(pot_button,"burnt" if p.state == "burnt" else ("empty" if p.state in ["empty","prep"] else "soup"),Rect2(20,2,118,70))
        _label("%d · %s" % [i+1,name],Rect2(x,410,164,21),15)
        var l := _label("",Rect2(x,432,164,22),17)
        timers.append({"label":l,"index":i})
    var chosen: Dictionary = rules.pots[selected_pot]
    if chosen.state == "empty":
        _label("给 %d 号锅选菜谱" % (selected_pot+1),Rect2(24,454,480,30),19)
        var available := rules.available()
        for i in available.size():
            var r: Dictionary = available[i]
            _button(r.name,Rect2(24+(i%3)*166,494+(i/3)*52,158,46),func(): rules.choose(selected_pot,r.id); _render())
    else:
        var r := Rules.recipe(chosen.recipe)
        _label("顺序：%s  ·  %s火" % [" → ".join(r.ingredients),["","小","中","大"][int(r.heat)]],Rect2(24,454,492,38),17)
        for i in r.ingredients.size():
            var ingredient: String = r.ingredients[i]
            var b := _button(ingredient,Rect2(24+i*166,494,158,48),func(): rules.add_ingredient(selected_pot,ingredient); _render())
            b.disabled = chosen.state != "prep" or i < chosen.ingredients.size()
        for i in 3:
            _button(["小火","中火","大火"][i],Rect2(24+i*104,552,96,48),func(): rules.heat(selected_pot,i+1); _render(),int(chosen.heat)==i+1)
        _button("清锅",Rect2(348,552,168,48),func(): rules.clear_pot(selected_pot); _render())
    _button("盛出选中的锅",Rect2(24,616,492,52),func(): rules.serve_pot(selected_pot); _render(),true)
    _label("盛菜台 · 选成菜，再点服务员",Rect2(24,680,490,30),18)
    for i in rules.plates.size():
        var plate: Dictionary = rules.plates[i]
        _button(Rules.recipe(plate.recipe).name,Rect2(24+(i%3)*166,718+(i/3)*48,158,42),func(): selected_plate=plate.id; _render(),selected_plate==int(plate.id))
    Art.put(panel,"chef",Rect2(452,804,64,80))
    status = _label("已暂停，锅和服务员一起等待" if rules.paused else rules.message,Rect2(24,820,416,54),19,Color("ffd894"))
    _button("离开本局",Rect2(24,888,492,48),func():
        rules.paused=true
        _exit_confirmation())

func _exit_confirmation() -> void:
    _base("要离开这次接单吗？")
    status = null
    _label("已赚取的金币保留。\n本局未完成的订单和锅中食材不保留。",Rect2(24,220,492,100),23)
    _button("继续做菜",Rect2(24,430,492,60),func(): rules.paused=false; _render(),true)
    _button("结束本局 · 回到选关",Rect2(24,520,492,60),func(): rules.active=false; _menu())

func _result() -> void:
    _base("接单完成" if rules.won else "这次先歇一歇")
    status = null
    _label("交付 %d 道菜\n获得 %d 金币\n%s" % [rules.completed,rules.earned,rules.message],Rect2(24,200,492,160),25)
    _button("继续下一关" if rules.won else "再试一次",Rect2(24,470,492,64),func(): _start(mini(30,rules.level+1) if rules.won else rules.level),true)
    _button("回到选关",Rect2(24,560,492,60),_menu)

func _close() -> void:
    rules.active = false
    closed.emit()
    queue_free()
