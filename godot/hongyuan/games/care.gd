extends RefCounted
## Six worries; unlimited care tokens, no failure and no penalty for a missed drag.
var r
var phase := "care"
var t := 0.0
var cleared: Array = []
var dragging := false
var pointer := Vector2.ZERO
const CENTERS := [Vector2(78,160),Vector2(258,160),Vector2(68,255),Vector2(278,255),Vector2(75,350),Vector2(265,350)]
const WORDS := ["周报","会议","加班","家庭的责任","相处的摩擦","工作压力"]
const TRAY := Rect2(56,530,248,65)
func start(runner,_beat: Dictionary) -> void:
	r = runner
	r.hint = "把关心拖向烦恼，或拖给阿鱼"
func process(dt: float) -> bool:
	t += dt
	if phase == "settle" and t > 1.4: phase = "done"
	return phase == "done"
func input(kind: String,pos: Vector2) -> void:
	if phase != "care": return
	if kind == "down": dragging = TRAY.has_point(pos);pointer = pos
	elif kind == "move" and dragging: pointer = pos
	elif kind == "up" and dragging:
		dragging = false
		var hit := -1
		for i in range(6):
			if i not in cleared and pos.distance_to(CENTERS[i]) < 49: hit = i;break
		if hit < 0 and Rect2(130,270,100,220).has_point(pos):
			for i in range(6):
				if i not in cleared: hit = i;break
		if hit >= 0:
			cleared.append(hit);r.play("pop")
			if cleared.size() == 6: phase = "settle";t = 0;r.hint = ""
func draw(ci) -> void:
	ci.sprite("ayu_idle.png",Vector2(180,475),false,0.85)
	for i in range(6):
		if i in cleared: continue
		var c: Vector2 = CENTERS[i]+Vector2(0,sin(t*1.2+i)*3)
		ci.draw_circle(c,43,Color(0.24,0.28,0.4,0.80))
		ci.text_at(c-Vector2(42,-5),WORDS[i],14,ci.PAPER,84)
	ci.pill(TRAY,"关心 · 拖给她",18,Color("#f5dfbe"),ci.INK)
	ci.text_at(Vector2(90,512),"已经放下 %d / 6"%cleared.size(),15,ci.PAPER,180)
	if dragging:
		ci.draw_circle(pointer,24,Color("#edb1a4"));ci.text_at(pointer-Vector2(25,-5),"关心",14,ci.INK,50)
