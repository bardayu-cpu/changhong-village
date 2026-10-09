extends SceneTree
## 第八轮第 4 条（总002）：面板正文一行别只剩一个字（「来。」「意。」）。540×960 开每个面板，
## 把会自动折行的字按真实宽度折一遍（TextParagraph，跟 Label 同字体、同字号、同宽），哪行去掉标点只剩 1 个字就算吊字
const Home=preload("res://ayu_home/v4/home.gd")
var h
var vp:SubViewport
var bad:Array=[]
var count:=0
func _initialize() -> void:call_deferred("run")
func labels(n:Node,out:Array) -> void:
	if n is Label and n.is_visible_in_tree() and n.autowrap_mode!=TextServer.AUTOWRAP_OFF:out.append(n)
	for c in n.get_children():labels(c,out)
func check(tag:String) -> void:
	for i in 3:await process_frame
	var ls:Array=[];labels(h,ls)
	for l in ls:
		var font:Font=l.get_theme_font("font");var fs:int=l.get_theme_font_size("font_size")
		var sb:StyleBox=l.get_theme_stylebox("normal");var w:float=l.size.x-(sb.get_margin(SIDE_LEFT)+sb.get_margin(SIDE_RIGHT) if sb else 0.0)
		for part:String in l.text.split("\n"):
			if part.strip_edges().is_empty():continue
			var p:=TextParagraph.new();p.add_string(part,font,fs);p.width=w;p.break_flags=TextServer.BREAK_MANDATORY|TextServer.BREAK_WORD_BOUND|TextServer.BREAK_ADAPTIVE
			count+=1
			if p.get_line_count()<2:continue
			for i in range(1,p.get_line_count()):
				var r:Vector2i=p.get_line_range(i);var line:String=part.substr(r.x,r.y-r.x)
				var core:String=line
				for ch in "，。、！？：；…·「」“”（） ,.!?":core=core.replace(ch,"")
				if core.strip_edges().length()<=1:bad.append("%s：「%s」最后一行只剩「%s」"%[tag,part,line])
func panel(tag:String,f:Callable) -> void:
	f.call();await create_timer(.3).timeout;await check(tag);h.close_modal()
func run() -> void:
	vp=SubViewport.new();vp.size=Vector2i(540,960);root.add_child(vp)
	var save:=OS.get_user_data_dir()+"/claude-orphans.json";DirAccess.remove_absolute(save)
	h=Home.new();h.town_profile={"id":"claude-orphans","avatar":2};h.save_path=save;vp.add_child(h);await process_frame;h.set_process(false);h.sound_on=false;h.admitted=true;h.close_modal()
	for hour in [14.5,21.0]:
		h.set_test_clock(hour);h.enter_room("living",false,"exterior");for i in 900:h._process(0.05)
		await panel("家里的人 %s 点"%hour,h.family_page)
	for id in ["ayu","father","mother"]:await panel("人物卡 "+id,func():h.family_card(id))
	await panel("生活册",h.life_book);await panel("今日小事",h.today);await panel("设置",h.settings_page)
	for floor in ["一楼","二楼","屋外"]:
		h.navigation(floor);await create_timer(.3).timeout;await check("地图 "+floor)
		# 每个房间缩略图下面都要有名字（别把名字弄丢了）
		var rooms:=0;var named:=0
		for id in h.definitions:
			if h.definitions[id].group==floor:rooms+=1
		var ls:Array=[];labels(h,ls)
		for l in ls:
			if l.get_parent() is VBoxContainer and l.get_parent().get_child(0) is Button and not l.text.is_empty():named+=1
		if named!=rooms:bad.append("地图 %s：%d 个房间，下面有名字的 %d 个"%[floor,rooms,named])
		h.close_modal();await panel("挂历",h.calendar_page);await panel("收集册",h.collection_page);await panel("相册",h.album_page)
	# 小游戏上面那行说明（status）：把代码里给它的每一句都放进去量（同一个 Label、同宽）
	h.games.open("tea",h.life,{"hour":14.5,"month":10,"sound":false});for i in 3:await process_frame
	var st:Label=h.games.status;var re:=RegEx.new();re.compile('status\\.text\\s*=\\s*"([^"]+)"')
	for f in ["res://ayu_home/v4/life_games.gd"]:
		for m in re.search_all(FileAccess.get_file_as_string(f)):
			st.text=m.get_string(1);await check("小游戏说明")
	h.games.close(false)
	print("量了 %d 段字"%count)
	for b in bad:print("不行 ",b)
	print("RESULT PASS" if bad.is_empty() and count>20 else "RESULT FAIL")
	h.stop_audio();quit()
