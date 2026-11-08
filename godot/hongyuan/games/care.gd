extends RefCounted
## Six worries; unlimited care tokens, no failure and no penalty for a missed drag.
var r
var phase := "care"
var t := 0.0
var cleared: Array = []
var dragging := false
var pointer := Vector2.ZERO
var pops: Array = []   # [中心, 剩余时间]：泡泡碎开的动画
const CENTERS := [Vector2(78,160),Vector2(258,160),Vector2(68,255),Vector2(278,255),Vector2(75,350),Vector2(265,350)]
const WORDS := ["周报","会议","加班","家庭的责任","相处的摩擦","工作压力"]
const TRAY := Rect2(56,530,248,65)
func start(runner,_beat: Dictionary) -> void:
	r = runner
	r.hint = "把关心拖向烦恼，或拖给阿鱼"
func process(dt: float) -> bool:
	t += dt
	for p in pops: p[1] = float(p[1]) - dt
	pops = pops.filter(func(p) -> bool: return float(p[1]) > 0.0)
	if phase == "settle" and t > 1.6: phase = "done"
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
			cleared.append(hit);r.play("pop");pops.append([CENTERS[hit],0.5])
			if cleared.size() == 6: phase = "settle";t = 0;r.hint = ""
func draw(ci) -> void:
	# 烦恼一个个放下，阿鱼越来越轻松；全部放下时换成开心的样子
	var art := "w2/common/ayu_cheer.png|ayu_idle.png" if phase != "care" else "ayu_idle.png"
	ci.sprite(art,Vector2(180,475),false,0.85)
	if cleared.size() >= 3 and phase == "care":
		ci.draw_arc(Vector2(180,400),46 + cleared.size() * 2,0,TAU,40,Color(1,0.85,0.6,0.12 * cleared.size()),6)
	for i in range(6):
		if i in cleared: continue
		var c: Vector2 = (CENTERS[i]+Vector2(0,sin(t*1.2+i)*3)).round()
		_bubble(ci,c,43)
		ci.text_at(c-Vector2(42,-5),WORDS[i],14,ci.PAPER,84)
	for p in pops:
		var k := 1.0 - float(p[1]) / 0.5
		for j in range(8):
			var a := TAU * j / 8.0
			var q: Vector2 = (p[0] as Vector2) + Vector2(cos(a),sin(a)) * (30 + 30 * k)
			ci.draw_rect(Rect2(q.round() - Vector2(3,3),Vector2(6,6)),Color(0.62,0.72,0.95,1.0 - k))
	ci.pill(TRAY,"Toretto 的关心 · 拖给她",16,Color("#f5dfbe"),ci.INK)
	var face: Texture2D = ci.texture("toretto_avatar.png")
	if face: ci.draw_texture_rect(face,Rect2(TRAY.position + Vector2(-30,10),Vector2(44,44)),false)
	ci.text_at(Vector2(90,512),"已经放下 %d / 6"%cleared.size(),15,ci.PAPER,180)
	if dragging:
		ci.draw_circle(pointer,24,Color("#edb1a4"));ci.text_at(pointer-Vector2(25,-5),"关心",14,ci.INK,50)

## 像素风的烦恼泡泡：深色圆 + 2px 浅色描边 + 左上角方块高光（不再是平面蓝圆）
func _bubble(ci, c: Vector2, rad: float) -> void:
	ci.draw_circle(c,rad,Color(0.20,0.24,0.36,0.88))
	ci.draw_arc(c,rad-1,0,TAU,24,Color(0.55,0.62,0.82,0.9),2)
	ci.draw_rect(Rect2(c + Vector2(-rad*0.55,-rad*0.6),Vector2(8,8)),Color(0.85,0.9,1.0,0.7))
	ci.draw_rect(Rect2(c + Vector2(-rad*0.55+10,-rad*0.6+2),Vector2(4,4)),Color(0.85,0.9,1.0,0.5))
