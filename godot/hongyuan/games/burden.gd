extends RefCounted
## 六个压力气泡逐一消去，无计时失败；标签只引用原稿。
const AYU := Vector2(180, 398)
const CENTER := Vector2(180, 332)
const TARGET := Rect2(136, 266, 88, 146)
const PRESSURE := [Vector2(75, 204), Vector2(285, 204), Vector2(57, 314),
	Vector2(303, 314), Vector2(85, 434), Vector2(275, 434)]
const CARE := [Vector2(76, 556), Vector2(180, 556), Vector2(284, 556)]
var r
var phase := "helping" # helping → relaxed → done
var t := 0.0
var idle_t := 0.0
var pressure_labels: Array[String] = []
var care_labels: Array[String] = []
var positions: Array = []
var removed: Array = [false, false, false, false, false, false]
var pop_t: Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var hearts: Array = []
var care_count := 0
var dragging := false
var drag_index := -1
var drag_to := Vector2.ZERO

func start(runner, beat: Dictionary) -> void:
	r = runner
	var groups: Dictionary = {}
	for id: String in beat.get("pressure", ["A3-L1", "A3-L2", "A3-L4"]):
		groups[id] = r.t_(id).split("／", false)
	# The six choices and their order are specified in C3; no authored labels.
	for pair in [["A3-L2", 0], ["A3-L2", 1], ["A3-L2", 2], ["A3-L4", 1], ["A3-L1", 0], ["A3-L1", 1]]:
		pressure_labels.append(str(groups[pair[0]][pair[1]]).strip_edges())
	for label: String in r.t_(str(beat.get("care", "A3-L3"))).split("／", false):
		care_labels.append(label.strip_edges())
	positions.assign(PRESSURE)

func process(dt: float) -> bool:
	var previous_second := int(t)
	t += dt
	idle_t += dt
	for i in range(pop_t.size()):
		pop_t[i] = maxf(0.0, float(pop_t[i]) - dt)
	for heart: Dictionary in hearts:
		heart.age = minf(1.0, float(heart.age) + dt)
	if phase == "helping":
		if int(t) > previous_second:
			for i in range(positions.size()):
				if removed[i]: continue
				var at: Vector2 = positions[i]
				# Keep six circles separated and off Ayu; they never damage her.
				if at.distance_to(CENTER) > 99:
					positions[i] = at.move_toward(CENTER, minf(3, at.distance_to(CENTER) - 99))
		if care_count == 6 and float(pop_t.max()) <= 0:
			phase = "relaxed"
			t = 0.0
			dragging = false
	elif phase == "relaxed" and t >= 1.0:
		phase = "done"
	return phase == "done"

func _nearest() -> int:
	var best := -1
	for i in range(positions.size()):
		if removed[i]: continue
		if best < 0 or positions[i].distance_squared_to(CENTER) < positions[best].distance_squared_to(CENTER): best = i
	return best

func _drop_target(pos: Vector2) -> int:
	if TARGET.has_point(pos): return _nearest()
	var best := -1
	for i in range(positions.size()):
		if removed[i] or pos.distance_to(positions[i]) > 42: continue
		if best < 0 or pos.distance_squared_to(positions[i]) < pos.distance_squared_to(positions[best]): best = i
	return best

func input(kind: String, pos: Vector2) -> void:
	if phase != "helping": return
	if kind == "down":
		dragging = false
		idle_t = 0.0
		for i in range(mini(CARE.size(), care_labels.size())):
			if pos.distance_to(CARE[i]) <= 42:
				dragging = true
				drag_index = i
				drag_to = pos
				break
	elif kind == "move" and dragging:
		drag_to = pos.clamp(Vector2.ZERO, Vector2(360, 640))
		idle_t = 0.0
	elif kind == "up" and dragging:
		dragging = false
		idle_t = 0.0
		var index := _drop_target(pos)
		if index < 0: return
		removed[index] = true
		pop_t[index] = 0.4
		care_count += 1
		hearts.append({"from": pos, "age": 0.0})
		r.play("pop")

func _bubble(ci, at: Vector2, label: String, warm: bool, scale_k := 1.0) -> void:
	var fill := Color("#f1c981") if warm else Color("#8b9daf")
	var edge: Color = ci.GOLD if warm else Color("#4b6074")
	ci.draw_circle(at, 40 * scale_k, edge)
	ci.draw_circle(at, 37 * scale_k, fill)
	if scale_k < 0.85: return
	var text := label
	if ci.FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x > 70:
		text = label.substr(0, 3) + "\n" + label.substr(3)
	ci.text_at(at + Vector2(-36, -2 if "\n" in text else 5), text, 14, ci.INK, 72)

func _heart(ci, at: Vector2) -> void:
	ci.draw_circle(at + Vector2(-3, -2), 4, ci.GOLD)
	ci.draw_circle(at + Vector2(3, -2), 4, ci.GOLD)
	ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-7, -1), at + Vector2(7, -1), at + Vector2(0, 8)]), ci.GOLD)

func draw(ci) -> void:
	var progress := care_count / 6.0
	ci.draw_rect(Rect2(0, 0, 360, 640), Color("#303340").lerp(Color("#665143"), progress))
	ci.text_at(Vector2(24, 82), ci.t_("A3-P1"), 16, ci.PAPER, 312)
	# A small desk separates the seated subject from the bubble tray. A3 replaces the fallback.
	ci.draw_rect(Rect2(128, 366, 104, 10), ci.WOOD)
	ci.draw_rect(Rect2(136, 376, 5, 36), ci.WOOD)
	ci.draw_rect(Rect2(219, 376, 5, 36), ci.WOOD)
	ci.sprite("w2/common/ayu_relaxed.png|ayu_idle.png" if phase == "relaxed" else "w2/common/ayu_tired.png|ayu_idle.png", AYU)
	for i in range(PRESSURE.size()):
		if removed[i] and float(pop_t[i]) <= 0: continue
		var scale_k := clampf(float(pop_t[i]) / 0.4, 0, 1) if removed[i] else 1.0
		_bubble(ci, positions[i], pressure_labels[i], false, scale_k)
	for i in range(hearts.size()):
		var heart: Dictionary = hearts[i]
		var destination := CENTER + Vector2(cos(i * TAU / 6), sin(i * TAU / 6)) * 53
		_heart(ci, heart.from.lerp(destination, 1 - pow(1 - float(heart.age), 2)))
	ci.draw_rect(Rect2(20, 506, 320, 104), Color(ci.INK, 0.6))
	ci.draw_rect(Rect2(20, 506, 320, 104), ci.GOLD, false, 2)
	for i in range(mini(CARE.size(), care_labels.size())):
		# The source remains full even while a copy is being dragged.
		_bubble(ci, CARE[i], care_labels[i], true)
	if dragging and drag_index >= 0 and drag_index < care_labels.size():
		_bubble(ci, drag_to, care_labels[drag_index], true)
	elif phase == "helping" and idle_t >= 8.0:
		var nearest := _nearest()
		if nearest >= 0:
			var end: Vector2 = positions[nearest]
			var direction := (end - CARE[1]).normalized()
			var normal := Vector2(-direction.y, direction.x)
			ci.draw_line(CARE[1], end, ci.GOLD, 2)
			ci.draw_line(end, end - direction * 12 + normal * 6, ci.GOLD, 2)
			ci.draw_line(end, end - direction * 12 - normal * 6, ci.GOLD, 2)
