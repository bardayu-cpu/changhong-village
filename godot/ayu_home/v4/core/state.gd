extends RefCounted
## 共用存档形状；本模块只写 village、经动作写 wallet / renqing。双槽校验写入，不依赖微信 rename。
signal changed
const C=preload("res://ayu_home/v4/core/config.gd")
var data:Dictionary={}
var path:=""
var error:=""
var now_override:=-1.0
var rng:=RandomNumberGenerator.new()
var blocked:=false
func raw_now() -> float:return now_override if now_override>=0 else Time.get_unix_time_from_system()
func now() -> float:return maxf(raw_now(),float(data.get("village",{}).get("clock",raw_now())))
func local_date() -> Dictionary:
	return Time.get_datetime_dict_from_unix_time(int(now())+int(Time.get_time_zone_from_system().bias)*60)
func date_key() -> String:
	var d:=local_date();return "%04d-%02d-%02d"%[d.year,d.month,d.day]
func isMarketDay() -> bool:return int(local_date().day)%2==1
func season() -> String:return ["冬","春","夏","秋"][int(local_date().month)%12/3]
func slot() -> String:
	var d:=local_date();var h:float=d.hour+d.minute/60.0
	return "早" if h>=6 and h<10 else ("日" if h>=10 and h<18 else ("傍晚" if h>=18 and h<19.5 else ("夜游" if h>=19.5 and h<20.5 else "夜")))
func open(profile:Dictionary,override_path:="") -> bool:
	var identity:=str(profile.get("openid",profile.get("id","local")))
	path=override_path if not override_path.is_empty() else "user://village_shared_"+identity.sha256_text().substr(0,20)
	var disk:=read_latest()
	if disk.is_empty() and (FileAccess.file_exists(path+".a") or FileAccess.file_exists(path+".b")):
		blocked=true;error="存档暂时读不出来，请保留文件交回复查";return false
	if not disk.is_empty():
		if int(disk.get("version",0))!=1 or str(disk.get("openid",""))!=identity:
			blocked=true;error="存档版本或玩家身份不匹配";return false
		data=disk;upgrade();return true
	rng.randomize()
	data={"version":1,"openid":identity,"profile":profile.duplicate(true),"wallet":{"coins":0,"ledger":[]},"calendar":{"test_clock":{"enabled":false},"events":[]},"renqing":[],"manor":{},"town":{},"village":{"version":1,"revision":0,"clock":raw_now(),"rng":str(rng.state),"items":C.START_ITEMS.duplicate(true),"animals":{},"crops":[{},{},{},{},{},{}],"stations":{"stove":{},"mill":{}},"orders":{},"order_total":0,"resident":false,"location":"","land":[0,0,0],"blueprints":[],"furniture":[],"next_id":1,"visits":[],"history":[],"first_supply":0}}
	# 初次到家时动物已经从上一趟回来；收取后严格等 300 秒，离线最多一趟。
	for pet in C.PETS:data.village.animals[pet]={"due":raw_now(),"trips":0}
	upgrade()
	return persist()
func upgrade() -> void:
	var defaults={"household":{},"producers":{"honey":{},"pond":{},"chicken":{},"orchard":{}},"helped":{},"chores":{},"memories":[],"market":{},"box_misses":0,"animal_misses":0,"first_day":date_key(),"last_area":"exterior","last_position":[],"season":"","weather":"","migration":{}}
	for key in defaults:
		if not data.village.has(key):data.village[key]=defaults[key]
	for key in ["institutions","active_institution"]:
		if not data.village.has(key):data.village[key]={}
	if not data.village.has("first_supply"):data.village.first_supply=C.FIRST_TRIP_SLOTS # 旧档不补发新档保底。
	if not data.village.has("institution_runs"):data.village.institution_runs=0
	if int(data.village.get("version",1))<2:data.village.version=2
func read_latest() -> Dictionary:
	var latest:Dictionary={}
	for ext in [".a",".b"]:
		if not FileAccess.file_exists(path+ext):continue
		var parser:=JSON.new()
		if parser.parse(FileAccess.get_file_as_string(path+ext))!=OK:continue
		var box=parser.data
		if not box is Dictionary or not box.get("payload") is String:continue
		if str(box.get("sha256",""))!=str(box.payload).sha256_text():continue
		var value=JSON.parse_string(box.payload)
		if not value is Dictionary or not value.get("village") is Dictionary:continue
		if latest.is_empty() or int(value.village.get("revision",0))>int(latest.village.get("revision",0)):latest=value
	return latest
func persist() -> bool:
	data.village.revision=int(data.village.revision)+1
	var payload:=JSON.stringify(data)
	var dest:=path+(".a" if int(data.village.revision)%2==1 else ".b")
	var f:=FileAccess.open(dest,FileAccess.WRITE)
	if f==null:error="保存没成功，这次操作没有扣除或发放物品";return false
	f.store_string(JSON.stringify({"payload":payload,"sha256":payload.sha256_text()}));f.flush();var ok:=f.get_error()==OK;f.close()
	if not ok or read_latest()!=JSON.parse_string(payload):error="保存校验失败，请重试";return false
	return true
func count(id:String) -> int:return int(data.village.items.get(id,0))
func put(id:String,n:int) -> void:data.village.items[id]=count(id)+n
func has_items(items:Dictionary) -> bool:
	for id in items:if count(id)<int(items[id]):return false
	return true
func take(items:Dictionary) -> void:
	for id in items:put(id,-int(items[id]))
func wallet_add(delta:int,src:String,line:="village") -> bool:
	if delta<=0:return false
	data.wallet.coins=int(data.wallet.coins)+delta
	data.wallet.ledger.append({"t":now(),"delta":delta,"src":src,"line":line});return true
func wallet_spend(delta:int,src:String,line:="village") -> bool:
	if delta<0 or int(data.wallet.coins)<delta:return false
	data.wallet.coins=int(data.wallet.coins)-delta
	if delta>0:data.wallet.ledger.append({"t":now(),"delta":-delta,"src":src,"line":line})
	return true
func renqing_add(who:String,what:String) -> void:data.renqing.append({"with":who,"what":what,"where":"village","t":now()})
func remaining(due:float) -> int:return maxi(0,int(ceil(due-now())))
func orders() -> Array:
	var list:Array=[];var day:=date_key()
	var serial:=int(Time.get_unix_time_from_datetime_string(day+"T00:00:00")/86400)
	var epoch:=int(Time.get_unix_time_from_datetime_string(C.ORDER_EPOCH+"T00:00:00")/86400)
	var cohort:=posmod(serial-epoch,C.ORDER_ROTATION_DAYS)
	for offset in C.DAILY_ORDER_COUNT:
		var i:int=cohort*C.DAILY_ORDER_COUNT+offset
		var order:Dictionary=C.ORDERS[i].duplicate(true);order.id=day+":"+str(order.key)
		# 原四单数组索引历史继续有效，升级不让当日已经交过的单重领。
		var legacy:=day+":"+str(i) if i<4 else ""
		order.done=data.village.orders.has(order.id) or (not legacy.is_empty() and data.village.orders.has(legacy));list.append(order)
	return list
func act(command:String,args:Dictionary={}) -> Dictionary:
	if blocked:return {"ok":false,"message":error}
	var disk:=read_latest()
	if not disk.is_empty() and int(disk.village.revision)!=int(data.village.revision):
		data=disk;changed.emit();return {"ok":false,"message":"另一窗口已保存，已更新内容，请再点一次"}
	var before:=data.duplicate(true)
	data.village.clock=now();rng.state=int(data.village.rng)
	var result:=execute(command,args)
	if not result.get("ok",false):data=before;return result
	data.village.rng=str(rng.state)
	if not persist():data=before;return {"ok":false,"message":error}
	changed.emit();return result
func fail(message:String) -> Dictionary:return {"ok":false,"message":message}
func success(message:String) -> Dictionary:return {"ok":true,"message":message}
func execute(command:String,a:Dictionary) -> Dictionary:
	var v:Dictionary=data.village
	match command:
		"institution_begin":
			var id:=str(a.get("game",""))
			if not C.INSTITUTION_GAMES.has(id):return fail("这里没有这项小玩法")
			var game:Dictionary=C.INSTITUTION_GAMES[id]
			if not has_items(game.input):return fail("还缺："+missing_text(game.input))
			if game.daily and v.orders.has("institution-day:"+id+":"+date_key()):return fail("今天的这份已经收好，明天再来帮忙")
			v.institution_runs=int(v.institution_runs)+1
			v.active_institution={"game":id,"run":str(v.institution_runs),"progress":0}
			return success("准备好了，做完再收进篮子")
		"institution_step":
			var run:Dictionary=v.active_institution
			if run.is_empty() or str(a.get("run",""))!=str(run.run):return fail("这次小玩法已经结束")
			if int(a.get("step",-1))!=int(run.progress):return fail("这一步已经做过了")
			if int(run.progress)>=int(C.INSTITUTION_GAMES[run.game].steps):return fail("已经做好，可以收起了")
			run.progress=int(run.progress)+1;return success("再慢慢做下一步")
		"institution_cancel":
			if v.active_institution.is_empty() or str(a.get("run",""))!=str(v.active_institution.run):return fail("这次小玩法已经结束")
			v.active_institution={};return success("先放下，原料和篮子都没有变化")
		"institution_complete":
			var run:Dictionary=v.active_institution
			if run.is_empty() or str(a.get("run",""))!=str(run.run):return fail("这一份已经收好或放下了")
			var game:Dictionary=C.INSTITUTION_GAMES[run.game];var tx:="institution:"+str(run.run)
			if int(run.progress)<int(game.steps):return fail("还没做完，先继续手里的活")
			if v.orders.has(tx):return fail("这一份已经收好")
			if not has_items(game.input):return fail("篮子变化了，还缺："+missing_text(game.input))
			var day_key:="institution-day:"+str(run.game)+":"+date_key()
			if game.daily and v.orders.has(day_key):return fail("今天的这份已经收好")
			take(game.input)
			for item in game.output:put(item,int(game.output[item]))
			v.orders[tx]=now()
			if game.daily:v.orders[day_key]=now()
			var id:=str(run.game)
			if not v.institutions.has(id):v.institutions[id]={}
			v.institutions[id].completed=int(v.institutions[id].get("completed",0))+1
			renqing_add(game.host,"一起做完了"+str(game.title));v.active_institution={}
			return success("收好了："+describe(game.output)+"，已放进同一个篮子")
		"institution_effect":
			var room:=str(a.get("room",""));var spot:=str(a.get("spot",""))
			if not C.INSTITUTION_ROOMS.has(room) or not spot in C.INSTITUTION_ROOMS[room].actions:return fail("这里没有这件事")
			if not v.institutions.has(room):v.institutions[room]={}
			var effects:Dictionary=v.institutions[room];effects[spot]=int(effects.get(spot,0))+1
			var daily_key:=date_key()+":"+room+":"+spot
			if not v.chores.has(daily_key):renqing_add(C.INSTITUTION_ROOMS[room].host,"在这里帮忙："+spot);v.chores[daily_key]=true
			return success(str(a.get("message","这件小事收拾好了")))
		"import_household_inventory":
			if v.get("inventory_migrated",false):return fail("家庭物品已迁入")
			var household:Dictionary=a.get("data",{})
			for id in household.get("basket",{}):put(id,int(household.basket[id]))
			for id in household.get("seeds",{}):put(str(id)+"_seed",int(household.seeds[id]))
			v.inventory_migrated=true;return success("家庭物品已并入同一个篮子")
		"fishing_reward":
			var tx:="fishing:"+str(a.get("id",""))
			if v.orders.has(tx):return fail("这一尾已经收好了")
			v.orders[tx]=now();put("fish",1);return success("新钓的鱼放入篮子")
		"household":
			var delta:Dictionary=a.get("stock_delta",{})
			for id in delta:
				if count(id)+int(delta[id])<0:return fail("篮子已变化，已重新核对物品")
			for id in delta:put(id,int(delta[id]))
			v.household=a.get("data",{}).duplicate(true);return success("家里的日子已保存")
		"checkpoint":
			v.last_area=str(a.get("area","exterior"));v.last_position=a.get("position",[]);return success("位置已记住")
		"weather":
			v.season=str(a.get("season",""));v.weather=str(a.get("weather",""));return success("记住了窗外的天气")
		"producer_start":
			var id:=str(a.get("id",""))
			if not C.PRODUCERS.has(id):return fail("没有这个生产场所")
			if not v.producers[id].is_empty():return fail("这里已经在忙，完成后先收取")
			var c:Dictionary=C.PRODUCERS[id]
			if not has_items(c.input):return fail("还缺："+missing_text(c.input))
			take(c.input);v.producers[id]={"due":now()+c.seconds};return success(c.name+"照料好了，忙自己的事去吧")
		"producer_collect":
			var id:=str(a.get("id",""))
			if not C.PRODUCERS.has(id) or v.producers[id].is_empty():return fail("先照料这里")
			if remaining(v.producers[id].due)>0:return fail("还要再等一会儿")
			var c:Dictionary=C.PRODUCERS[id];put(c.output,c.yield);v.producers[id]={};return success("收好了"+c.name+"的收获，放入同一个篮子")
		"neighbour":
			var id:=str(a.get("id",""))
			if not C.NEIGHBOURS.has(id):return fail("没有这张便签")
			var c:Dictionary=C.NEIGHBOURS[id].duplicate(true);c.request=neighbour_request(id);var key:=date_key()+":"+id
			if v.chores.has(key):return fail("今天已经帮过忙了，坐下来聊一会儿吧")
			if not has_items(c.request):return fail("还缺："+missing_text(c.request))
			take(c.request);v.chores[key]=true;v.helped[id]=int(v.helped.get(id,0))+1
			renqing_add(c.name,"收到了你带来的"+describe(c.request));return success(c.name+"记住了你的帮助，这份人情留在村里")
		"house_help":
			var id:=str(a.get("id",""));var key:=date_key()+":house:"+id
			if v.chores.has(key):return fail("今天已经收拾好了。你的来访记在这里")
			v.chores[key]=true;v.helped["house:"+id]=int(v.helped.get("house:"+id,0))+1
			v.memories.append({"date":date_key(),"place":str(a.get("title",id)),"text":str(a.get("text","来串了门"))})
			return success(str(a.get("text","已经收拾好了")))
		"season_help":
			var key:=date_key()+":season"
			if v.chores.has(key):return fail("今天的季节小事已经做完，明天还会有新的便签")
			var wet:bool=str(a.get("weather","")) in ["rain","snow"];var need:Dictionary=C.SEASON_REQUESTS.wet if wet else C.SEASON_REQUESTS.dry
			if not has_items(need):return fail("今天"+("给鸟留一把谷子：" if wet else "分享一份时令果：")+missing_text(need))
			take(need);v.chores[key]=true;renqing_add("村里的邻居","雨雪天添谷子" if wet else "分享了"+str(a.get("season",""))+"的果子");return success("这件小事记下了，邻居记着这份人情")
		"sell":
			var id:=str(a.get("id",""))
			if not id in ["radish","pepper","grain","honey","fish","egg","fruit"] or count(id)<1:return fail("篮子里还没有这份收获")
			put(id,-1);wallet_add(C.FOOD_SALE_COINS,"order");return success("放进邻里食材柜，收到 %d 金币"%C.FOOD_SALE_COINS)
		"market_buy":
			if not isMarketDay():return fail("今天歇场；普通种子可在种子篮换")
			var goods:=market_goods();var id:=str(a.get("id",""))
			if not goods.has(id):return fail("今天没带这件货")
			if not wallet_spend(goods[id],"decor"):return fail("金币不够")
			put(id,1);return success("货郎把东西包好了")
		"wallet.add","wallet.spend","renqing.add":
			var tx:=str(a.get("transaction_id",""))
			if tx.is_empty():return fail("跨线动作需要唯一流水号")
			if not v.has("shared_transactions"):v.shared_transactions={}
			if v.shared_transactions.has(tx):return fail("这笔动作已经保存")
			if command=="renqing.add":renqing_add(str(a.get("with","")),str(a.get("what","")))
			else:
				var delta:=int(a.get("delta",0));var src:=str(a.get("src",""));var line:=str(a.get("line","village"))
				if delta<=0 or src.is_empty() or not line in ["village","manor","town"]:return fail("流水参数不正确")
				if command=="wallet.add":wallet_add(delta,src,line)
				elif not wallet_spend(delta,src,line):return fail("insufficient")
			v.shared_transactions[tx]=now();return success("已保存")
		"visit":
			if not date_key() in v.visits:v.visits.append(date_key())
			return success("回来啦")
		"animal":
			var id:=str(a.get("id",""))
			if not v.animals.has(id):return fail("找不到这只动物")
			if remaining(v.animals[id].due)>0:return fail("它还在路上，回来后再收")
			var got:Dictionary={}
			for i in C.ANIMAL_ITEMS:
				var roll:=rng.randi_range(1,100);var total:=0;var picked:=""
				if i==3 and int(v.animal_misses)>=C.ANIMAL_TOOL_MISSES:roll=1
				for entry in C.LOOT:
					total+=entry.weight
					if roll<=total:picked=entry.id;break
				if int(v.first_supply)<C.FIRST_TRIP_GUARANTEE.size():picked=C.FIRST_TRIP_GUARANTEE[int(v.first_supply)]
				put(picked,1);got[picked]=int(got.get(picked,0))+1;v.first_supply=mini(C.FIRST_TRIP_SLOTS,int(v.first_supply)+1)
			v.animal_misses=0 if got.has("tool") else int(v.animal_misses)+1
			v.animals[id]={"due":now()+C.ANIMAL_SECONDS,"trips":int(v.animals[id].trips)+1}
			v.history.append({"kind":"animal","who":id,"items":got,"at":now()})
			return success(C.PETS[id]+"带回："+describe(got)+"。它又出门啦")
		"plant":
			var i:=int(a.get("plot",-1));var crop:=str(a.get("crop",""))
			if i<0 or i>=v.crops.size() or not C.CROPS.has(crop):return fail("先选一块地和种子")
			if not v.crops[i].is_empty():return fail("这块地已经种好了")
			var cfg:Dictionary=C.CROPS[crop]
			if count(cfg.seed)<1:return fail("种子不够，可在种子篮用金币换，或等动物带回")
			put(cfg.seed,-1);v.crops[i]={"crop":crop,"due":now()+cfg.seconds};return success("种下了"+cfg.name)
		"harvest":
			var i:=int(a.get("plot",-1))
			if i<0 or i>=v.crops.size() or v.crops[i].is_empty():return fail("这块地还没种")
			var plot:Dictionary=v.crops[i]
			if remaining(plot.due)>0:return fail("还没熟，让它慢慢长")
			put(plot.crop,C.CROPS[plot.crop].yield);v.crops[i]={};return success("收下"+C.CROPS[plot.crop].name)
		"seed":
			var crop:=str(a.get("crop",""))
			if not C.CROPS.has(crop):return fail("没有这种种子")
			if not wallet_spend(C.SEED_COST,"decor"):return fail("金币不够，等动物带种子回来也可以")
			put(C.CROPS[crop].seed,1);return success("种子放进篮子了")
		"produce":
			var recipe:=str(a.get("recipe",""))
			if not C.RECIPES.has(recipe):return fail("还没有这份食谱")
			var cfg:Dictionary=C.RECIPES[recipe]
			if not v.stations[cfg.station].is_empty():return fail("这里还在忙，做好后先收下")
			if not has_items(cfg.input):return fail("还缺原料："+missing_text(cfg.input))
			take(cfg.input);v.stations[cfg.station]={"recipe":recipe,"due":now()+cfg.seconds};return success(cfg.name+"正在做，离开也会继续")
		"collect":
			var station:=str(a.get("station",""))
			if not v.stations.has(station) or v.stations[station].is_empty():return fail("这里还没开工")
			var job:Dictionary=v.stations[station]
			if remaining(job.due)>0:return fail("还没做好")
			put(C.RECIPES[job.recipe].output,1);v.stations[station]={};return success("做好了，放进篮子")
		"order":
			var wanted:=str(a.get("id",""));var found:Dictionary={}
			for order in orders():if order.id==wanted:found=order;break
			if found.is_empty() or found.done:return fail("这件已经交过，明天再来看看")
			if not has_items(found.items):return fail("还缺："+missing_text(found.items))
			take(found.items);wallet_add(found.coins,"order");v.orders[wanted]=now();v.order_total+=1
			if found.family:renqing_add(found.who,"交了"+describe(found.items))
			return success("交给"+found.who+"了，收到 %d 金币"%found.coins)
		"reside":
			if v.resident:return fail("你已经入驻了")
			if v.order_total<C.RESIDENCY.orders:return fail("先帮大家交完 %d 件订单"%C.RESIDENCY.orders)
			if not has_items(C.RESIDENCY.items):return fail("入驻还缺："+missing_text(C.RESIDENCY.items))
			if not wallet_spend(C.RESIDENCY.coins,"decor"):return fail("入驻还要 %d 金币"%C.RESIDENCY.coins)
			take(C.RESIDENCY.items);v.resident=true;return success("村长收好了申请，去选一处喜欢的位置吧")
		"location":
			var id:=str(a.get("id",""))
			if not v.resident or not v.location.is_empty() or not C.LOCATIONS.has(id):return fail("请先入驻；住处选好后本轮固定")
			v.location=id;return success("你的家就在"+C.LOCATIONS[id]+"，从第一块荒地开始吧")
		"land":
			var i:=int(a.get("plot",-1))
			if v.location.is_empty() or i<0 or i>=C.LAND.size():return fail("先选好住处")
			if float(v.land[i])>0:return fail("这块地已经开过了")
			if i>0 and (float(v.land[i-1])<=0 or remaining(v.land[i-1])>0):return fail("先开好前一块地")
			var cost:Dictionary=C.LAND[i]
			if not has_items(cost.items):return fail("还缺："+missing_text(cost.items)+"。动物会带材料和工具，盲盒也有工具")
			if not wallet_spend(cost.coins,"decor"):return fail("金币不够，多交几件门口订单")
			take(cost.items);v.land[i]=now()+C.LAND_SECONDS;return success("杂草收走，石头搬开…%d 秒后可以摆家具"%C.LAND_SECONDS)
		"box","parcel":
			if command=="box":
				if not wallet_spend(C.BOX_COST,"decor"):return fail("金币不够")
			else:
				if count("parcel")<1:return fail("还没有动物包")
				put("parcel",-1)
			if rng.randf()<C.BOX_TOOL_CHANCE or int(v.box_misses)>=C.BOX_TOOL_MISSES:
				v.box_misses=0;put("tool",1);return success("打开得到一把旧锄头")
			v.box_misses+=1
			var keys:=C.FURNITURE.keys();var id:String=keys[rng.randi_range(0,keys.size()-1)]
			if id in v.blueprints:put("bamboo",C.DUPLICATE_BLUEPRINT_BAMBOO);return success("这张图纸已有，换成了 %d 根竹材"%C.DUPLICATE_BLUEPRINT_BAMBOO)
			v.blueprints.append(id);return success("得到"+C.FURNITURE[id].name+"图纸")
		"craft":
			var id:=str(a.get("id",""))
			if not id in v.blueprints:return fail("先从金币盲盒或动物包取得图纸")
			if not has_items(C.FURNITURE[id].items):return fail("还缺："+missing_text(C.FURNITURE[id].items))
			take(C.FURNITURE[id].items);v.furniture.append({"id":int(v.next_id),"kind":id,"x":-1,"y":-1});v.next_id+=1;return success("家具做好了，选它再放到地上")
		"place","store":
			var f:Dictionary={}
			for item in v.furniture:if int(item.id)==int(a.get("id",-1)):f=item;break
			if f.is_empty():return fail("先选一件家具")
			if command=="store":f.x=-1;f.y=-1;return success("家具收好了，可以再摆")
			var x:=int(a.get("x",-1));var y:=int(a.get("y",-1))
			if x<0 or x>=4 or y<0 or y>=9:return fail("放到院子格子里")
			if float(v.land[y/3])<=0 or remaining(v.land[y/3])>0:return fail("这里还没开好")
			for other in v.furniture:
				if other.id!=f.id and int(other.x)==x and int(other.y)==y:return fail("这里已经放了家具")
			f.x=x;f.y=y;return success("摆好了，点家具可再挪或收起")
	return fail("暂时没有这个动作")
func describe(items:Dictionary) -> String:
	var text:Array=[]
	for id in items:
		if int(items[id])>0:text.append("%s×%d"%[item_name(id),items[id]])
	return "、".join(text)
func missing_text(items:Dictionary) -> String:
	var absent:Dictionary={}
	for id in items:if count(id)<int(items[id]):absent[id]=int(items[id])-count(id)
	return describe(absent)
## 给主工程的动作适配器；保留 manor/town/calendar.events 全部内容。
func shared_action(action:String,a:Dictionary) -> Dictionary:
	if action.begins_with("calendar."):
		match action:
			"calendar.now":return {"ok":true,"value":now()}
			"calendar.isMarketDay":return {"ok":true,"value":isMarketDay()}
			"calendar.season":return {"ok":true,"value":season()}
			"calendar.slot":return {"ok":true,"value":slot()}
	if action in ["wallet.add","wallet.spend","renqing.add"]:return act(action,a)
	return fail("未知共用动作")

func market_goods() -> Dictionary:
	var d:=local_date();var rotation:=int(d.day/2)%3
	return C.MARKET_GOODS[rotation]
func day_number() -> int:return maxi(1,data.village.visits.size())

func item_name(id:String) -> String:
	if C.ITEMS.has(id):return str(C.ITEMS[id])
	var old=preload("res://ayu_home/v4/life_state.gd")
	var key:=id.trim_suffix("_seed")
	return str(old.CROPS[key].name)+("种" if id.ends_with("_seed") else "") if old.CROPS.has(key) else id
func neighbour_request(id:String) -> Dictionary:
	var visits:=int(data.village.helped.get(id,0))
	return C.NEIGHBOUR_REQUESTS[id][visits%C.NEIGHBOUR_REQUESTS[id].size()]
