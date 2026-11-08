extends RefCounted
## 俯视竖向卷轴驾驶：左右滑动换道躲车，撞到只减速；最后按住减速、松手停进东方明珠旁的空车位。
## 图（有就用，没有画占位）：w2/shanghai/drive_tile.png（360 宽可竖向平铺的路面）、
## w2/shanghai/g42_top.png、w2/shanghai/traffic_top_1..3.png、w2/shanghai/pearl_top.png

const LANES := [120.0, 180.0, 240.0]
const CAR_Y := 500.0
const LENGTH := 5200.0
const CRUISE := 230.0
const PURPLE := Color("#6b3fa0")

var r
var phase := "drive"   # (ready →) drive → park → in → done；任务卡已经确认过一次，不再要「出发」第二次确认
var t := 0.0
var lane := 1
var car_x := 180.0
var scroll := 0.0
var speed := 0.0
var bump := 0.0
var traffic: Array = []
var spawn_at := 420.0
var rng := RandomNumberGenerator.new()
var holding := false
var bay_y := -9999.0
var park_t := 0.0
var misses := 0
var miss_note_t := 0.0
var swipe_from := Vector2.ZERO
var swiping := false
var hint_t := 0.0
var tapped := false


func start(runner, _beat: Dictionary) -> void:
	r = runner
	rng.seed = Time.get_ticks_usec()


func process(dt: float) -> bool:
	t += dt
	hint_t += dt
	car_x = move_toward(car_x, LANES[lane], 300.0 * dt)
	bump = maxf(0.0, bump - dt)
	miss_note_t = maxf(0.0, miss_note_t - dt)
	match phase:
		"drive":
			var want := CRUISE * (0.45 if bump > 0.0 else 1.0)
			speed = move_toward(speed, want, 260.0 * dt)
			scroll += speed * dt
			_traffic(dt)
			if scroll >= LENGTH:
				phase = "park"
				park_t = 0.0
				bay_y = -120.0
				lane = 2
				traffic.clear()
		"park":
			# 按住刹车：车位在附近就自动倒进去。点一下＝车位到了就停。
			# 保底：车位开到和车并排还没停，就自己刹车入位，不会无限循环。
			park_t += dt
			var aligned := bay_y >= CAR_Y - 10.0
			# 车位还远就按住：记下“要停”，车继续慢慢开，车位一靠近自己刹住，不会原地卡住。
			if holding:
				tapped = true
			var near := bay_y > CAR_Y - 300.0
			# 要按住才停得住：没按就开过车位，绕一圈再来。错过两次以后才自动帮忙停，免得卡死。
			var braking := (tapped and near) or (aligned and misses >= 2)
			if bay_y > CAR_Y + 150.0 and not tapped:
				misses += 1
				bay_y = -260.0
				hint_t = 0.0
				miss_note_t = 2.4
				r.play("blip")
			var want2 := 0.0 if braking else (90.0 if tapped else 150.0)
			speed = move_toward(speed, want2, (300.0 if braking else 90.0) * dt)
			if aligned and braking:
				bay_y = minf(bay_y, CAR_Y + 30.0)
			scroll += speed * dt
			bay_y += speed * dt
			if speed < 8.0 and bay_y > CAR_Y - 320.0:
				phase = "in"
				park_t = 0.0
				speed = 0.0
				lane = 2
				r.play("pop")
		"in":
			park_t += dt
			if park_t >= 1.2:
				phase = "done"
				return true
	return phase == "done"


func _traffic(dt: float) -> void:
	if scroll >= spawn_at and scroll < LENGTH - 500.0:
		spawn_at = scroll + rng.randf_range(300.0, 470.0)
		var l := rng.randi_range(0, 2)
		traffic.append({"lane": l, "y": -80.0, "v": rng.randf_range(80.0, 120.0), "kind": rng.randi_range(1, 3), "hit": false})
		if rng.randf() < 0.3:
			traffic.append({"lane": (l + rng.randi_range(1, 2)) % 3, "y": -230.0, "v": 100.0, "kind": rng.randi_range(1, 3), "hit": false})
	for c: Dictionary in traffic:
		c.y += (speed - float(c.v)) * dt
		if not c.hit and absf(float(c.y) - CAR_Y) < 54.0 and absf(LANES[int(c.lane)] - car_x) < 36.0:
			c.hit = true
			bump = 0.9
			speed *= 0.5
			r.play("blip")
	traffic = traffic.filter(func(c: Dictionary) -> bool: return float(c.y) < 760.0)


func input(kind: String, pos: Vector2) -> void:
	match phase:
		"ready":
			if kind == "tap" and _go_rect().grow(10).has_point(pos):
				phase = "drive"
				hint_t = 0.0
				r.play("blip")
		"drive", "park":
			if phase == "park" and kind == "tap":
				tapped = true
			if kind == "down":
				swipe_from = pos
				swiping = true
				if phase == "park":
					holding = true
			elif kind == "move" and swiping and absf(pos.x - swipe_from.x) > 26.0:
				if phase == "park" and pos.x > swipe_from.x:
					tapped = true
				lane = clampi(lane + (1 if pos.x > swipe_from.x else -1), 0, 2)
				swipe_from = pos
			elif kind == "up":
				swiping = false
				holding = false
			elif kind == "tap" and phase == "drive":
				lane = clampi(lane + (1 if pos.x > car_x else -1), 0, 2)


func _go_rect() -> Rect2:
	return Rect2(120, 560, 120, 44)


func draw(ci) -> void:
	_road(ci)
	if phase in ["park", "in", "done"]:
		_bay(ci)
	for c: Dictionary in traffic:
		_car(ci, Vector2(LANES[int(c.lane)], float(c.y)), "w2/shanghai/traffic_top_%d.png" % int(c.kind), [Color("#c9ccd4"), Color("#3c6fb0"), Color("#d6a456")][int(c.kind) - 1])
	var p := Vector2(car_x, CAR_Y)
	var ang := clampf((LANES[lane] - car_x) / 120.0, -0.25, 0.25)
	if phase == "in":
		var k := smoothstep(0.0, 1.0, park_t / 1.0)
		p = Vector2(lerpf(car_x, 318.0, k), lerpf(CAR_Y, bay_y, k))
		ang = sin(k * PI) * 0.45
	if bump > 0.0:
		p.x += sin(t * 60.0) * 2.0 * bump
	_car(ci, p, "w2/shanghai/g42_top.png", PURPLE, ang)
	if phase == "drive":
		_far_pearl(ci)
	_progress(ci)
	if phase == "ready":
		ci.draw_rect(ci.view_rect, Color(0, 0, 0, 0.25))
		ci.pill(_go_rect(), ci.t_("A1-B2"), 20, ci.RED, ci.PAPER)
	elif phase == "drive" and hint_t < 3.0:
		_swipe_hint(ci)
	elif phase == "park":
		_hold_hint(ci)


func _road(ci) -> void:
	var tile: Texture2D = ci.texture("round1/scenes/shanghai_drive.png|w2/shanghai/drive_tile.png")
	if tile:
		var h := tile.get_size().y * (360.0 / tile.get_size().x)
		var off := fposmod(scroll, h)
		var y: float = ci.view_rect.position.y + off - h
		while y < ci.view_rect.end.y:
			ci.draw_texture_rect(tile, Rect2(0, y, 360, h), false)
			y += h
		return
	# 占位：草地、人行道、三车道、虚线、路灯和行道树都跟着滚
	ci.draw_rect(Rect2(0, 0, 360, 640), Color("#6f8f4e"))
	ci.draw_rect(Rect2(66, 0, 228, 640), Color("#c9b48c"))
	ci.draw_rect(Rect2(86, 0, 188, 640), Color("#4a4550"))
	ci.draw_rect(Rect2(88, 0, 3, 640), Color("#e8e0cc"))
	ci.draw_rect(Rect2(269, 0, 3, 640), Color("#e8e0cc"))
	var off2 := fposmod(scroll, 64.0)
	for lx in [150.0, 210.0]:
		var y2 := off2 - 64.0
		while y2 < 640.0:
			ci.draw_rect(Rect2(lx - 1.5, y2, 3, 28), Color("#efe6d2"))
			y2 += 64.0
	var off3 := fposmod(scroll, 160.0)
	var y3 := off3 - 160.0
	while y3 < 700.0:
		for side in [-1, 1]:
			var tx: float = 180.0 + side * 140.0
			ci.draw_circle(Vector2(tx, y3), 20, Color("#3f6b3a"))
			ci.draw_circle(Vector2(tx - 5, y3 - 5), 12, Color("#5d8c4a"))
			ci.draw_rect(Rect2(180.0 + side * 100.0 - 3, y3 + 70, 6, 6), Color("#2d2a2e"))
			ci.draw_circle(Vector2(180.0 + side * 100.0, y3 + 73), 7, Color(1, 0.9, 0.6, 0.25))
		y3 += 160.0


func _bay(ci) -> void:
	var lot := Rect2(276, bay_y - 260, 84, 520)
	var lot_tex: Texture2D = ci.texture("w2/shanghai/parking_lot.png")
	if lot_tex:
		ci.draw_texture_rect(lot_tex, lot, false)
	else:
		ci.draw_rect(lot, Color("#8d8a86"))
		for i in range(6):
			var y := bay_y - 225 + i * 90
			ci.draw_rect(Rect2(278, y, 80, 3), Color("#f2ead8"))
	var slot := Rect2(282, bay_y - 42, 72, 84)
	ci.draw_rect(slot, Color(1.0, 0.85, 0.4, 0.25 + 0.15 * sin(t * 6.0)))
	ci.draw_rect(slot, Color("#f5c75a"), false, 2.0)
	# 东方明珠在停车场边（俯视：三个球）
	var pearl: Texture2D = ci.texture("w2/shanghai/pearl_top.png")
	var pc := Vector2(318, bay_y - 190)
	if pearl:
		var sz: Vector2 = pearl.get_size() * ci.S
		ci.draw_texture_rect(pearl, Rect2(pc - sz * 0.5, sz), false)
	else:
		ci.draw_circle(pc, 26, Color("#c3407a"))
		ci.draw_circle(pc, 18, Color("#e46aa0"))
		ci.draw_circle(pc + Vector2(-6, -6), 6, Color(1, 0.85, 0.9, 0.7))


func _car(ci, p: Vector2, tex_name: String, color: Color, ang := 0.0) -> void:
	var tex: Texture2D = ci.texture(tex_name)
	ci.draw_set_transform(p, ang, Vector2.ONE)
	ci.draw_rect(Rect2(-20, -32, 44, 72), Color(0, 0, 0, 0.25))
	if tex:
		var sz: Vector2 = tex.get_size() * ci.S
		ci.draw_texture_rect(tex, Rect2(-sz * 0.5, sz), false)
	else:
		ci.draw_rect(Rect2(-21, -36, 42, 72), color.darkened(0.45))
		ci.draw_rect(Rect2(-19, -34, 38, 68), color)
		ci.draw_rect(Rect2(-15, -18, 30, 14), Color("#20283a"))
		ci.draw_rect(Rect2(-15, 14, 30, 10), Color("#20283a"))
		ci.draw_rect(Rect2(-12, -6, 24, 18), color.lightened(0.15))
		ci.draw_rect(Rect2(-17, -36, 8, 4), Color("#fff2c0"))
		ci.draw_rect(Rect2(9, -36, 8, 4), Color("#fff2c0"))
		ci.draw_rect(Rect2(-17, 33, 8, 3), Color("#d83a3a"))
		ci.draw_rect(Rect2(9, 33, 8, 3), Color("#d83a3a"))
	ci.draw_set_transform(Vector2.ZERO)


func _progress(ci) -> void:
	var k := clampf(scroll / LENGTH, 0.0, 1.0)
	ci.draw_rect(Rect2(40, 92, 280, 6), Color(ci.INK, 0.7))
	ci.draw_rect(Rect2(40, 92, 280 * k, 6), ci.GOLD)
	ci.draw_circle(Vector2(40 + 280 * k, 95), 6, PURPLE)
	ci.draw_circle(Vector2(320, 95), 7, Color("#e46aa0"))


func _swipe_hint(ci) -> void:
	var a := clampf(3.0 - hint_t, 0.0, 1.0)
	var x := 180.0 + sin(hint_t * 4.0) * 40.0
	ci.draw_circle(Vector2(x, 590), 12, Color(ci.PAPER, 0.8 * a))
	for side in [-1, 1]:
		var b := Vector2(180 + side * 70, 590)
		ci.draw_colored_polygon(PackedVector2Array([b + Vector2(side * 10, 0), b + Vector2(-side * 4, -9), b + Vector2(-side * 4, 9)]), Color(ci.PAPER, 0.8 * a))


func _hold_hint(ci) -> void:
	var p := Vector2(180, 595)
	var a := 0.6 + 0.4 * sin(t * 5.0)
	ci.draw_rect(Rect2(40, 538, 280, 30), Color(ci.INK, 0.72))
	ci.text_at(Vector2(40, 543), "开过了，再来一次：车位靠近时按住屏幕" if miss_note_t > 0.0 else ci.t_("G-PARK"), 15, ci.PAPER, 280)
	ci.draw_arc(p, 18, 0, TAU, 28, Color(ci.PAPER, a), 3.0)
	ci.draw_circle(p, 8 if holding else 11, Color(ci.PAPER, a))


func _far_pearl(ci) -> void:
	# 东方明珠远景：越开越近（正式图到了用 w2/shanghai/pearl_far.png）
	var k := clampf(scroll / LENGTH, 0.0, 1.0)
	var h := lerpf(40.0, 120.0, k)
	var base := Vector2(180, 118 + h)
	var a := 0.55 + 0.35 * k
	var far: Texture2D = ci.texture("w2/shanghai/pearl_far.png")
	if far:
		var sz := Vector2(far.get_width() * h / far.get_height(), h)
		ci.draw_texture_rect(far, Rect2(base - Vector2(sz.x * 0.5, sz.y), sz), false, Color(1, 1, 1, a))
		return
	var col := Color("#c3407a", a)
	ci.draw_line(base, base - Vector2(0, h), Color("#8b8f9a", a), maxf(2.0, h * 0.04))
	ci.draw_circle(base - Vector2(0, h * 0.30), h * 0.11, col)
	ci.draw_circle(base - Vector2(0, h * 0.68), h * 0.08, col)
	ci.draw_circle(base - Vector2(0, h * 0.86), h * 0.04, col)
