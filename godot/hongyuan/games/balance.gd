extends RefCounted
## Thirty calm seconds balancing daily demands. Full bars wait; there is no failure.
var r
var phase := "active"
var t := 0.0
var levels := [0.25,0.4,0.2]
var touches := 0
var glow := [0.0,0.0,0.0]
const LABELS := ["工作","家人","对方"]
func start(runner,_beat: Dictionary) -> void:
	r=runner;r.hint="哪件事快堆满了，就点一下照顾它"
func rect(i: int) -> Rect2: return Rect2(28,418+i*58,304,52)  # 放在画面下方，不压住两个人
func process(dt: float) -> bool:
	t += dt
	if phase == "active":
		for i in range(3):
			levels[i] = minf(1,levels[i]+dt*(0.033+i*0.004));glow[i]=maxf(0,glow[i]-dt)
		if t>=30 and touches>=3: phase="done";r.hint=""
	return phase == "done"
func input(kind: String,pos: Vector2) -> void:
	if kind!="tap" or phase!="active":return
	for i in range(3):
		if rect(i).has_point(pos):levels[i]=maxf(0,levels[i]-0.6);glow[i]=0.5;touches+=1;r.play("pop")
func draw(ci) -> void:
	for i in range(3):
		var box:=rect(i)
		ci.pill(box,LABELS[i],18,Color("#f6e8d1"),ci.INK)
		ci.draw_rect(Rect2(box.position+Vector2(110,32),Vector2(172,7)),Color("#d7c7b0"))
		ci.draw_rect(Rect2(box.position+Vector2(110,32),Vector2(172*levels[i],7)),Color("#cc8561") if levels[i]>.8 else Color("#80a88b"))
		if glow[i]>0:ci.text_at(box.position+Vector2(114,24),"慢慢来",14,ci.WOOD,165)
	ci.text_at(Vector2(45,602),"一起度过这段日子 · %d / 30 秒"%mini(30,int(t)),14,ci.PAPER,270)
