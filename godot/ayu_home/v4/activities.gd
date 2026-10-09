extends CanvasLayer
const UI=preload("res://ayu_home/v4/pixel_ui.gd")
const Art = preload("res://ayu_home/asset_store.gd")
signal closed
signal completed(kind: String)

var kind := ""
var context: Dictionary = {}
var root: Control
var content: VBoxContainer
var status: Label
var board: GridContainer
var tiles: Array[Button] = []
var order: Array[int] = []
var selected := -1
var finished := false
var elapsed := 0.0
var clock_running := false
var sound_on := true
var gentle := true
var guitar_step := 0
var note_buttons: Array[Button] = []
var melody := [0, 2, 1, 3, 2, 0, 1, 2, 3, 1, 0, 2]
var player: AudioStreamPlayer
var artwork: Texture2D
var album_slots: Array[Button] = []
var album_tray: Array[Button] = []
var album_found: Array[int] = []
var album_piece := -1
var fish_food: Array[Vector2] = []
var fun_canvas: Control
var fun_count := 0
var font: Font
var album_preview: TextureRect
var ui_scale := 1.0
var note_cache: Dictionary = {}
var garden_panel: Control
var guitar_canvas: Control
var guitar_art:Texture2D

func _ready() -> void:
	layer = 30
	var path := "res://assets/fonts/fusion-pixel-12px-proportional-zh_hans.otf.woff2"
	if ResourceLoader.exists(path):
		font = load(path)
	player = AudioStreamPlayer.new()
	add_child(player)
	set_process(false)

func open(which: String, data: Dictionary = {}) -> void:
	if not await preload("res://ayu_home/v4/core/download_gate.gd").ensure(self,"activity:"+which):return
	_dispose()
	ui_scale = maxf(1.0, get_viewport().get_visible_rect().size.x / 540.0)
	kind = which
	context = data
	finished = false
	selected = -1
	elapsed = 0
	guitar_step = 0
	fun_count = 0
	album_piece = -1
	album_found.clear()
	fish_food.clear()
	set_process(true)
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	root.theme=UI.theme(true)
	var shade := ColorRect.new()
	shade.color = Color(0.12, 0.09, 0.06, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var outer := MarginContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		outer.add_theme_constant_override("margin_" + side, int(12 * ui_scale))
	for side in ["top", "bottom"]:
		outer.add_theme_constant_override("margin_" + side, int(18 * ui_scale))
	root.add_child(outer)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.paper())
	panel.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	outer.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, int(18 * ui_scale))
	panel.add_child(margin)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", int(12 * ui_scale))
	if font != null:
		content.add_theme_font_override("font", font)
	margin.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	var title := _label({"guitar": "窗边的小旋律", "puzzle": "书架 · 九格花园", "album": "相册 · 修复院子写生", "relax": "好好歇一会儿", "fish": "鱼缸里的小伙伴", "tv": "今晚看什么", "record": "一张原创唱片", "workbench": "木作小工坊", "garden": "院子的小花园"}.get(kind, "闲居时光"), 26)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(title)
	var exit := _button("收起", close) # 关闭按钮统一叫「收起」
	exit.custom_minimum_size = Vector2(76, 48) * ui_scale
	header.add_child(exit)
	status = _label("", 20)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(status)
	if kind == "guitar":
		_build_guitar()
	elif kind == "puzzle":
		_build_puzzle()
	elif kind == "album":
		_build_album()
	elif kind == "garden":
		_build_garden()
	else:
		_build_fun()

func close() -> void:
	_dispose()
	closed.emit()

func _dispose() -> void:
	clock_running = false
	set_process(false)
	if player != null:
		player.stop()
		player.stream = null
	if root != null:
		remove_child(root)
		root.queue_free()
		root = null
	tiles.clear()
	note_buttons.clear()
	album_slots.clear()
	album_tray.clear()
	guitar_canvas = null
	fun_canvas = null
	album_preview = null
	garden_panel = null

func _style(color: Color, _radius: int = 12) -> StyleBoxTexture:
	return UI.box(color)

func _label(text: String, size: int = 20) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color("59412e"))
	l.add_theme_font_size_override("font_size", UI.fs(size))   # 村-7：只用 24 / 36 / 48
	if font != null:
		l.add_theme_font_override("font", font)
	return l

func _button(text: String, call: Callable) -> Button:
	var b := Button.new()
	b.text = text
	_decorate_button(b)
	b.pressed.connect(call)
	return b

func _decorate_button(b: Button) -> void:
	b.custom_minimum_size = Vector2(0, 52) * ui_scale
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 村-4：次按钮（深褐底、金棕双线、米白字 24），跟阿鱼家别处一样
	for st in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(st, UI.secondary_box())
	b.add_theme_stylebox_override("pressed", UI.secondary_box(true))
	b.add_theme_color_override("font_color", Color(UI.DS.PAL.text))
	b.add_theme_font_size_override("font_size", 24)
	if font != null:
		b.add_theme_font_override("font", font)

func _finish(message: String) -> void:
	status.text = message
	if not finished:
		finished = true
		clock_running = false
		completed.emit(kind)

func _art() -> Texture2D:
	if context.get("v2_art",false):
		return preload("res://ayu_home/v2/assets.gd").texture("res://ayu_home/v3/assets/approved-0.png")
	var month := int(context.get("month", Time.get_datetime_dict_from_system().month))
	var season := int((month + 9) % 12 / 3)
	var art := Art.texture(["garden_spring.png", "garden_summer.png", "garden.png", "garden_winter.png"][season])
	if art != null:
		return art
	# Original geometric garden picture; available offline even before art import.
	var im := Image.create(300, 300, false, Image.FORMAT_RGBA8)
	im.fill(Color("dfe6b4"))
	for y in range(300):
		for x in range(300):
			if y < 110:
				im.set_pixel(x, y, Color("aed8d2"))
			if x > 80 and x < 218 and y > 95 and y < 225:
				im.set_pixel(x, y, Color("e9c28d"))
			if abs(x - 150) + abs(y - 75) < 80:
				im.set_pixel(x, y, Color("b47654"))
			if x > 130 and x < 169 and y > 165 and y < 225:
				im.set_pixel(x, y, Color("80583a"))
			if Vector2(x - 43, y - 192).length() < 33 or Vector2(x - 256, y - 177).length() < 36:
				im.set_pixel(x, y, Color("668d61"))
	return ImageTexture.create_from_image(im)

func _slice(n: int) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = artwork
	var dim := artwork.get_size() / 3.0
	a.region = Rect2(Vector2(n % 3, n / 3) * dim, dim)
	return a

func _build_puzzle() -> void:
	status.text = "点两块交换，拼回院子。每一块都可以自由交换。"
	artwork = _art()
	board = GridContainer.new()
	board.columns = 3
	board.custom_minimum_size.y=420*ui_scale
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(board)
	for i in range(9):
		var b := _button("", _pick_tile.bind(i))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL
		b.expand_icon = true
		board.add_child(b)
		tiles.append(b)
	_shuffle()
	content.add_child(_button("提示 · 标出下一对", _hint))
	content.add_child(_button("重新打乱", _shuffle))

func _shuffle() -> void:
	order.assign(range(9))
	for i in range(24):
		var a := randi_range(0, 8)
		var b := randi_range(0, 8)
		var tmp := order[a]
		order[a] = order[b]
		order[b] = tmp
	if order == [0, 1, 2, 3, 4, 5, 6, 7, 8]:
		order[0] = 1
		order[1] = 0
	selected = -1
	_refresh_tiles()
	if status != null:
		status.text = "点两块交换，拼回院子。"

func _refresh_tiles() -> void:
	for i in range(9):
		tiles[i].icon = _slice(order[i])
		tiles[i].modulate = Color("e8c68b") if selected == i else Color.WHITE

func _pick_tile(i: int) -> void:
	if selected < 0:
		selected = i
	elif selected == i:
		selected = -1
	else:
		var tmp := order[selected]
		order[selected] = order[i]
		order[i] = tmp
		selected = -1
	_refresh_tiles()
	if order == [0, 1, 2, 3, 4, 5, 6, 7, 8]:
		_finish("拼好了！院子又完整了，已记入生活册。")

func _hint() -> void:
	for i in range(9):
		if order[i] != i:
			selected = i
			_refresh_tiles()
			var other := order.find(i)
			tiles[other].modulate = Color("bed39f")
			status.text = "把金色格和绿色格交换。"
			return

func _build_album() -> void:
	status.text = "院子写生少了三片。先点下方碎片，再点空缺；也可以拖过去。"
	artwork = _art()
	var grid := GridContainer.new()
	grid.columns = 3
	grid.custom_minimum_size.y=360*ui_scale
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(grid)
	for i in range(9):
		var slot := AlbumSlot.new()
		_decorate_button(slot)
		slot.owner_activity = self
		slot.index = i
		slot.custom_minimum_size = Vector2(0, 80) * ui_scale
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
		slot.expand_icon = true
		slot.pressed.connect(_place_album.bind(i))
		if i not in [1, 4, 7]:
			slot.icon = _slice(i)
		else:
			slot.text = "缺片"
		grid.add_child(slot)
		album_slots.append(slot)
	var tray := HBoxContainer.new()
	content.add_child(tray)
	for i in [7, 1, 4]:
		var piece := AlbumPiece.new()
		_decorate_button(piece)
		piece.owner_activity = self
		piece.index = i
		piece.icon = _slice(i)
		piece.expand_icon = true
		piece.custom_minimum_size = Vector2(90, 90) * ui_scale
		piece.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		piece.pressed.connect(_select_album.bind(i))
		tray.add_child(piece)
		album_tray.append(piece)
	content.add_child(_button("提示 · 看完整写生", func():
		if is_instance_valid(album_preview):
			album_preview.queue_free()
		var preview := TextureRect.new()
		album_preview = preview
		preview.texture = artwork
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.custom_minimum_size = Vector2(0, 130) * ui_scale
		content.add_child(preview)
		get_tree().create_timer(3).timeout.connect(func():
			if is_instance_valid(preview): preview.queue_free())))

func _select_album(i: int) -> void:
	album_piece = i
	status.text = "已选碎片，点对应空缺。"
	for piece in album_tray:
		piece.modulate = Color("e8c68b") if piece.index == i else Color.WHITE

func _place_album(i: int) -> void:
	if i not in [1, 4, 7] or i in album_found:
		return
	if album_piece != i:
		status.text = "这一片边缘还接不上，再看看树和屋顶。"
		return
	album_found.append(i)
	for piece in album_tray:
		if piece.index == i:
			piece.disabled = true
			piece.modulate = Color(1, 1, 1, 0.35)
	album_slots[i].icon = _slice(i)
	album_slots[i].text = ""
	album_piece = -1
	status.text = "接好了 %d / 3 片。" % album_found.size()
	if album_found.size() == 3:
		_finish("这一页院子写生修复好了，已记入生活册。")

class AlbumSlot extends Button:
	var owner_activity
	var index: int
	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.has("album_piece") and index in [1, 4, 7]
	func _drop_data(_at: Vector2, data: Variant) -> void:
		owner_activity.album_piece = int(data.album_piece)
		owner_activity._place_album(index)

class AlbumPiece extends Button:
	var owner_activity
	var index: int
	func _get_drag_data(_at: Vector2) -> Variant:
		var preview := TextureRect.new()
		preview.texture = icon
		preview.custom_minimum_size = Vector2(90, 90) * owner_activity.ui_scale
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		set_drag_preview(preview)
		return {"album_piece": index}

func _build_guitar() -> void:
	guitar_art=preload("res://ayu_home/v2/assets.gd").texture("res://ayu_home/v4/assets/guitar-corner.png")
	status.text = "跟着亮起的琴弦，弹一段原创小曲。宽容模式可以慢慢弹。"
	var sound := _button("声音：开", func():
		sound_on = not sound_on
		if not sound_on: player.stop())
	sound.pressed.connect(func(): sound.text = "声音：开" if sound_on else "声音：关")
	var settings:=HBoxContainer.new();content.add_child(settings);sound.size_flags_horizontal=Control.SIZE_EXPAND_FILL;settings.add_child(sound)
	var mode := _button("宽容模式：开", func(): gentle = not gentle)
	mode.pressed.connect(func(): mode.text = "宽容模式：开" if gentle else "节拍模式：开")
	mode.size_flags_horizontal=Control.SIZE_EXPAND_FILL;settings.add_child(mode)
	guitar_canvas = Control.new()
	guitar_canvas.custom_minimum_size = Vector2(0,310)*ui_scale
	guitar_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	guitar_canvas.draw.connect(_draw_guitar)
	content.add_child(guitar_canvas)
	var strings := HBoxContainer.new()
	strings.add_theme_constant_override("separation",int(8*ui_scale))
	content.add_child(strings)
	for i in range(4):
		var b := _button(["哆", "咪", "索", "啦"][i], _strum.bind(i))
		b.custom_minimum_size.y = 62*ui_scale
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		strings.add_child(b)
		note_buttons.append(b)
	content.add_child(_button("从头弹", func():
		guitar_step = 0
		elapsed = 0
		clock_running = true
		_refresh_notes()))
	clock_running = true
	_refresh_notes()

func _refresh_notes() -> void:
	for i in range(note_buttons.size()):
		note_buttons[i].modulate = Color("a7cf8d") if guitar_step < melody.size() and i == melody[guitar_step] else Color.WHITE

func _strum(i: int) -> void:
	_play_note(i)
	if guitar_step >= melody.size():
		return
	if i != melody[guitar_step]:
		status.text = "听听这个音，再试亮着的弦。"
		return
	if not gentle and fmod(elapsed, 1.2) > 0.75:
		status.text = "下一拍再弹，灯会轻轻闪。"
		return
	guitar_step += 1
	elapsed = 0
	status.text = "小旋律 %d / %d" % [guitar_step, melody.size()]
	_refresh_notes()
	if guitar_step == melody.size():
		_finish("一曲完成！这段窗边旋律已记入生活册。")

func _play_note(i: int) -> void:
	if not sound_on or player == null:
		return
	player.stop()
	if note_cache.has(i):
		player.stream = note_cache[i]
		player.play()
		return
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var bytes := PackedByteArray()
	bytes.resize(13230)
	var hz: float = [261.63, 329.63, 392.0, 440.0][i % 4]
	for sample in range(6615):
		var t := float(sample) / 22050.0
		var envelope := exp(-t * 12.0) * minf(t * 140.0, 1.0)
		var value := int((sin(TAU * hz * t) + 0.28 * sin(TAU * hz * 2 * t)) * envelope * 11000)
		bytes.encode_s16(sample * 2, value)
	wav.data = bytes
	note_cache[i] = wav
	player.stream = wav
	player.play()

func _build_garden() -> void:
	status.text = "种菜与摘果只记入家的生活册。真实等待生长，不改变家里的时间。"
	var Garden = load("res://ayu_home/garden_panel.gd")
	var garden = Garden.new()
	garden_panel = garden
	content.add_child(garden)
	garden.size_flags_vertical = Control.SIZE_EXPAND_FILL
	garden.configure(context, self)
	garden.state_changed.connect(func(): completed.emit("garden"))

func _build_fun() -> void:
	status.text = {"relax": "躺下来听听屋子。不会推进现实时间；关闭后起身。", "fish": "点鱼缸投一小撮鱼粮，看鱼儿游过来。", "tv": "点按钮换一个原创小节目。", "record": "转动唱片，听一段原创旋律。", "workbench": "按下磨一磨，让小木鸟成形。"}.get(kind, "享受一会儿闲居时光。")
	fun_canvas = Control.new()
	fun_canvas.custom_minimum_size = Vector2(0, 240) * ui_scale
	fun_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fun_canvas.draw.connect(_draw_fun)
	fun_canvas.gui_input.connect(func(event):
		if kind == "fish" and event is InputEventMouseButton and event.pressed:
			fish_food.append(event.position)
			_fun_action())
	content.add_child(fun_canvas)
	content.add_child(_button({"relax": "深呼吸", "fish": "投一小撮鱼粮", "tv": "换个节目", "record": "播放 / 再听一遍", "workbench": "磨一磨木鸟"}.get(kind, "试一试"), _fun_action))
	if kind in ["record", "tv"]:
		var sound := _button("声音：开", func():
			sound_on = not sound_on
			if not sound_on: player.stop())
		sound.pressed.connect(func(): sound.text = "声音：开" if sound_on else "声音：关")
		content.add_child(sound)

func _fun_action() -> void:
	fun_count += 1
	if kind in ["record", "tv"]:
		clock_running = true
		elapsed = 0
		_play_note(fun_count % 4)
	if kind == "fish" and fish_food.is_empty():
		fish_food.append(fun_canvas.size * Vector2(0.5, 0.3))
	var goal := 4 if kind in ["workbench", "relax"] else 1
	if fun_count >= goal:
		_finish({"relax": "呼吸慢下来，歇好了就关闭起身。", "fish": "鱼儿吃到了，感谢你的照顾。", "tv": "节目：%s" % ["小镇天气", "庭院观察", "猫咪日记"][fun_count % 3], "record": "唱片正在转，关闭会停止声音。", "workbench": "小木鸟做好了！已记入生活册。"}.get(kind, "完成了。"))
		if kind == "record": clock_running = true
	else:
		status.text = "慢慢来 · %d / %d" % [fun_count, goal]

func _unhandled_input(event:InputEvent) -> void:
	if root and event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:close();get_viewport().set_input_as_handled()
func _process(delta: float) -> void:
	elapsed += delta
	if is_instance_valid(guitar_canvas): guitar_canvas.queue_redraw()
	if fun_canvas != null:
		fun_canvas.queue_redraw()
	if kind == "guitar" and clock_running and guitar_step < melody.size():
		var b := note_buttons[melody[guitar_step]]
		b.modulate = Color("bcd699").lerp(Color("f5d98f"), (sin(elapsed * TAU / 1.2) + 1) * 0.5)
	if kind == "record" and clock_running and int(elapsed / 0.45) > guitar_step:
		guitar_step = int(elapsed / 0.45)
		_play_note(melody[guitar_step % melody.size()])
	if kind == "fish":
		for i in range(fish_food.size()):
			fish_food[i].y += delta * 8

func _draw_fun() -> void:
	if fun_canvas == null: return
	var size := fun_canvas.size
	var center := size * 0.5
	fun_canvas.draw_style_box(_style(Color("dfdfbe")), Rect2(Vector2.ZERO, size))
	if kind == "fish":
		fun_canvas.draw_rect(Rect2(12, 20, size.x - 24, size.y - 40), Color("a5d7d4"))
		for i in range(5):
			var p := Vector2(35 + fposmod(elapsed * (18 + i * 4) + i * 69, size.x - 70), center.y + sin(elapsed + i) * 40)
			if not fish_food.is_empty(): p = p.lerp(fish_food[0], 0.45)
			fun_canvas.draw_circle(p, 9, Color("dc9f56"))
			fun_canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(-8, 0), p + Vector2(-18, -7), p + Vector2(-18, 7)]), Color("c97c43"))
		for p in fish_food:
			fun_canvas.draw_circle(p, 2, Color("91653f"))
	elif kind == "record":
		fun_canvas.draw_circle(center, 85, Color("3f433e"))
		for radius in [40, 55, 70]: fun_canvas.draw_arc(center, radius, 0, TAU, 60, Color("6d715d"), 1)
		fun_canvas.draw_circle(center, 24, Color("c58d55"))
		fun_canvas.draw_line(center, center + Vector2.from_angle(elapsed * 2) * 65, Color("d1bb86"), 2)
		fun_canvas.draw_line(center + Vector2(95, -90), center + Vector2(45, 0), Color("927653"), 7)
	elif kind == "workbench":
		fun_canvas.draw_rect(Rect2(20, center.y + 38, size.x - 40, 24), Color("a1784d"))
		fun_canvas.draw_circle(center, 30, Color("cda26b"))
		fun_canvas.draw_circle(center + Vector2(24, -20), 18, Color("cda26b"))
		fun_canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(37, -25), center + Vector2(53, -17), center + Vector2(37, -12)]), Color("a67d43"))
		if fun_count >= 4: fun_canvas.draw_circle(center + Vector2(29, -23), 3, Color("493c2a"))
		for i in range(mini(fun_count * 4, 20)): fun_canvas.draw_line(center + Vector2(i * 5 - 50, 52), center + Vector2(i * 5 - 46, 56), Color("e9cea4"), 2)
	elif kind == "tv":
		fun_canvas.draw_rect(Rect2(25, 25, size.x - 50, size.y - 50), Color("6d765a"))
		var p := center + Vector2(sin(elapsed) * 70, 0)
		fun_canvas.draw_circle(p, 30, [Color("d9ba77"), Color("88b6b0"), Color("c6926e")][fun_count % 3])
		fun_canvas.draw_circle(p + Vector2(-10, -5), 3, Color("453c2d"))
		fun_canvas.draw_circle(p + Vector2(10, -5), 3, Color("453c2d"))
	else:
		var radius := 50 + sin(elapsed * 1.4) * 18
		fun_canvas.draw_circle(center, radius, Color("bed0a0"))
		fun_canvas.draw_circle(center, radius * 0.7, Color("f2dfb3"))
		fun_canvas.draw_arc(center, radius + 20, 0, TAU, 60, Color("b1be92"), 2)

func _draw_guitar() -> void:
	if not is_instance_valid(guitar_canvas):return
	var size:=guitar_canvas.size;guitar_canvas.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	guitar_canvas.draw_texture_rect(guitar_art,Rect2(Vector2.ZERO,size),false)
	# Four original melody cues ride over the coarse-pixel instrument scene.
	if not finished and guitar_step<melody.size():
		var i:int=melody[guitar_step];var at:=Vector2(size.x*(.483+(i-1.5)*.012),size.y*(.18+minf(1,elapsed/1.2)*.52)).round()
		guitar_canvas.draw_rect(Rect2(at-Vector2(8,8),Vector2(16,16)),Color("4d5936"))
		guitar_canvas.draw_rect(Rect2(at-Vector2(6,6),Vector2(12,12)),Color("fff1be"))
		guitar_canvas.draw_rect(Rect2(at-Vector2(3,3),Vector2(6,6)),Color("8ead64"))
		guitar_canvas.draw_rect(Rect2(at+Vector2(5,-19),Vector2(3,14)),Color("fff1be"))
