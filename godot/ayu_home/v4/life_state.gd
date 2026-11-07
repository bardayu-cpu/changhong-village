extends RefCounted
## One household per player. All growth reads real UTC seconds, never the preview clock.
signal changed
const VERSION := 4
const CROPS := {
	"radish":{"name":"萝卜","type":"vegetable","season":0,"seconds":7200,"color":"edaaa0"},
	"pea":{"name":"豌豆","type":"vegetable","season":0,"seconds":10800,"color":"87b869"},
	"tulip":{"name":"郁金香","type":"flower","season":0,"seconds":14400,"color":"e9a2b0"},
	"peach":{"name":"桃树","type":"tree","season":0,"seconds":259200,"color":"f3b1a5"},
	"tomato":{"name":"番茄","type":"vegetable","season":1,"seconds":10800,"color":"d8735b"},
	"cucumber":{"name":"黄瓜","type":"vegetable","season":1,"seconds":14400,"color":"7d9b48"},
	"sunflower":{"name":"向日葵","type":"flower","season":1,"seconds":14400,"color":"e6bd53"},
	"plum":{"name":"李树","type":"tree","season":1,"seconds":259200,"color":"9671a4"},
	"pumpkin":{"name":"南瓜","type":"vegetable","season":2,"seconds":14400,"color":"de984f"},
	"carrot":{"name":"胡萝卜","type":"vegetable","season":2,"seconds":10800,"color":"e6a566"},
	"cosmos":{"name":"波斯菊","type":"flower","season":2,"seconds":14400,"color":"dfa7cb"},
	"apple":{"name":"苹果树","type":"tree","season":2,"seconds":259200,"color":"c97759"},
	"cabbage":{"name":"白菜","type":"vegetable","season":3,"seconds":14400,"color":"b6cf92"},
	"spinach":{"name":"菠菜","type":"vegetable","season":3,"seconds":10800,"color":"78a07b"},
	"pansy":{"name":"三色堇","type":"flower","season":3,"seconds":14400,"color":"a49ac7"},
	"kumquat":{"name":"金橘树","type":"tree","season":3,"seconds":259200,"color":"e7aa45"},
	"daisy":{"name":"雏菊","type":"flower","season":0,"seconds":14400,"color":"f1e8c9"},
	"forgetmenot":{"name":"勿忘我","type":"flower","season":0,"seconds":14400,"color":"93b6d0"},
	"zinnia":{"name":"百日菊","type":"flower","season":1,"seconds":14400,"color":"e79aab"},
	"lily":{"name":"百合","type":"flower","season":1,"seconds":14400,"color":"eee6bf"},
	"chrysanthemum":{"name":"秋菊","type":"flower","season":2,"seconds":14400,"color":"e9c568"},
	"aster":{"name":"紫菀","type":"flower","season":2,"seconds":14400,"color":"aa94c5"},
	"camellia":{"name":"山茶","type":"flower","season":3,"seconds":14400,"color":"d98a96"},
	"narcissus":{"name":"水仙","type":"flower","season":3,"seconds":14400,"color":"edeac9"}
}
## 家人托的事：每人一串，每天各挑一件（跟前一天不重样）。三个人说话各有各的样子：
## 妈妈细致、惦记吃穿；爸爸话少、手上有活；阿鱼爱猫爱拍照，说话带笑。
const TASKS := {
	"mother":[
		{"event":"soup","text":"煮一锅热汤","thanks":"闻到汤香啦。今天的饭桌又多了一道，你先盛一碗。"},
		{"event":"laundry","text":"洗好一筐衣服","thanks":"衣服晒在这里，太阳会慢慢把它们烘干。下雨记得收哦。"},
		{"event":"fold","text":"把毛巾和衣服叠整齐","thanks":"叠得方方正正的，比我叠得还好。"},
		{"event":"harvest","text":"去后园收一回菜","thanks":"这么新鲜，晚上就做给你吃。"},
		{"event":"fruit_gift","text":"摘一篮果子，留一份给家里人","thanks":"洗好放桌上了，大家路过都拿一个。"},
		{"event":"serve","text":"吃饭时给家人夹一筷子菜","thanks":"一家人吃饭，就是要你夹我、我夹你。"},
		{"event":"wash_hands","text":"饭前好好洗个手","thanks":"手洗干净了吧？来，坐下吃饭。"}
	],
	"father":[
		{"event":"wood","text":"磨好一只小木鸟","thanks":"放在窗台上吧，看着就想起你来。"},
		{"event":"tools","text":"把工具挂回墙上","thanks":"顺手多了。歇会儿，一起喝杯茶。"},
		{"event":"tree","text":"在树林里种一棵果树","thanks":"三天就能看见它长高。到时候第一个果子给你。"},
		{"event":"fishing","text":"去溪边钓一尾鱼","thanks":"钓上来了？手稳，像我。"},
		{"event":"tea","text":"沏一壶茶","thanks":"嗯，茶泡得正好，不涩。"},
		{"event":"football","text":"陪喜多踢一会儿球","thanks":"它跑累了，今晚睡得香。"},
		{"event":"puzzle","text":"把那幅拼图拼完","thanks":"我拼了一个礼拜没拼上，你一会儿就好了。"}
	],
	"ayu":[
		{"event":"pet_food","text":"给猫咪添水和猫粮","thanks":"碗里满满的，它们也在谢谢你。"},
		{"event":"flowers","text":"插一瓶家里的花","thanks":"这一瓶好有精神，放在大家都看得到的地方。"},
		{"event":"photo","text":"拍一张合照放进生活册","thanks":"这张拍得好好看！我要偷偷存一张。"},
		{"event":"pet_play","text":"陪猫咪玩一会儿","thanks":"落落今天肯定把你记住了，它可挑人了。"},
		{"event":"fish","text":"给客厅鱼缸里的鱼喂一撮食","thanks":"它们吃东西的样子是不是很可爱？"},
		{"event":"guitar","text":"弹一小段吉他给我听","thanks":"再弹一遍嘛，我想录下来。"},
		{"event":"stars","text":"去看一会儿天空","thanks":"你看到了吗？我每次看都觉得心里静下来了。"}
	]
}
const SPECIAL := {"spring":"春天的一枝花","summer":"树林里的萤火虫","autumn":"夹进书里的秋叶","winter":"露台的第一捧雪","rain":"雨天收回的衣服","snail":"院子里的小蜗牛","night":"台灯旁的猫","meal":"一桌热饭","moon":"今天的月亮","wish":"流星经过的愿望","cats":"三只猫都找到了","stay":"住进这个家"}
var shared_state
var data:Dictionary={}
var path := ""
var last_error := ""
var now_override := -1.0 # Tests inject a clock into isolated files; no gameplay control exposes this.
func now() -> float:return shared_state.now() if shared_state!=null else (now_override if now_override>=0 else Time.get_unix_time_from_system())
func date_key() -> String:return Time.get_date_string_from_unix_time(int(now())) if now_override>=0 else Time.get_date_string_from_system()
static func season(month:int) -> int:return int((month+9)%12/3)
func open(profile:Dictionary, override_path:="") -> void:
	var identity:=str(profile.get("id","local"))
	path=override_path if not override_path.is_empty() else "user://ayu_home_v4_"+identity.sha256_text().substr(0,20)+".json"
	data={"version":VERSION,"notes":[],"profile":profile.duplicate(true),"resident":false,"plots":[{},{},{},{},{},{}],"trees":[{},{}],"seeds":{},"seed_packs":[],"basket":{},"effects":{},"found":[],"completed":{},"cards":[],"photos":[],"wishes":[],"chores":{},"daily_cats":{},"invites":{},"fish":[],"flower_vase":[],"harvest_history":[],"last_seen":now(),"rev":0,"settings":{"sound":true,"gentle":true,"text_scale":1.0}}
	var saved=_read(path)
	if saved.is_empty() and FileAccess.file_exists(path):
		saved=_read(path+".bak");last_error="存档恢复好了"
	if not saved.is_empty() and saved.get("version",0)==VERSION:
		for key in data:
			if saved.has(key) and typeof(saved[key])==typeof(data[key]):data[key]=saved[key]
		data.profile=profile.duplicate(true)
	if data.plots.size()!=6:data.plots=[{},{},{},{},{},{}]
	if data.trees.size()!=2:data.trees=[{},{}]
	base=data.duplicate(true)
	# 同一份存档是不是已经在别的窗口开着（那个窗口每几秒在旁边的小文件里记一下「我还开着」）
	var other:=_read_open()
	another_open=not other.is_empty() and str(other.get("who",""))!=who and now_real()-float(other.get("at",0))<20
	touch_open()
## 「我还开着」：每几秒记一次，关的时候删掉
func touch_open() -> void:
	if _browser_lock():
		# Presence is ephemeral cross-tab state, not a saved household file.
		# Removing an IDBFS .open file during an in-flight scan caused ENOENT
		# and aborted the whole save transaction when leaving the village.
		var value := JSON.stringify({"who":who,"at":now_real()})
		JavaScriptBridge.eval("try{localStorage.setItem(%s,%s)}catch(_){}" % [JSON.stringify(_open_key()),JSON.stringify(value)],true)
		return
	var f:=FileAccess.open(path+".open",FileAccess.WRITE)
	if f:f.store_string(JSON.stringify({"who":who,"at":now_real()}));f.close()
func close_open() -> void:
	if _browser_lock():
		JavaScriptBridge.eval("try{const k=%s;const v=JSON.parse(localStorage.getItem(k)||'{}');if(v.who===%s)localStorage.removeItem(k)}catch(_){}" % [JSON.stringify(_open_key()),JSON.stringify(who)],true)
		return
	var other:=_read(path+".open")
	if str(other.get("who",""))==who:DirAccess.remove_absolute(path+".open")
func _browser_lock() -> bool:
	return OS.has_feature("web") and not OS.has_feature("hongyuan_wechat")
func _open_key() -> String:
	return "ayu-home-open:"+ProjectSettings.globalize_path(path)
func _read_open() -> Dictionary:
	if _browser_lock():
		var text := str(JavaScriptBridge.eval("(()=>{try{return localStorage.getItem(%s)||'{}'}catch(_){return '{}'}})()" % JSON.stringify(_open_key()),true))
		var value: Variant = JSON.parse_string(text)
		return value if value is Dictionary else {}
	return _read(path+".open")
func now_real() -> float:return Time.get_unix_time_from_system()
## 合并：存之前先读磁盘上的存档。别的窗口在我上次读 / 存之后存过（rev 变大），就三方合并：
## 我这边没动过的，用磁盘上的；磁盘上没动过的，用我的；两边都动了的，列表合在一起、开关取「做过」、次数取大的，其余用我的。
## 这样闲着的窗口换房间、关掉，不会把另一个窗口里刚做的事（留宿、摘的果子）盖掉。
static func merge3(b,mine,disk):
	if typeof(mine)!=typeof(disk):return mine
	if mine==b:return disk
	if disk==b:return mine
	match typeof(mine):
		TYPE_DICTIONARY:
			var out:Dictionary={};var bd:Dictionary=b if b is Dictionary else {}
			for k in mine.keys()+disk.keys():
				if out.has(k):continue
				if not disk.has(k):
					if not (bd.has(k) and mine[k]==bd[k]):out[k]=mine[k] # 磁盘上删掉了、我这边也没动：跟着删
				elif not mine.has(k):
					if not (bd.has(k) and disk[k]==bd[k]):out[k]=disk[k]
				else:out[k]=merge3(bd.get(k),mine[k],disk[k])
			return out
		TYPE_ARRAY:
			if b is Array and mine.size()==b.size() and disk.size()==b.size():
				var out:Array=[]
				for i in mine.size():out.append(merge3(b[i],mine[i],disk[i]))
				return out
			var out:Array=disk.duplicate(true);var seen:={}
			for x in disk:seen[JSON.stringify(x)]=true
			for x in mine:
				if not seen.has(JSON.stringify(x)):out.append(x)
			return out
		TYPE_BOOL:return mine or disk
		TYPE_INT,TYPE_FLOAT:return maxf(mine,disk) if typeof(mine)==TYPE_FLOAT else maxi(mine,disk)
	return mine
func _read(file:String) -> Dictionary:
	if not FileAccess.file_exists(file):return {}
	var parser:=JSON.new()
	if parser.parse(FileAccess.get_file_as_string(file))!=OK:return {}
	return parser.data if parser.data is Dictionary else {}
## 存档：先写到这个窗口自己的临时文件，再整个换上去。
## 好几个阿鱼家窗口同时开着时，原来大家共用一个临时文件，会互相抢走对方的、冒出「暂时没能保存」（实测两个窗口各存 400 次，约一成失败）。
## 现在每个窗口、每次存都用自己的临时文件，换不上就再试几次；真的连着存不上才说一句，话也说得软一点。
var save_failures:=0
var base:Dictionary={}
var another_open:=false
var who:=str(OS.get_process_id())+"-"+str(randi()) # 这个窗口自己的记号
var merged_count:=0
var save_serial:=0
func save() -> bool:
	if shared_state!=null:
		var stock_delta:Dictionary={}
		for key in ["basket","seeds"]:
			for id in data[key]:
				var delta:=int(data[key].get(id,0))-int(base.get(key,{}).get(id,0))
				if delta!=0:
					var stock_id:String=str(id)+("_seed" if key=="seeds" else "")
					stock_delta[stock_id]=int(stock_delta.get(stock_id,0))+delta
		var result:Dictionary=shared_state.act("household",{"data":data,"stock_delta":stock_delta})
		if not result.ok and not shared_state.data.village.household.is_empty():data=shared_state.data.village.household.duplicate(true)
		sync_inventory()
		attempt_done(result.ok);return bool(result.ok)
	save_serial+=1
	var disk:=_read(path)
	if not disk.is_empty() and int(disk.get("rev",0))>int(base.get("rev",0)) and disk.get("version",0)==VERSION:
		var merged=merge3(base,data,disk)
		for k in merged:data[k]=merged[k]
		data.profile=base.get("profile",data.profile);merged_count+=1
	data.rev=maxi(int(data.get("rev",0)),int(disk.get("rev",0)))+1
	var tmp:=path+".tmp"+str(OS.get_process_id())+"-"+str(save_serial)
	var ok:=false
	# 手机上（微信小游戏的内存文件系统）改名、拷贝不落盘，只有写完关掉的文件才存下来（C3 10/5 在模拟器里查到只剩 .tmp）：
	# 先把旧存档的字节写成 .bak，再直接写正式存档，读回来对就算存上。电脑上照旧「写临时文件再改名」
	if OS.has_feature("web") or OS.has_feature("wechat"):
		var old:=FileAccess.get_file_as_bytes(path)
		if not old.is_empty():
			var b:=FileAccess.open(path+".bak",FileAccess.WRITE)
			if b:b.store_buffer(old);b.close()
		for attempt in 3:
			var direct:=FileAccess.open(path,FileAccess.WRITE)
			if not direct:continue
			direct.store_string(JSON.stringify(data));direct.close()
			if int(_read(path).get("rev",-1))==int(data.rev):ok=true;break
		attempt_done(ok);return ok
	for attempt in 3:
		var file:=FileAccess.open(tmp,FileAccess.WRITE)
		if not file:continue
		file.store_string(JSON.stringify(data));file.flush();file.close()
		if attempt==0 and not _read(path).is_empty():DirAccess.copy_absolute(path,path+".bak")
		if DirAccess.rename_absolute(tmp,path)==OK:ok=true;break
	if FileAccess.file_exists(tmp):DirAccess.remove_absolute(tmp)
	attempt_done(ok);return ok
func attempt_done(ok:bool) -> void:
	if ok:base=data.duplicate(true)
	save_failures=0 if ok else save_failures+1
	last_error="" if save_failures<3 else "没存上，等会儿自动再存"
	changed.emit()
func pack_seeds(month:int) -> bool:
	var key:=Time.get_date_string_from_unix_time(int(now())).substr(0,4)+"-"+str(season(month))
	if data.seed_packs.has(key):return false
	for id in CROPS:
		if CROPS[id].season==season(month):data.seeds[id]=int(data.seeds.get(id,0))+(2 if CROPS[id].type=="tree" else 6)
	data.seed_packs.append(key)
	# A one-time welcome basket gives the first visit a complete kitchen/florist loop.
	if data.seed_packs.size()==1:
		for id in CROPS:
			if CROPS[id].season==season(month):
				data.basket[id]=3 if CROPS[id].type!="tree" else 2
		data.effects["welcome_basket"]=true
	save();return true
func available(month:int,kind:="") -> Array:
	var out:Array=[]
	for id in CROPS:
		if CROPS[id].season==season(month) and (kind.is_empty() or CROPS[id].type==kind):out.append(id)
	return out
func till(index:int,tree:=false) -> bool:
	var rows:Array=data.trees if tree else data.plots
	if index<0 or index>=rows.size() or not rows[index].is_empty():return false
	rows[index]={"tilled":true};save();return true
func plant(index:int,crop:String,month:int,tree:=false) -> bool:
	if not CROPS.has(crop) or CROPS[crop].season!=season(month) or int(data.seeds.get(crop,0))<1:return false
	if (CROPS[crop].type=="tree")!=tree:return false
	var rows:Array=data.trees if tree else data.plots
	if index<0 or index>=rows.size() or not rows[index].get("tilled",false) or rows[index].has("crop"):return false
	rows[index]={"tilled":true,"crop":crop,"planted":now(),"watered":false}
	data.seeds[crop]-=1;save();return true
func water(index:int,tree:=false) -> bool:
	var rows:Array=data.trees if tree else data.plots
	if index<0 or index>=rows.size() or not rows[index].has("crop") or rows[index].get("watered",false):return false
	rows[index].watered=true;rows[index].watered_at=now();save();return true
func growth(plot:Dictionary) -> float:
	if not plot.has("crop") or not plot.get("watered",false):return 0.0
	return clampf((now()-maxf(float(plot.planted),float(plot.get("watered_at",plot.planted))))/float(CROPS[plot.crop].seconds),0,1)
func stage(plot:Dictionary) -> String:
	if plot.is_empty():return "未翻土"
	if not plot.has("crop"):return "松软的土"
	if not plot.get("watered",false):return "等一壶水"
	var g:=growth(plot)
	if plot.get("grown",false):return "果子熟了" if g>=1 else ("新果在长" if g>=.65 else "等下一批果子")
	return "可以采收" if g>=1 else ("含苞 / 结果" if g>=.65 else ("长出叶子" if g>=.3 else "刚刚发芽"))
## 菜地格子上用的短写法（2～3 个字，24 号字一行放得下，跟菜名排一行）；跟下面按钮同一个词（翻土、播种、浇水），长辈一看就知道点哪个（002）
func stage_short(plot:Dictionary) -> String:
	if plot.is_empty():return "要翻土"
	if not plot.has("crop"):return "能播种"
	if not plot.get("watered",false):return "要浇水"
	var g:=growth(plot)
	if plot.get("grown",false):return "熟了" if g>=1 else ("结果中" if g>=.65 else "等新果")
	return "能收了" if g>=1 else ("开花" if g>=.65 else ("长叶" if g>=.3 else "发芽"))
func harvest(index:int,tree:=false) -> Dictionary:
	var rows:Array=data.trees if tree else data.plots
	if index<0 or index>=rows.size() or growth(rows[index])<1:return {}
	var crop:String=rows[index].crop
	data.basket[crop]=int(data.basket.get(crop,0))+2
	data.seeds[crop]=int(data.seeds.get(crop,0))+1
	data.harvest_history.append({"crop":crop,"at":now()})
	if tree:rows[index].planted=now();rows[index].watered_at=now();rows[index].grown=true
	else:rows[index]={}
	event("harvest");save();return {"crop":crop,"count":2,"seed":1}
func fruit_pick(month:int) -> Dictionary:
	var id:String=available(month,"tree")[0]
	var key:="fruit_"+date_key()+"_"+id
	if data.effects.has(key):return {}
	data.effects[key]=true;data.basket[id]=int(data.basket.get(id,0))+3;event("fruit");save()
	return {"crop":id,"count":3}
func take(crop:String,count:=1) -> bool:
	if int(data.basket.get(crop,0))<count:return false
	data.basket[crop]-=count;save();return true
func discover(id:String) -> void:
	if not data.found.has(id):data.found.append(id);save()
func card(id:String) -> void:
	if not data.cards.has(id):data.cards.append(id);save()
## 第几天（按日期算，不看时区里的钟点），用来让每天的安排都不一样
static func day_number(day:String) -> int:return int(Time.get_unix_time_from_datetime_string(day+"T12:00:00")/86400)
func daily_tasks() -> Array:
	var key:=date_key()
	if not data.chores.has(key):
		var n:=day_number(key);var list:Array=[]
		# 每人每天换一件；三个人换的步子不一样，七天里凑不出同一组
		var steps:={"mother":[3,0],"father":[2,3],"ayu":[5,1]}
		for host in ["mother","father","ayu"]:
			var pool:Array=TASKS[host];var pick:int=posmod(n*int(steps[host][0])+int(n/7)*int(steps[host][1]),pool.size())
			var q:Dictionary=pool[pick].duplicate(true);q.host=host;q.merge({"accepted":false,"done":false,"thanked":false});list.append(q)
		data.chores[key]=list
	return data.chores[key]
func event(id:String) -> void:
	data.completed[id]=int(data.completed.get(id,0))+1
	for q in daily_tasks():
		if q.event==id:q.done=true
	save()
func pet(id:String) -> void:
	var key:=date_key()
	if not data.daily_cats.has(key):data.daily_cats[key]=[]
	if id!="xiduo" and not data.daily_cats[key].has(id):data.daily_cats[key].append(id)
	if data.daily_cats[key].size()==3:card("cats")
	event("pet_"+id)
func cats_today() -> int:return data.daily_cats.get(date_key(),[]).size()
## 饭菜：每天一荤（或蛋、豆腐）一素一汤，跟着季节换，前一天吃过的今天换一道；
## 这三天里你收过的菜会被做成菜端上桌；今天一起煮过汤，汤就是那锅汤。
## pic 是 astra 画的 16 张菜图里最像的那张。
const DISHES := {
	"春笋豆腐":{"pic":0,"kind":"main","season":[0]},"香椿炒蛋":{"pic":12,"kind":"main","season":[0]},"韭菜鸡蛋饼":{"pic":12,"kind":"main","season":[0]},
	"豌豆蒸蛋":{"pic":1,"kind":"veg","season":[0],"crop":"pea"},"清炒豌豆尖":{"pic":10,"kind":"veg","season":[0]},"萝卜丝饼":{"pic":14,"kind":"veg","season":[0],"crop":"radish"},
	"萝卜清汤":{"pic":2,"kind":"soup","season":[0],"crop":"radish"},"腌笃鲜":{"pic":5,"kind":"soup","season":[0]},"荠菜豆腐羹":{"pic":8,"kind":"soup","season":[0]},
	"番茄炒蛋":{"pic":3,"kind":"main","season":[1],"crop":"tomato"},"毛豆炒肉丁":{"pic":14,"kind":"main","season":[1]},"黄瓜炒蛋":{"pic":3,"kind":"main","season":[1]},
	"清拌黄瓜":{"pic":4,"kind":"veg","season":[1],"crop":"cucumber"},"凉拌茄子":{"pic":14,"kind":"veg","season":[1]},"蒜蓉空心菜":{"pic":10,"kind":"veg","season":[1]},
	"冬瓜汤":{"pic":5,"kind":"soup","season":[1]},"丝瓜蛋汤":{"pic":11,"kind":"soup","season":[1]},"番茄蛋花汤":{"pic":2,"kind":"soup","season":[1],"crop":"tomato"},
	"板栗烧鸡":{"pic":13,"kind":"main","season":[2]},"胡萝卜炒肉丝":{"pic":14,"kind":"main","season":[2],"crop":"carrot"},"桂花糯米藕":{"pic":13,"kind":"main","season":[2]},
	"南瓜小盅":{"pic":6,"kind":"veg","season":[2],"crop":"pumpkin"},"胡萝卜焖饭":{"pic":7,"kind":"veg","season":[2],"crop":"carrot"},"清炒藕片":{"pic":10,"kind":"veg","season":[2]},
	"菌菇清汤":{"pic":8,"kind":"soup","season":[2]},"莲藕排骨汤":{"pic":5,"kind":"soup","season":[2]},"南瓜小米粥":{"pic":6,"kind":"soup","season":[2],"crop":"pumpkin"},
	"白菜炖豆腐":{"pic":9,"kind":"main","season":[3],"crop":"cabbage"},"萝卜炖牛腩":{"pic":11,"kind":"main","season":[3]},"红烧豆腐":{"pic":13,"kind":"main","season":[3]},
	"清炒菠菜":{"pic":10,"kind":"veg","season":[3],"crop":"spinach"},"白菜粉丝煲":{"pic":9,"kind":"veg","season":[3],"crop":"cabbage"},"醋溜白菜":{"pic":10,"kind":"veg","season":[3],"crop":"cabbage"},
	"热乎萝卜汤":{"pic":11,"kind":"soup","season":[3]},"菠菜蛋花汤":{"pic":11,"kind":"soup","season":[3],"crop":"spinach"},"酸菜粉丝汤":{"pic":5,"kind":"soup","season":[3]},
	"葱香煎蛋":{"pic":12,"kind":"main","season":[0,1,2,3]},"家常豆腐":{"pic":13,"kind":"main","season":[0,1,2,3]},"清蒸时蔬":{"pic":14,"kind":"veg","season":[0,1,2,3]},
	"一起煮的家常汤":{"pic":15,"kind":"soup","season":[]}
}
static func dish_picture(name:String) -> int:return int(DISHES.get(name.get_slice("（",0),{}).get("pic",14))
func _pool(kind:String,month:int) -> Array:
	var pool:Array=[]
	for dish in DISHES:
		if DISHES[dish].kind==kind and season(month) in DISHES[dish].season:pool.append(dish)
	return pool
func meal_menu(month:int) -> Array:
	var day:=date_key();var n:=day_number(day);var menu:Array=[]
	# 荤、素、汤各走各的步子：相邻两天每道都换，两个月里凑不出同一桌
	for item in [["main",2],["veg",3],["soup",1]]:
		var pool:=_pool(item[0],month);menu.append(pool[posmod(n*int(item[1]),pool.size())])
	# 这三天收过的菜（最近收的在前）：有对应的家常菜就端上来，标上是你种的
	var recent:Array=[]
	for record in data.harvest_history:
		if CROPS.has(record.crop) and CROPS[record.crop].type=="vegetable" and now()-float(record.at)<259200 and not recent.has(record.crop):recent.push_front(record.crop)
	var used:=0
	for crop in recent:
		if used>=2:break
		var dishes:Array=[]
		for dish in DISHES:
			if DISHES[dish].get("crop","")==crop and DISHES[dish].kind!="soup":dishes.append(dish)
		if dishes.is_empty():continue
		var dish:String=dishes[absi((day+crop).hash())%dishes.size()];var slot:=0 if DISHES[dish].kind=="main" else 1
		if str(menu[slot]).contains("（"):slot=1-slot
		menu[slot]=dish+"（你种的"+CROPS[crop].name+"）";used+=1
	if str(data.effects.get("soup_date",""))==day:menu[2]="一起煮的家常汤"
	return menu
func invite_key(hour:float) -> String:
	var slot:="早餐" if hour>=7.5 and hour<8.25 else ("午饭" if hour>=12 and hour<13 else ("晚饭" if hour>=18 and hour<19 else ""))
	return date_key()+"_"+slot if not slot.is_empty() else ""
func keep_photo(photo:Dictionary) -> void:
	data.photos.append(photo.duplicate(true));event("photo");save()
func wish(text:String,moon:float) -> void:
	data.wishes.append({"text":text.left(80),"at":now(),"moon":moon});card("wish");save()
func moon_phase() -> float:return fposmod((now()-947182440.0)/86400.0,29.530588853)/29.530588853

func sync_inventory() -> void:
	if shared_state==null:return
	var basket:Dictionary={};var seeds:Dictionary={}
	for id in CROPS:
		if shared_state.count(id)>0:basket[id]=shared_state.count(id)
		seeds[id]=shared_state.count(str(id)+"_seed")
	data.basket=basket;data.seeds=seeds
	base.basket=basket.duplicate(true);base.seeds=seeds.duplicate(true)
