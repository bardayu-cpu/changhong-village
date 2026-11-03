extends SceneTree
const Home=preload("res://ayu_home/v4/home.gd")
var failures:Array[String]=[]
var cases:Array=[]
func _initialize() -> void:call_deferred("run")
func verify(label:String,base:Vector2,tag_size:Vector2,safe:Rect2,blocked:Array[Rect2],lift:=true,expect_visible:=true) -> void:
	var result:=Home.marker_group_layout(base,Vector2(48,54),tag_size,safe,blocked,lift)
	var ok:=not result.is_empty() if expect_visible else result.is_empty()
	if not result.is_empty():
		var marker:Rect2=result.marker;var tag:Rect2=result.tag
		ok=ok and safe.encloses(marker)
		var hit:=tag.grow_individual(0,4,0,4) if tag.has_area() else Rect2()
		if tag.has_area():ok=ok and safe.encloses(hit)
		for obstacle in blocked:ok=ok and not obstacle.intersects(marker) and (not hit.has_area() or not obstacle.intersects(hit))
		if not lift and safe.position.y<=base.y and base.y+54<=safe.end.y:ok=ok and marker.position.y==base.y
	if not ok:failures.append(label)
	cases.append({"case":label,"passed":ok,"placement":str(result)})
func run() -> void:
	var phone:=Rect2(8,98,524,710)
	# 原帧所示的双人相邻构型：原文字牌撞头，气泡本身没有撞头。
	var heads:Array[Rect2]=[Rect2(378,266,64,72),Rect2(228,278,64,72)]
	var old_tag:=Rect2(282,294,168,40)
	if not old_tag.intersects(heads[0]):failures.append("旧标签重现前提")
	verify("村委双人近距文字牌避让",Vector2(342,242),Vector2(168,40),phone,heads)
	verify("磨坊左侧坐姿",Vector2(88,478),Vector2(118,40),phone,[Rect2(132,430,64,72),Rect2(234,428,64,72)])
	verify("先夹顶边再查人脸",Vector2(260,50),Vector2.ZERO,phone,[Rect2(250,110,60,68)],false)
	verify("左边完整文字与点击区",Vector2(-12,260),Vector2(216,40),phone,[])
	verify("右边完整文字与点击区",Vector2(515,260),Vector2(216,40),phone,[])
	verify("底边保留点击区",Vector2(270,790),Vector2(216,40),phone,[])
	verify("长文字已限到安全宽度",Vector2(290,250),Vector2(524,40),phone,[])
	verify("窄屏长牌",Vector2(290,250),Vector2(304,40),Rect2(8,98,304,318),[])
	verify("横窗靠右",Vector2(1270,260),Vector2(216,40),Rect2(8,98,1264,470),[])
	verify("话泡区域避让",Vector2(250,300),Vector2(168,40),phone,[Rect2(190,345,250,60)])
	verify("人物提示只左右移",Vector2(250,180),Vector2.ZERO,phone,[Rect2(250,178,60,58)],false)
	verify("全遮挡不强行覆盖",Vector2(250,300),Vector2(168,40),phone,[phone],true,false)
	var report={"scope":"原生Godot矩形布局核验，无GUI输入、无实际存档；画面由C3补验","cases":cases,"failures":failures,"passed":failures.is_empty()}
	FileAccess.open("res://../回执/第1轮返工/标签避让-1016/几何核验.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("LABEL_LAYOUT ","PASS" if failures.is_empty() else "FAIL"," ",cases.size()," cases ",failures)
	quit(0 if failures.is_empty() else 1)
