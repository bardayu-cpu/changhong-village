extends RefCounted
## 码头短钓：按住蓄力，松手甩竿；等 2～4 秒浮标下沉，点「收！」。错过了浮标回来，再甩一次，不计次数。

var r
var phase := "aim"   # aim → backcast → cast → fly → wait → bite → reel → caught
var t := 0.0
var power := 0.0
var holding := false
var bob := Vector2.ZERO
var from := Vector2.ZERO
var wait_for := 3.0
var rng := RandomNumberGenerator.new()
var fish_t := 0.0
var missed := false


func start(runner, _beat: Dictionary) -> void:
	r = runner
	rng.seed = Time.get_ticks_usec()
	r.pose = "fishing"
	r.facing = 1.0
	r.comp_pos = r.feet + Vector2(-72,4)


const BODY_ORIGIN := Vector2(49,200)
const BODY_HEIGHT := 192.0
const ROD_LENGTH := 102.0

func body_frame() -> String:
	# Kept for head-height calculation. draw_body renders the articulated pose.
	return "w2/shizuoka/ayu_fish_hold.png"

func _motion() -> Dictionary:
	var grip := Vector2(78,87)
	var angle := -1.04
	var lean := 0.0
	if phase == "backcast":
		var k := smoothstep(0,1,clampf(t/0.28,0,1))
		grip = grip.lerp(Vector2(62,62),k)
		angle = lerpf(-1.04,-2.12,k)
		lean = -0.045*k
	elif phase == "cast":
		var k := smoothstep(0,1,clampf(t/0.24,0,1))
		grip = Vector2(62,62).lerp(Vector2(85,77),k)
		angle = lerpf(-2.12,-0.44,k)
		lean = lerpf(-0.045,0.045,k)
	elif phase == "fly":
		var k := smoothstep(0,1,clampf(t/0.6,0,1))
		grip = Vector2(85,77).lerp(Vector2(78,87),k)
		angle = lerpf(-0.44,-1.04,k)
		lean = 0.045*(1-k)
	elif phase == "reel":
		angle = -1.04+sin(t*8)*0.045
		grip += Vector2(sin(t*13)*1.2,-2)
	return {"grip":grip,"angle":angle,"lean":lean}

func _body_point(point: Vector2) -> Vector2:
	var m := _motion()
	var local := (point-BODY_ORIGIN).rotated(float(m.lean))
	local.x *= r.facing
	return r.feet+local*(r.person_height_at(r.feet.y)/BODY_HEIGHT)

func _tip() -> Vector2:
	var m := _motion()
	return _body_point(m.grip+Vector2(cos(m.angle),sin(m.angle))*ROD_LENGTH)

func draw_body(ci) -> void:
	# Reuse original hair, face, shirt and trousers. Only the arm joints and rod
	# are articulated; no stretched whole-character pose or baked second rod.
	var tex: Texture2D = ci.texture("w2/shizuoka/ayu_fish_hold.png")
	if not tex: return
	var motion := _motion()
	var k: float = ci.person_height_at(ci.feet.y)/BODY_HEIGHT
	ci.draw_set_transform(ci.feet+Vector2(0,ci.camera_y),float(motion.lean),Vector2(k*ci.facing,k))
	for region: Rect2 in [Rect2(11,95,64,107),Rect2(37,54,32,43),Rect2(28,8,56,47)]:
		ci.draw_texture_rect_region(tex,Rect2(region.position-BODY_ORIGIN,region.size),region)
	var grip: Vector2 = motion.grip
	var right_elbow := Vector2(76,83).lerp(Vector2(77,65),clampf((-float(motion.angle)-1.04)/1.08,0,1))
	var left_hand := grip+Vector2(-9,6)
	if phase == "reel": left_hand += Vector2(cos(t*21),sin(t*21))*3.5
	_arm(ci,Vector2(66,59),right_elbow,grip)
	_arm(ci,Vector2(36,61),Vector2(37,84).lerp(Vector2(43,72),clampf((-float(motion.angle)-1.04)/1.08,0,1)),left_hand)
	ci.draw_set_transform(Vector2.ZERO)
	_draw_rod(ci)
	ci.draw_set_transform(Vector2(0,ci.camera_y))

func _arm(ci,shoulder: Vector2,elbow: Vector2,hand: Vector2) -> void:
	var pts := PackedVector2Array([shoulder-BODY_ORIGIN,elbow-BODY_ORIGIN,hand-BODY_ORIGIN])
	ci.draw_polyline(pts,Color("#3e261d"),7)
	ci.draw_polyline(pts,Color("#df9e66"),5)
	ci.draw_polyline(pts,Color("#f4bd83"),2)
	ci.draw_line(shoulder-BODY_ORIGIN,shoulder.lerp(elbow,0.38)-BODY_ORIGIN,Color("#e7e8dd"),7)
	ci.draw_rect(Rect2(hand-BODY_ORIGIN-Vector2(2,2),Vector2(5,5)),Color("#efb57d"))

func _draw_rod(ci) -> void:
	var m := _motion()
	var grip: Vector2 = m.grip
	var unit := Vector2(cos(m.angle),sin(m.angle))
	var bent := 5.0*sin(clampf(t/0.24,0,1)*PI) if phase == "cast" else (2.0 if phase == "reel" else 0.5)
	var pts := PackedVector2Array()
	for i in range(9):
		var k := i/8.0
		var p := grip+unit*(ROD_LENGTH*k)+Vector2(-unit.y,unit.x)*(sin(k*PI)*bent)
		pts.append(_body_point(p)+Vector2(0,ci.camera_y))
	ci.draw_polyline(pts,Color("#342a29"),2)
	ci.draw_polyline(pts,Color("#b8bca7"),0.7)
	ci.draw_line(_body_point(grip-unit*10),_body_point(grip+unit*7),Color("#62432b"),3)
	ci.draw_circle(_body_point(grip+Vector2(-5,5)),3.5,Color("#4e626b"))
	ci.draw_circle(_body_point(grip+Vector2(-5,5)),1.6,Color("#bdc5bd"))


func process(dt: float) -> bool:
	t += dt
	match phase:
		"aim":
			if holding:
				power = fmod(power + dt * 0.9, 2.0)
		"backcast":
			if t >= 0.28:
				phase = "cast"
				t = 0.0
		"cast":
			if t >= 0.24:
				from = _tip()
				phase = "fly"
				t = 0.0
				bob = from
				r.play("blip")
		"fly":
			var k := clampf(t / 0.6, 0.0, 1.0)
			bob = from.lerp(_landing(), k) + Vector2(0, -sin(k * PI) * 70.0)
			if k >= 1.0:
				phase = "wait"
				t = 0.0
				wait_for = rng.randf_range(2.0, 4.0)
				r.play("blip")
		"wait":
			if t >= wait_for:
				phase = "bite"
				t = 0.0
				r.play("blip")
		"bite":
			if t >= 3.0:
				phase = "aim"
				missed = true
				power = 0.0
				t = 0.0
		"reel":
			var k := smoothstep(0, 1, clampf(t / 0.55, 0, 1))
			bob = _landing().lerp(r.feet + Vector2(30, -36), k) + Vector2(sin(t * 26) * 2, 0)
			if k >= 1:
				phase = "caught"
				t = 0.0
				fish_t = 0.0
				r.play("pop")
		"caught":
			fish_t += dt
			if fish_t >= 1.6:
				r.pose = ""
				return true
	return false


func _p() -> float:
	return power if power <= 1.0 else 2.0 - power


func _landing() -> Vector2:
	return Vector2(r.feet.x + 40 + _p() * 60.0, r.feet.y - 70 - _p() * 150.0)


func input(kind: String, pos: Vector2) -> void:
	match phase:
		"aim":
			if kind == "down":
				holding = true
				power = 0.0
				missed = false
			elif kind == "up" and holding:
				holding = false
				phase = "backcast"
				t = 0.0
				from = _tip()
		"bite":
			if kind in ["down", "tap"]:
				phase = "reel"
				t = 0.0
				fish_t = 0.0
				r.play("blip")
		"wait":
			pass  # 还没咬钩时乱点不惩罚


func draw(ci) -> void:
	var tip := _tip()
	if phase in ["backcast","cast"]:
		_line(ci, tip, tip + Vector2(-10, 22))
	if phase in ["fly", "wait", "bite", "reel"]:
		var b := bob
		if phase == "wait":
			b = _landing() + Vector2(0, sin(t * 4.0) * 1.5)
		elif phase == "bite":
			b = _landing() + Vector2(0, 4 + sin(t * 30.0) * 2.0)
		_line(ci, tip, b)
		_bobber(ci, b, phase in ["bite", "reel"])
		if phase != "fly":
			ci.draw_arc(b + Vector2(0, 4), 10 + fmod(t * 8.0, 8.0), 0, TAU, 20, Color(1, 1, 1, 0.35), 1.0)
	if phase == "caught":
		var k := clampf(fish_t / 0.9, 0.0, 1.0)
		var p := bob.lerp(r.feet + Vector2(-34, -20), k) + Vector2(0, -sin(k * PI) * 90.0)
		_line(ci, tip, p)
		var fish: Texture2D = ci.texture("w2/shizuoka/fish.png")
		if fish:
			var sz: Vector2 = fish.get_size() * ci.S
			ci.draw_texture_rect(fish, Rect2(p - sz * 0.5, sz), false)
		else:
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-14, 0), p + Vector2(0, -7), p + Vector2(12, 0), p + Vector2(0, 7)]), Color("#9fb7c9"))
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(12, 0), p + Vector2(20, -6), p + Vector2(20, 6)]), Color("#7d97ab"))
			ci.draw_rect(Rect2(p + Vector2(-9, -2), Vector2(2, 2)), Color("#1d1d1d"))
		if fish_t < 0.5:
			for i in range(6):
				var a := TAU * i / 6.0
				ci.draw_rect(Rect2(_landing() + Vector2(cos(a), sin(a) * 0.5) * fish_t * 50.0, Vector2(3, 3)), Color(1, 1, 1, 1.0 - fish_t * 2.0))
	if phase == "aim":
		var base: Vector2 = r.feet + Vector2(-60, -60)
		ci.draw_rect(Rect2(base, Vector2(12, 70)), Color(ci.INK, 0.8))
		ci.draw_rect(Rect2(base + Vector2(2, 68 - 66 * _p()), Vector2(8, 66 * _p())), ci.GOLD)
		if not holding:
			var a := 0.6 + 0.4 * sin(t * 5.0)
			ci.draw_arc(Vector2(180, 590), 18, 0, TAU, 28, Color(ci.PAPER, a), 3.0)
			ci.draw_circle(Vector2(180, 590), 10, Color(ci.PAPER, a))
	var hint := ""
	if phase == "aim":
		hint = ci.t_("G-FISH-MISS") if missed and t < 2.0 else ci.t_("G-FISH-HOLD")
	elif phase == "wait":
		hint = ci.t_("G-FISH-WAIT")
	if hint != "":
		ci.pill(Rect2(70, 520, 220, 34), hint, 15, Color(ci.INK, 0.8), ci.RED if missed and phase == "aim" and t < 2.0 else ci.PAPER)
	if phase == "caught":
		ci.pill(Rect2(110, 520, 140, 40), ci.t_("G-FISH-GOT"), 20, ci.RED, ci.PAPER)
	if phase == "bite":
		var pulse := 1.0 + 0.08 * sin(t * 18.0)
		var rect := Rect2(Vector2(180, 560) - Vector2(60, 26) * pulse, Vector2(120, 52) * pulse)
		ci.pill(rect, ci.t_("A4-P2"), 24, ci.RED, ci.PAPER)


func _line(ci, a: Vector2, b: Vector2) -> void:
	var pts := PackedVector2Array()
	for i in range(13):
		var k := i / 12.0
		pts.append(a.lerp(b, k) + Vector2(0, sin(k * PI) * 10.0))
	ci.draw_polyline(pts, Color(1, 1, 1, 0.75), 1.0)


func _bobber(ci, p: Vector2, sinking: bool) -> void:
	var tex: Texture2D = ci.texture("w2/shizuoka/bobber_%d.png" % (2 if sinking else 1))
	if tex:
		var sz: Vector2 = tex.get_size() * ci.S
		ci.draw_texture_rect(tex, Rect2(p - sz * 0.5, sz), false)
		return
	ci.draw_rect(Rect2(p + Vector2(-3, -6), Vector2(6, 6)), Color("#d63c3c"))
	if not sinking:
		ci.draw_rect(Rect2(p + Vector2(-3, 0), Vector2(6, 4)), Color("#f5f0e6"))


func restore_checkpoint() -> void:
	r.comp_pos = r.feet + Vector2(-72,4)
