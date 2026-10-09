extends SceneTree
## 摘果、捞鱼、翻牌、看星星加深以后的玩法：照真实玩家的操作一步步走（画布坐标），确认能玩完、手法不对不会过
const Games=preload("res://ayu_home/v4/life_games.gd")
const Life=preload("res://ayu_home/v4/life_state.gd")
var g
var fails:Array=[]
func check(ok:bool,label:String) -> void:
	print("CHECK ",ok," ",label)
	if not ok:fails.append(label)
func step(sec:float) -> void:
	for i in int(sec/.05):g._process(.05)
func press(p:Vector2) -> void:g.pointer=p;g.holding=true;g.pointer_down(p)
func move(p:Vector2) -> void:var a:Vector2=g.pointer;g.previous=a;g.pointer=p;g.pointer_move(a,p)
func release(p:Vector2) -> void:g.pointer_up(p);g.holding=false;g.drag_id=-1
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var vp:=SubViewport.new();vp.size=Vector2i(540,960);root.add_child(vp)
	var life=Life.new();life.open({"id":"deeper"},OS.get_user_data_dir()+"/deeper.json");life.data.effects={};life.save()
	g=Games.new();vp.add_child(g);await process_frame
	# 摘果
	g.open("fruit",life,{"month":10,"sound":false});await process_frame
	var unripe:Dictionary=g.fruits[1];press(unripe.pos);release(unripe.pos);step(.5)
	check(unripe.state=="hang","青果子点了只晃一晃，不会掉")
	var got:=0
	for f in g.fruits:
		if not f.ripe or got>=3:continue
		press(f.pos);release(f.pos)
		press(Vector2(g.basket_x,480));move(Vector2(f.pos.x,480));release(Vector2(f.pos.x,480))
		step(1.5);got+=1
	check(g.caught==3 and g.finished,"熟果子掉下来、拖篮子接住三颗就采好一篮（接到 %d）"%g.caught)
	var missed:Dictionary={}
	g.open("fruit",life,{"month":10,"sound":false});await process_frame
	for f in g.fruits:
		if f.ripe:missed=f;break
	g.basket_x=390;press(missed.pos);release(missed.pos);step(2.0)
	check(missed.state=="ground","没接住的落在草上")
	press(missed.pos);release(missed.pos);check(missed.state=="basket","草上的点一下捡回篮子，不扣东西")
	# 捞鱼
	g.open("net",life,{"month":10,"sound":false});await process_frame;step(.2)
	var fish:Dictionary=g.net_fish[0];press(Vector2(420,470));step(.1)
	for i in 6:g.pointer=fish.pos+Vector2(130 if i%2 else -130,0);g._process(.05)
	g.pointer=fish.pos;g._process(.05)
	check(not fish.caught,"网兜挥得太快，鱼游开了没捞到")
	var caught_fish:=0
	for f in g.net_fish:
		if caught_fish>=3:break
		g.holding=true
		for i in 40:g.pointer=f.pos;g._process(.05)
		if f.caught:caught_fish+=1
	check(caught_fish>=3 and g.finished,"慢慢停在鱼底下，捞到三条（%d）"%caught_fish)
	# 翻牌
	g.open("pairs",life,{"month":10,"sound":false});await process_frame
	press(g.card_rect(0).get_center());release(Vector2.ZERO)
	check(g.flipped.is_empty(),"开局先亮牌给你记，这时候点牌不翻")
	step(2.0)
	for round in 2:
		var n:int=g.pairs.size()
		for v in n/2:
			var idx:=[]
			for i in n:
				if g.pairs[i]==v:idx.append(i)
			for i in idx:press(g.card_rect(i).get_center());release(Vector2.ZERO)
			step(.1)
		check(g.matched.size()==n,"第 %d 局 %d 张都配上"%[round+1,n])
		if round==0:
			check(g.finished,"第一局配完算完成")
			for b in g.footer.get_children():
				if b is Button and b.text.begins_with("再来一局"):b.pressed.emit()
			await process_frame;step(2.0)
			check(g.pairs.size()==12,"再来一局是十二张")
	# 看星星（夜里）
	g.open("stars",life,{"month":10,"hour":21.0,"sound":false});await process_frame;step(.5)
	press(Vector2(430,500));release(Vector2.ZERO);check(g.found_stars==0,"点错地方不算")
	for i in g.stars.size():press(g.stars[i]);release(Vector2.ZERO);step(.1)
	check(g.finished,"一颗颗点亮星座")
	for b in g.footer.get_children():
		if b is Button and b.text=="再认一个星座":b.pressed.emit()
	await process_frame
	check(g.found_stars==0 and g.constellation==1,"还能再认一个星座")
	for i in g.stars.size():press(g.stars[i]);release(Vector2.ZERO);step(.1)
	check(g.found_stars==g.stars.size(),"第二个星座也连好")
	# 看云（白天）
	g.open("stars",life,{"month":10,"hour":12.0,"sound":false});await process_frame
	for c in g.clouds.slice(0,3):press(g.cloud_pos(c));release(Vector2.ZERO);step(.1)
	check(g.finished,"白天点三朵像小动物的云")
	g.close(false);vp.queue_free();await process_frame
	print("RESULT ","PASS" if fails.is_empty() else "FAIL"," ",fails.size());quit()
