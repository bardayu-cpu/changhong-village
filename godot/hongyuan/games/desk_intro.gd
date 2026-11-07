extends RefCounted
const Desk := preload("res://hongyuan/ui/desk_art.gd")
var r
var t := 0.0
var done := false
var copy_id := "A0-1"
func start(runner, beat: Dictionary) -> void:
	r = runner
	copy_id = str(beat.get("copyId", "A0-1"))
func process(dt: float) -> bool:
	t += dt
	return done
func input(kind: String, _pos: Vector2) -> void:
	if kind == "tap" and t > 0.5:
		done = true
		r.play("blip")
func draw(ci) -> void:
	Desk.draw(ci, r.materials, r.view_rect, "", t)
	ci.StoryCaption.draw_caption(ci, ci.t_(copy_id), "ayu", -1, false, Vector2(88, 150))
	ci.pill(Rect2(104, 566, 152, 44), "轻点继续", 17, ci.RED, ci.PAPER)
