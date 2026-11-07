extends RefCounted
## 香港迪士尼回忆：两人并肩走进画面（Toretto 跟在后面），出现相机，点一下拍照：
## 白闪之后画面定格成一张带边框的拍立得，停约 2 秒。
const AYU_WALK := "w2/common/ayu_walk_side_%d.png|ayu_walk.png"
const AYU_STAND := "ayu_idle.png"
const TORETTO_STAND := "w2/common/toretto_neutral_r2.png"
const AYU_Y := 572.0
const TORETTO_Y := 576.0
const AYU_STOP := 168.0
const TORETTO_STOP := 224.0
const CAMERA := Vector2(196, 438)
const SHOW_TIME := 2.2

var r
var phase := "walk"   # walk → ready → prep → flash → show → done
var t := 0.0
var ayu_x := -34.0
var toretto_x := -86.0
var walk_d := 0.0
var _frames := 0
var caption := "B-G3-1"
var _photo: Texture2D


func start(runner, beat: Dictionary) -> void:
	r = runner
	caption = str(beat.get("caption","B-G3-1"))
	r.hint = ""


func restore_checkpoint() -> void:
	# The GPU texture is deliberately excluded from JSON checkpoints. Rebuild it
	# from a clean couple frame before replaying the flash/polaroid transition.
	_photo = null
	_frames = 0
	if phase != "walk":
		ayu_x = AYU_STOP
		toretto_x = TORETTO_STOP
	if phase in ["prep", "flash", "show"]:
		phase = "prep"
		t = 0.0
	r.hint = r.t_("G-PHOTO") if phase == "ready" else ""


func process(dt: float) -> bool:
	t += dt
	match phase:
		"walk":
			var ayu_step := minf(AYU_STOP - ayu_x, 74.0 * dt)
			var tor_step := minf(TORETTO_STOP - toretto_x, 78.0 * dt)
			ayu_x += ayu_step
			toretto_x += tor_step
			walk_d += maxf(ayu_step, tor_step)
			if ayu_step <= 0.0 and tor_step <= 0.0:
				phase = "ready"
				t = 0.0
				r.hint = r.t_("G-PHOTO")
		"prep":
			_frames += 1
			if _frames >= 3:
				_capture()
				phase = "flash"
				t = 0.0
				r.play("pop")
		"flash":
			if t >= 0.5:
				phase = "show"
				t = 0.0
		"show":
			if t >= SHOW_TIME:
				phase = "done"
	return phase == "done"


func _capture() -> void:
	var vp: Viewport = r.get_viewport()
	if vp and vp.get_texture():
		var img: Image = vp.get_texture().get_image()
		if img and img.get_width() > 8:
			_photo = ImageTexture.create_from_image(img)


func _camera_rect() -> Rect2:
	return Rect2(CAMERA - Vector2(24, 24), Vector2(48, 48))


func input(kind: String, pos: Vector2) -> void:
	if kind != "tap" or phase != "ready":
		return
	# 相机图标及其下方一整片都算（手指常点在图标下面）
	var zone := _camera_rect().grow(16)
	zone = zone.merge(Rect2(zone.position.x - 30, zone.position.y, zone.size.x + 60, zone.size.y + 90))
	if zone.has_point(pos):
		phase = "prep"
		t = 0.0
		_frames = 0
		r.hint = ""


func skip() -> void:
	phase = "done"
	r.hint = ""


# ---------- 画 ----------

func draw(ci) -> void:
	if phase in ["show", "flash"] and _photo:
		ci.draw_rect(ci.view_rect, Color(0.04, 0.03, 0.05, 0.6 if phase == "show" else 0.0))
	else:
		_draw_couple(ci)
	if phase == "ready":
		_draw_camera(ci)
	if phase == "show":
		_draw_polaroid(ci)
	if phase == "flash":
		ci.draw_rect(ci.view_rect, Color(1, 1, 1, 1.0 - clampf(t / 0.5, 0.0, 1.0)))


func _draw_couple(ci) -> void:
	var walking: bool = phase == "walk"
	var f := 1 + int(walk_d / 9.0) % 4
	# 后面的先画：Toretto 跟在阿鱼后面
	var tor_frame: String = TORETTO_STAND
	if walking and toretto_x < TORETTO_STOP - 0.5:
		tor_frame = "w2/common/toretto_walk.png" if int(walk_d / 11.0) % 2 == 0 else TORETTO_STAND
	var ayu_frame: String = AYU_STAND
	if walking and ayu_x < AYU_STOP - 0.5:
		ayu_frame = AYU_WALK % f
	ci.sprite(tor_frame, Vector2(toretto_x, TORETTO_Y), false, 1.0)
	ci.sprite(ayu_frame, Vector2(ayu_x, AYU_Y + (-1.0 if walking and f % 2 == 0 else 0.0)), false, 1.0)


func _draw_camera(ci) -> void:
	var c: Vector2 = CAMERA + Vector2(0, sin(ci.time * 4.0) * 3.0)
	var a: float = 0.5 + 0.3 * sin(ci.time * 4.5)
	var ring := PackedVector2Array()
	for j in range(25):
		var ang := TAU * j / 24.0
		ring.append(c + Vector2(cos(ang), sin(ang)) * (30.0 + sin(ci.time * 4.5) * 2.0))
	ci.draw_polyline(ring, Color(1.0, 0.92, 0.65, a), 2.0)
	ci.draw_circle(c, 26.0, Color(ci.INK, 0.8))
	ci.draw_rect(Rect2(c + Vector2(-15, -9), Vector2(30, 20)), Color("#e9dfd0"))
	ci.draw_rect(Rect2(c + Vector2(-15, -9), Vector2(30, 20)), ci.INK, false, 2.0)
	ci.draw_rect(Rect2(c + Vector2(-10, -14), Vector2(10, 6)), Color("#e9dfd0"))
	ci.draw_rect(Rect2(c + Vector2(-10, -14), Vector2(10, 6)), ci.INK, false, 2.0)
	ci.draw_circle(c + Vector2(0, 1), 7.0, ci.INK)
	ci.draw_circle(c + Vector2(0, 1), 4.5, Color("#5aa8d6"))
	ci.draw_circle(c + Vector2(-1.5, -0.5), 1.5, Color(1, 1, 1, 0.9))
	ci.draw_rect(Rect2(c + Vector2(9, -7), Vector2(4, 3)), ci.GOLD)


func _draw_polaroid(ci) -> void:
	var k := clampf(t / 0.28, 0.0, 1.0)
	var pop := 1.0 + (1.0 - k) * 0.16
	var center := Vector2(180, 316)
	ci.draw_set_transform(center, deg_to_rad(-2.0), Vector2(pop, pop))
	var outer := Rect2(Vector2(-134, -246), Vector2(268, 488))
	ci.draw_rect(Rect2(outer.position + Vector2(5, 7), outer.size), Color(0, 0, 0, 0.35 * k))
	ci.draw_rect(outer, Color("#fbf6ea", k))
	ci.draw_rect(outer, Color(ci.INK, 0.9 * k), false, 2.0)
	var photo := Rect2(Vector2(-122, -234), Vector2(244, 434))
	if _photo:
		var src := Rect2(Vector2.ZERO,_photo.get_size())
		var wanted := photo.size.x/photo.size.y
		if src.size.x/src.size.y > wanted:
			src.position.x = (src.size.x-src.size.y*wanted)*0.5
			src.size.x = src.size.y*wanted
		else:
			src.position.y = (src.size.y-src.size.x/wanted)*0.5
			src.size.y = src.size.x/wanted
		ci.draw_texture_rect_region(_photo, photo, src, Color(1,1,1,k))
	else:
		ci.draw_rect(photo, Color("#d8b9a2", k))
	ci.draw_rect(photo, Color(ci.WOOD, 0.8 * k), false, 2.0)
	ci.text_at(Vector2(-122, 224), ci.t_(caption), 16, Color(ci.INK, k), 244)
	ci.draw_set_transform(Vector2.ZERO)
