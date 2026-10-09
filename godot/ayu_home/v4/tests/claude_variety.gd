extends SceneTree
## 14 天里饭菜、家人托的事有多少种（不加速游戏：只在隔离存档里换测试时钟）
const Life=preload("res://ayu_home/v4/life_state.gd")
func _initialize() -> void:
	var t=Life.new();t.now_override=1759600000.0;t.open({"id":"variety"},OS.get_user_data_dir()+"/variety.json");t.data.chores={}
	var menus:={};var tasks:={};var lines:=[]
	for d in 14:
		t.now_override=1759600000.0+d*86400
		var m:Array=t.meal_menu(10);menus["、".join(m)]=true
		var ts:=[]
		for q in t.daily_tasks():ts.append(q.host+":"+q.text)
		tasks[" / ".join(ts)]=true;lines.append(t.date_key()+"  "+"、".join(m)+"  ｜ "+" / ".join(ts))
	t.data.harvest_history=[{"crop":"pumpkin","at":t.now_override-3600}];lines.append("收了南瓜以后："+"、".join(t.meal_menu(10)))
	t.data.effects.soup_date=t.date_key();lines.append("今天煮了汤："+"、".join(t.meal_menu(10)))
	t.now_override+=86400*4;lines.append("四天后："+"、".join(t.meal_menu(10)))
	for l in lines:print(l)
	print("RESULT ","PASS" if menus.size()>=10 and tasks.size()>=10 else "FAIL"," 14 天菜单 ",menus.size()," 种，托的事 ",tasks.size()," 种")
	quit()
