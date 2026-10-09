from pathlib import Path
R=Path(__file__).resolve().parents[1];core=R/'godot/ayu_home/v4/core'
p=core/'config.gd';s=p.read_text();s=s.replace('"porridge":"谷香粥"','"porridge":"谷香粥","honey":"蜂蜜","fish":"鲜鱼","egg":"鸡蛋","fruit":"时令果"')
s=s.replace('"grain_seed":3}', '"grain_seed":4}')
s += '''
const PRODUCERS={
 "honey":{"name":"蜂蜜箱","seconds":240,"input":{},"output":"honey","yield":2},
 "pond":{"name":"池塘","seconds":180,"input":{"grain":1},"output":"fish","yield":2},
 "chicken":{"name":"鸡圈","seconds":180,"input":{"grain":1},"output":"egg","yield":2},
 "orchard":{"name":"果树","seconds":300,"input":{},"output":"fruit","yield":3}}
const NEIGHBOURS={
 "honey":{"name":"阿禾","house":"h5","request":{"honey":1},"coins":35,"gift":{"bamboo":2},"first":"花架还空着。帮我收一瓶蜜，摆盆花在这里吧。","again":"你上次留下的蜜很香。花架一直给你留着位置。"},
 "mill":{"name":"青叔","house":"h3","request":{"flour":1},"coins":40,"gift":{"stone":2},"first":"谷子磨成粉，便能煮粥。帮我带一袋，石磨随时借你。","again":"上次的谷粉派上用场了。坐下，我再泡壶茶。"}}
const LOCATION_POINTS={"lake":[1350,3385],"bamboo":[1790,3385],"hill":[1350,3765],"garden":[1790,3765]}
''';p.write_text(s)
p=core/'state.gd';s=p.read_text();s=s.replace('data=disk;return true','data=disk;upgrade();return true',1);s=s.replace('return persist()\nfunc read_latest','upgrade()\n\treturn persist()\nfunc read_latest',1)
s=s.replace('func read_latest()','''func upgrade() -> void:
	var defaults={"household":{},"producers":{"honey":{},"pond":{},"chicken":{},"orchard":{}},"helped":{},"chores":{},"memories":[],"market":{},"box_misses":0,"animal_misses":0,"first_day":date_key(),"last_area":"exterior","last_position":[],"season":"","weather":"","migration":{}}
	for key in defaults:
		if not data.village.has(key):data.village[key]=defaults[key]
	data.village.version=2
func read_latest()''')
s=s.replace('var roll:=rng.randi_range(1,100);var total:=0','var roll:=rng.randi_range(1,100);var total:=0\n\t\t\t\tif i==3 and int(v.animal_misses)>=5:roll=1')
s=s.replace('v.animals[id]={"due":now()+C.ANIMAL_SECONDS','v.animal_misses=0 if got.has("tool") else int(v.animal_misses)+1\n\t\t\tv.animals[id]={"due":now()+C.ANIMAL_SECONDS')
s=s.replace('if rng.randf()<0.25:put("tool",1);return success("打开得到一把旧锄头")','if rng.randf()<0.25 or int(v.box_misses)>=3:\n\t\t\t\tv.box_misses=0;put("tool",1);return success("打开得到一把旧锄头")\n\t\t\tv.box_misses+=1')
s=s.replace('match command:\n', '''match command:
		"household":
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
			var c:Dictionary=C.NEIGHBOURS[id];var key:=date_key()+":"+id
			if v.chores.has(key):return fail("今天已经帮过忙了，坐下来聊一会儿吧")
			if not has_items(c.request):return fail("还缺："+missing_text(c.request))
			take(c.request);wallet_add(c.coins,"order");v.chores[key]=true;v.helped[id]=int(v.helped.get(id,0))+1
			for item in c.gift:put(item,c.gift[item])
			renqing_add(c.name,"收到了你带来的"+describe(c.request));return success(c.name+"记住了你的帮助，收到金币和"+describe(c.gift))
		"house_help":
			var id:=str(a.get("id",""));var key:=date_key()+":house:"+id
			if v.chores.has(key):return fail("今天已经收拾好了。你的来访记在这里")
			v.chores[key]=true;v.helped["house:"+id]=int(v.helped.get("house:"+id,0))+1
			v.memories.append({"date":date_key(),"place":str(a.get("title",id)),"text":str(a.get("text","来串了门"))})
			return success(str(a.get("text","已经收拾好了")))
		"season_help":
			var key:=date_key()+":season"
			if v.chores.has(key):return fail("今天的季节小事已经做完，明天还会有新的便签")
			var wet:bool=str(a.get("weather","")) in ["rain","snow"];var need:Dictionary={"grain":1} if wet else {"fruit":1}
			if not has_items(need):return fail("今天"+("给鸟留一把谷子：" if wet else "分享一份时令果：")+missing_text(need))
			take(need);wallet_add(25,"order");put("bamboo",1);v.chores[key]=true;renqing_add("村里的邻居","雨雪天添谷子" if wet else "分享了"+str(a.get("season",""))+"的果子");return success("这件小事记下了，收到 25 金币和一根竹材")
		"sell":
			var id:=str(a.get("id",""))
			if not id in ["radish","pepper","grain","honey","fish","egg","fruit"] or count(id)<1:return fail("篮子里还没有这份收获")
			put(id,-1);wallet_add(12,"order");return success("放进邻里食材柜，收到 12 金币")
		"market_buy":
			if not isMarketDay():return fail("今天歇场；普通种子可在种子篮换")
			var goods:=market_goods();var id:=str(a.get("id",""))
			if not goods.has(id):return fail("今天没带这件货")
			if not wallet_spend(goods[id],"decor"):return fail("金币不够")
			put(id,1);return success("货郎把东西包好了")
''',1)
s += '''
func market_goods() -> Dictionary:
	var d:=local_date();var rotation:=int(d.day/2)%3
	return [{"bamboo":9,"radish_seed":2,"honey":18},{"stone":10,"pepper_seed":2,"egg":18},{"bamboo":9,"grain_seed":2,"fruit":18}][rotation]
func day_number() -> int:return maxi(1,data.village.visits.size())
'''
p.write_text(s)
# One transactional save owns household moments as well as all village economy.
p=R/'godot/ayu_home/v4/life_state.gd';s=p.read_text();s=s.replace('var data:Dictionary={}','var shared_state\nvar data:Dictionary={}',1);s=s.replace('func save() -> bool:\n','''func save() -> bool:
	if shared_state!=null:
		var result:Dictionary=shared_state.act("household",{"data":data})
		attempt_done(result.ok);return bool(result.ok)
''',1);s=s.replace('func now() -> float:return now_override if now_override>=0 else Time.get_unix_time_from_system()','func now() -> float:return shared_state.now() if shared_state!=null else (now_override if now_override>=0 else Time.get_unix_time_from_system())');p.write_text(s)
# Never alter the proven old navigation cell in the house. Larger map has a coarser grid.
p=R/'godot/ayu_home/v4/world.gd';s=p.read_text().replace('const CELL := 4','var CELL := 4');s=s.replace('cfg = JSON.parse_string(FileAccess.get_file_as_string(ROOMS+area+".json"))','cfg = JSON.parse_string(FileAccess.get_file_as_string(ROOMS+area+".json"))\n\tCELL=int(cfg.get("nav_cell",4))')
p.write_text(s)
# Insert world UI/controller before first area load; resume a saved position at the normal entrance.
p=R/'godot/ayu_home/v4/home.gd';s=p.read_text().replace('DisplayServer.window_set_title("阿鱼家 · v4 · 把日子住进来")','DisplayServer.window_set_title("裳泓村 · 把日子住进来")')
s=s.replace('enter_room(area,false)\n\tif not focus.is_empty():','village_ui=preload("res://ayu_home/v4/core/interface.gd").new();add_child(village_ui);village_ui.setup(self)\n\tif not village_ui.state.blocked and not first_visit:area=str(village_ui.state.data.village.get("last_area",area))\n\tenter_room(area,false)\n\tif not focus.is_empty():',1)
s=s.replace('\n\tvillage_ui=preload("res://ayu_home/v4/core/interface.gd").new();add_child(village_ui);village_ui.setup(self)\n\tlife.changed','\n\tlife.changed',1)
s=s.replace('room_entries+=1;note=', 'if village_ui!=null:village_ui.entered()\n\troom_entries+=1;note=',1)
s=s.replace('if village_ui!=null:\n\t\tif area==','if village_ui!=null:\n\t\tif village_ui.interact(h):return\n\t\tif area==',1)
s=s.replace('view_scale=2.0\n','view_scale=float(world.cfg.get("view_scale",2.0))\n',1)
s=s.replace('if not group.is_empty():map_group=group','if village_ui!=null and group.is_empty():village_ui.show_page("地图");return\n\tif not group.is_empty():map_group=group',1)
s=s.replace('欢迎来阿鱼家。\\n先和喜多打个招呼，再来敲门。家人有三件小事想请你帮忙，后园的种子也备好了。','欢迎来到裳泓村。\\n先收喜多和猫猫带回的东西，种下几样菜，再进阿鱼家做客。帮大家交三件订单，阿鱼就会介绍你去找村长。')
s=s.replace('喜欢这里的话，二楼客房给你留着。','二楼客房给你留着。以后也可以在村里选一处荒地，慢慢搭起自己的家。')
s=s.replace('阿鱼家 · "+("你的房间"','裳泓村 · "+("你的房间"',1)
s=s.replace('else:labels=["晴天","雨天"];values=["clear","rain"]','else:labels=["晴天","阴天","雨天","雪天"];values=["clear","cloud","rain","snow"]')
p.write_text(s)
# Narrative stage notes are part of the concrete production plan.
p=R/'交付/完整村庄-1006/整体设计与实施顺序.md';s=p.read_text();s+='''\n\n每日回访与前三次来到村里：第一天由阿鱼家的种子、借用自留地和四只动物开启，边等五分钟边串门，三张订单换来入住资格。第二次回来能收昨日停着的作物和生产，阿禾与青叔记得上次帮忙，玩家选择继续赚钱开地或先做竹椅。第三次可换房前家具、照料新的生产链、补完生活册；后续目标是三块地和自己的布置。没有连续签到损失，天数按实际来访日记录，无必须等待明天的硬门槛。\n\n关键实现：每户小事留生活册记录；两位虚构邻居每天一份生产需求与累计回应；季节晴雨改变轻量帮助所需物品，普通日子仍可串门坐下、钓鱼和玩原小游戏。动物随机掉落保留五分钟与四件，连续五次未出工具则第六次有保底；金币盲盒连续三次未出工具则第四次有保底。工具仅从动物或金币盲盒/动物包来。邻里食材柜随时收余粮，保证无需等赶场、也无需调时间才能攒钱。\n''';p.write_text(s)
shutil=None
