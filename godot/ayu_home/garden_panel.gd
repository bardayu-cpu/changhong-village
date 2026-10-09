extends VBoxContainer
## Persistent, wallet-free gardening. Growth uses actual wall-clock seconds.
signal state_changed
const Data = preload("res://ayu_home/home_data.gd")
const GROW_SECONDS := 60
var state: Dictionary
var month := 10
var season := 2
var seed_index := 0
var fruit_index := 0
var ui_scale := 1.0
var host
var info: Label
var seed_button: Button
var fruit_button: Button
var beds: Array[Button] = []
var last_tick := -1
var now_override := -1.0

func configure(ctx: Dictionary, parent_activity) -> void:
	host = parent_activity
	ui_scale = host.ui_scale
	month = int(ctx.get("month", Time.get_datetime_dict_from_system().month))
	season = int(ctx.get("season_index", Data.season(month)))
	state = ctx.get("garden_state", {})
	if not state.has("beds"): state.beds = [{}, {}, {}]
	if not state.has("basket"): state.basket = {}
	if not state.has("fruit_next"): state.fruit_next = {}
	if not state.has("observed"): state.observed = {}
	if not state.has("harvest_total"): state.harvest_total = 0
	if not state.has("revision"): state.revision = 0
	add_theme_constant_override("separation", int(10 * ui_scale))
	info = host._label("%s季菜畦：%s。种下后浇水，真实等待60秒，再点菜畦采收。离开也会生长。" % [Data.SEASONS[season], "、".join(Data.CROPS[season])], 18)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(info)
	seed_button = host._button("", _next_seed)
	add_child(seed_button)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(8 * ui_scale))
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(row)
	for i in range(3):
		var b = host._button("", _tap_bed.bind(i))
		b.custom_minimum_size = Vector2(0, 160) * ui_scale
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", int(17 * ui_scale))
		b.draw.connect(_draw_bed.bind(b, i))
		row.add_child(b)
		beds.append(b)
	add_child(host._button("一键浇水 · 三块菜畦", water_all))
	fruit_button = host._button("", _fruit_action)
	add_child(fruit_button)
	add_child(host._button("看看另一棵果树", func():
		fruit_index = (fruit_index + 1) % 3
		_refresh()))
	var basket = host._label("", 17)
	basket.name = "Basket"
	basket.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(basket)
	_refresh()

func _now() -> float:
	return now_override if now_override >= 0 else Time.get_unix_time_from_system()

func _next_seed() -> void:
	seed_index = (seed_index + 1) % 3
	_refresh()

func _tap_bed(index: int) -> void:
	var bed: Dictionary = state.beds[index]
	if bed.is_empty():
		plant(index, Data.CROPS[season][seed_index])
	elif not bed.get("watered", false):
		_water(index)
	elif _now() >= float(bed.ready_at):
		harvest(index)
	else:
		info.text = "这畦还需 %d 秒。可以先去听唱片，回来再收。" % ceili(float(bed.ready_at) - _now())

func plant(index: int, crop: String) -> void:
	if not state.beds[index].is_empty() or crop not in Data.CROPS[season]: return
	state.beds[index] = {"crop":crop, "planted_at":_now(), "watered":false, "ready_at":0.0}
	info.text = "种下%s了。点这块菜畦或一键浇水，才开始生长。" % crop
	_changed("plant")

func _water(index: int) -> bool:
	var bed: Dictionary = state.beds[index]
	if bed.is_empty() or bed.get("watered", false): return false
	bed.watered = true
	bed.ready_at = _now() + GROW_SECONDS
	info.text = "浇好了！真实60秒后可以采收，关闭面板也会继续生长。"
	_changed("water")
	return true

func water_all() -> void:
	var count := 0
	for i in range(3):
		if _water(i): count += 1
	if count == 0: info.text = "菜畦不缺水。空畦先种下当季种子，正在长的苗不用重复浇。"

func harvest(index: int) -> void:
	var bed: Dictionary = state.beds[index]
	if bed.is_empty() or not bed.get("watered", false) or _now() < float(bed.ready_at): return
	var crop: String = bed.crop
	state.basket[crop] = int(state.basket.get(crop, 0)) + 1
	state.harvest_total = int(state.harvest_total) + 1
	state.beds[index] = {}
	info.text = "采到一份%s，收进生活菜篮。空菜畦可以继续种。" % crop
	_changed("harvest")

func _fruit_action() -> void:
	var fruit: String = Data.FRUITS[season][fruit_index]
	var key := "%d:%s" % [season, fruit]
	if fruit.ends_with("花") or fruit == "冬芽":
		var day := int(_now() / 86400)
		if int(state.observed.get(key, -1)) == day:
			info.text = "今天已看过%s。花与冬芽先留在枝上，慢慢欣赏。" % fruit
			return
		state.observed[key] = day
		info.text = "仔细看了%s，把今天的小发现留在生活册。" % fruit
		_changed("observe")
		return
	var next := float(state.fruit_next.get(key, 0.0))
	if _now() < next:
		info.text = "这棵%s还在恢复，%d秒后再摘。" % [fruit, ceili(next - _now())]
		return
	state.fruit_next[key] = _now() + GROW_SECONDS
	state.basket[fruit] = int(state.basket.get(fruit, 0)) + 1
	state.harvest_total = int(state.harvest_total) + 1
	info.text = "摘到一份%s。给果树60秒歇息，其他果树也可以看看。" % fruit
	_changed("fruit")

func _changed(event: String) -> void:
	state.last_event = event
	state.revision = int(state.revision) + 1
	_refresh()
	state_changed.emit()

func _refresh() -> void:
	seed_button.text = "选种子：%s  ·  点空畦种下" % Data.CROPS[season][seed_index]
	for i in range(beds.size()):
		var bed: Dictionary = state.beds[i]
		if bed.is_empty():
			beds[i].text = "\n\n\n空菜畦\n点一下种下"
		elif not bed.get("watered", false):
			beds[i].text = "\n\n\n%s\n点一下浇水" % bed.crop
		elif _now() >= float(bed.ready_at):
			beds[i].text = "\n\n\n%s\n成熟 · 点采收" % bed.crop
		else:
			beds[i].text = "\n\n\n%s\n还需%d秒" % [bed.crop, ceili(float(bed.ready_at) - _now())]
		beds[i].queue_redraw()
	var fruit: String = Data.FRUITS[season][fruit_index]
	fruit_button.text = ("观赏：" if fruit.ends_with("花") or fruit == "冬芽" else "采果：") + fruit
	var entries: Array[String] = []
	for crop in state.basket: entries.append("%s ×%d" % [crop, int(state.basket[crop])])
	get_node("Basket").text = "生活菜篮：" + ("还空着，第一份收成正在等你。" if entries.is_empty() else "、".join(entries))

func _process(_delta: float) -> void:
	if host == null: return
	var tick := int(_now())
	if tick != last_tick:
		last_tick = tick
		_refresh()

func _draw_bed(b: Button, index: int) -> void:
	var center := Vector2(b.size.x * 0.5, b.size.y * 0.3)
	var unit := ui_scale
	b.draw_rect(Rect2(center - Vector2(40, 13) * unit, Vector2(80, 26) * unit), Color("ad7b4f"))
	for j in range(4):
		b.draw_line(center + Vector2(-34 + j * 18, -10) * unit, center + Vector2(-28 + j * 18, 10) * unit, Color("ca9866"), 2 * unit)
	var bed: Dictionary = state.beds[index]
	if bed.is_empty(): return
	var grown: bool = bed.get("watered", false) and _now() >= float(bed.get("ready_at", 0))
	var height := 40.0 if grown else (23.0 if bed.get("watered", false) else 10.0)
	b.draw_line(center, center - Vector2(0, height) * unit, Color("577c48"), 4 * unit)
	for side in [-1, 1]:
		b.draw_circle(center + Vector2(side * 9, -height * 0.6) * unit, 8 * unit, Color("779454"))
	if not grown: return
	var crop: String = bed.crop
	if crop in ["南瓜", "番茄", "甜椒", "草莓"]:
		b.draw_circle(center - Vector2(0, height) * unit, 12 * unit, Color("d18d43") if crop == "南瓜" else Color("c86d52"))
		if crop == "南瓜": b.draw_line(center - Vector2(0, height + 9) * unit, center - Vector2(0, height + 15) * unit, Color("5b774b"), 3 * unit)
	elif crop == "萝卜":
		b.draw_colored_polygon(PackedVector2Array([center + Vector2(-10, -5) * unit, center + Vector2(10, -5) * unit, center + Vector2(0, 17) * unit]), Color("f0d9b8"))
	elif crop in ["豌豆", "黄瓜", "蒜苗"]:
		for offset in [-8, 0, 8]:
			b.draw_line(center + Vector2(offset, -15) * unit, center + Vector2(offset + 3, -height - 6) * unit, Color("6a934e"), 5 * unit)
	else:
		for angle in range(5):
			b.draw_circle(center - Vector2(0, height * 0.7) * unit + Vector2.from_angle(angle * TAU / 5) * 10 * unit, 10 * unit, Color("8faa64"))
