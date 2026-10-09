extends SceneTree
## 体验师第三轮查出的 5 处小家具：点过去不能站上去（停在家具前面）
const W=preload("res://ayu_home/v4/world.gd")
func _initialize() -> void:
	var fails:=0
	for it in [["parents",Vector2(110,83)],["parents",Vector2(292,170)],["parents",Vector2(320,270)],["mahjong",Vector2(272,288)],["workshop",Vector2(111,243)]]:
		var w=W.new();w.load_room(it[0]);var r:PackedVector2Array=w.path(w.nearest(it[1]+Vector2(0,60)),it[1]);var end:Vector2=r[r.size()-1] if r.size()>0 else Vector2.ZERO
		var on:bool=end.distance_to(it[1])<8
		print(it[0]," ",it[1]," 走到 ",end," 站上去=",on);fails+=int(on);w.free()
	print("RESULT ","PASS" if fails==0 else "FAIL");quit()
