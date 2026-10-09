extends SceneTree
## 第 28 条：人站在水龙头前面时，水线不画在人身上（水那层排在人后面）。五处水龙头，每个龙头附近能站的点都算一遍：
## 人身子（脚往上 86、左右各 14）跟水线（龙头嘴到水池）重叠、人又站在洗手台那件家具前面时（人盖住洗手台），人也要盖住水：
## 人的脚比水那层靠前（y 大）。人站在洗手台后面、被台子挡着的点不算（那时台子和水都在人前面，本来就对）
const W=preload("res://ayu_home/v4/world.gd")
func _initialize() -> void:
	var bad:=0;var n:=0
	for room in ["kitchen","laundry","bath1","guest_bath","bath2"]:
		var w=W.new();w.load_room(room)
		for layer in w.tap_layers:
			var h:Dictionary=w.spot(str(layer.get_meta("tap")))
			var spout:=W.v(h.get("spout",h.pos));var basin:=W.v(h.get("basin",[spout.x,spout.y+12]))
			var stream:=Rect2(spout+Vector2(-1,0),Vector2(2,maxf(2,basin.y-spout.y)+2))
			var front:=-INF
			for pr in w.props:
				var tex:Texture2D=pr.sprite.texture
				if tex and Rect2(W.v(pr.config.pos),tex.get_size()).has_point(spout) and float(pr.config.foot)<spout.y+60:front=maxf(front,float(pr.config.foot))
			for y in range(int(spout.y)-20,int(spout.y)+120,2):
				for x in range(int(spout.x)-20,int(spout.x)+21,2):
					var p:=Vector2(x,y)
					if not w.passable(p):continue
					if not Rect2(p+Vector2(-14,-86),Vector2(28,86)).intersects(stream) or p.y<=front:continue
					n+=1
					if p.y<=layer.position.y:bad+=1;print("水压在人身上 ",room," ",p," 水那层 ",layer.position.y)
		print(room," 水那层排在 ",w.tap_layers.map(func(l):return l.position.y))
		w.free()
	print("RESULT ","PASS" if bad==0 else "FAIL"," 龙头前能站又跟水线重叠的点 %d 个，水压在人身上 %d 个"%[n,bad]);quit()
