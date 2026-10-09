extends SceneTree
const Home=preload("res://ayu_home/v4/home.gd")
var checks:Array=[]
func _initialize() -> void:call_deferred("run")
func check(condition:bool,label:String) -> void:checks.append({"pass":condition,"name":label});print("CHECK ",condition," ",label)
func button(n:Node,copy:String):
	if n is Button and n.text==copy:return n
	for c in n.get_children():
		var b=button(c,copy)
		if b:return b
	return null
func label_copy(n:Node) -> String:
	var copy:String=n.text if n is Label else ""
	for child in n.get_children():copy+="\n"+label_copy(child)
	return copy
func click(vp:SubViewport,c:Control) -> void:
	if not is_instance_valid(c):check(false,"button exists");return
	var at:=c.get_global_rect().get_center() # 按下就关掉的框（对话框），松手时它已经没了
	for down in [true,false]:
		var e:=InputEventMouseButton.new();e.position=at;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;vp.push_input(e,true);await process_frame
	for i in 8:await process_frame
func run() -> void:
	for height in [960,1168]:
		var vp:=SubViewport.new();vp.size=Vector2i(540,height);root.add_child(vp)
		if height==1168:vp.size=Vector2i(1170,2532);vp.size_2d_override=Vector2i(540,1168);vp.size_2d_override_stretch=true
		var h=Home.new();h.town_profile={"id":"responsive-input-"+str(height),"avatar":2};h.save_path="/private/tmp/ayu-responsive-input-"+str(height)+".json";vp.add_child(h);await process_frame;h.set_process(false);h.set_test_clock(12.25);h.welcome()
		for i in 8:await process_frame
		await click(vp,button(h,"看看今日小事"));check(button(h,"去找妈妈")!=null,str(height)+" welcome → tasks")
		await click(vp,button(h,"去找妈妈"));check(h.modal==null and h.tracked_person=="mother",str(height)+" task starts route")
		h.tracked_person="";h.dialogue("妈妈","慢慢来，锅里的汤还热着。","mother")
		for i in 8:await process_frame
		# 第七轮 村-1：对话框换成罗曼那套，人物卡改成点头像（或名字牌）打开
		await click(vp,h.talk_ui.talk_box.find_child("face",true,false));check(button(h,"继续聊天")!=null,str(height)+" dialogue → identity card")
		await click(vp,button(h,"继续聊天"));check(h.talk_label!=null and h.talk_line=="慢慢来，锅里的汤还热着。",str(height)+" identity returns to conversation")
		h.talk_chars=999;h._process(.016);await click(vp,h.talk_ui.talk_box);check(h.modal==null,str(height)+" tapping the dialogue box closes the last line")
		h.settings_page()
		for i in 8:await process_frame
		var before:bool=h.sound_on;await click(vp,button(h,"声音 · "+("开" if before else "关")));check(h.sound_on!=before,str(height)+" settings sound toggle")
		await click(vp,button(h,"保存并继续"));check(h.modal==null,str(height)+" settings close")
		h.life.data.photos=[{"area":"dining"}];h.life_book()
		for i in 8:await process_frame
		check(label_copy(h.modal).contains("1 张合影") and not label_copy(h.modal).contains("等着第一件小事"),str(height)+" saved photo appears in the life book")
		h.calendar_page()
		for i in 8:await process_frame
		check(h.modal.panel.position.y>=0 and h.modal.panel.position.y+h.modal.panel.size.y<=height,str(height)+" calendar fits viewport")
		h.stop_audio();vp.queue_free();await process_frame
	var failures:=checks.filter(func(c):return not c.pass);var f:=FileAccess.open("res://ayu_home/v4/evidence/responsive-inputs.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures},"  "));f.close();print("RESULT ","PASS" if failures.is_empty() else "FAIL"," responsive inputs");quit(0 if failures.is_empty() else 1)
