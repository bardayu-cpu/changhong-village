extends RefCounted
const C=preload("res://ayu_home/v4/core/config.gd")
const PACK={"ticket":{"name":"车票","cost":0,"size":[1,1]},"document":{"name":"证件","cost":0,"size":[1,1]},"water":{"name":"水","cost":2,"size":[1,2]},"coat":{"name":"厚外套","cost":4,"size":[2,2]},"snack":{"name":"零食","cost":3,"size":[2,1]},"book":{"name":"书","cost":2,"size":[2,2]}}
static func milk_cards(s,level:int) -> Array:
	var today:=int(Time.get_unix_time_from_datetime_string(s.date_key()+"T00:00:00")/86400)
	var cards:Array=[]
	for i in 4+level:
		var age:=2+i%3
		var bad:bool=(i==level+1 or (level==2 and i==0))
		var swollen:bool=level==2 and i==0
		var cold:bool=not (level==1 and bad)
		if bad and not swollen and cold:age=10
		cards.append({"made":Time.get_date_string_from_unix_time((today-age)*86400),"days":7,"opened":level>=1 and i%2==0 or not cold,"cold":cold,"swollen":swollen,"leaking":false,"bad":bad})
	return cards
static func run(s,command:String,a:Dictionary) -> Dictionary:
	var v:Dictionary=s.data.village
	if not v.has("childhood"):v.childhood={"active":{},"daily":{},"pages":[]}
	var ch:Dictionary=v.childhood
	var session:Dictionary=ch.active
	if command=="memory_begin":
		var id:=str(a.get("id",""))
		if not id in ["milk","loach","train","laundry","vegetables"]:return s.fail("没有这段故事")
		if id in ["laundry","vegetables"] and id!=daily_story(s):return s.fail("今天家里留的是另一件小事")
		if ch.daily.has(s.date_key()+":"+id):return s.fail("今天这段回忆已收好，明天还能再玩")
		ch.active={"id":id,"started":s.now(),"level":0,"checks":0,"revealed":{},"isolated":[],"cards":milk_cards(s,0),"caught":0,"casts":0,"last_cast":s.now(),"budget":C.CHILDHOOD.train_budget,"bought":["ticket","document"],"packed":{},"picked":[],"failed":false}
		return s.success("这段回忆慢慢开始了")
	if session.is_empty():return s.fail("先打开一段回忆")
	var id:=str(session.id)
	if id=="laundry" and command in ["daily_pick","daily_finish"] and session.picked.size()<8 and s.now()-float(session.started)>=float(C.CHILDHOOD.laundry_seconds):
		ch.active={}
		return {"ok":true,"outcome":"rain","message":"雨点落下了，这次衣服还没收齐。没有扣金币，可以再试一次。"}
	match command:
		"memory_cancel":ch.active={};return s.success("先把本子合上，奖励还没有领取")
		"milk_check":
			if id!="milk":return s.fail("不是这段回忆")
			var i:=int(a.get("index",-1));var kind:=str(a.get("kind","date"))
			if i<0 or i>=session.cards.size() or not kind in ["date","colour","smell"]:return s.fail("先选一盒")
			var key:=str(i)+":"+kind
			if session.revealed.has(key):return s.fail("这个线索已经看过")
			if kind!="date" and session.revealed.has("used:"+kind):return s.fail("这次倒出或闻气味的机会已经用过")
			if int(session.checks)>=int(C.CHILDHOOD.milk_checks):return s.fail("三次检查用完了，按已知线索分开吧")
			session.checks=int(session.checks)+1;session.revealed[key]=true
			if kind!="date":session.revealed["used:"+kind]=true
			return s.success("线索已经展开")
		"milk_isolate":
			if id!="milk":return s.fail("不是这段回忆")
			var i:=int(a.get("index",-1))
			if i<0 or i>=session.cards.size():return s.fail("先选一盒")
			if i in session.isolated:session.isolated.erase(i)
			else:session.isolated.append(i)
			return s.success("这盒的位置换好了")
		"milk_finish":
			if id!="milk":return s.fail("不是这段回忆")
			var safe:bool=s.now()-float(session.started)<=float(C.CHILDHOOD.milk_seconds)
			for i in session.cards.size():
				if bool(session.cards[i].bad)!=(i in session.isolated):safe=false
			if not safe:
				var fee:=mini(int(s.data.wallet.coins),int(C.CHILDHOOD.milk_fee));s.wallet_spend(fee,"childhood_hospital")
				ch.active={};return {"ok":true,"outcome":"hospital","message":"那次真把大家吓坏了。医药费 %d 金币；可以再试一次。"%fee}
			if int(session.level)<2:
				session.level=int(session.level)+1;session.cards=milk_cards(s,int(session.level));session.checks=0;session.revealed={};session.isolated=[];session.started=s.now()
				return s.success("这一桌选好了，阿姨谢谢你。再看下一桌。")
			s.wallet_add(C.CHILDHOOD.milk_reward,"childhood");s.renqing_add("家人","一起挑好了牛奶")
			return finish(s,ch,id,"小阿鱼喝上了好的牛奶，阿姨道谢。回忆页已解锁。")
		"loach_cast":
			if id!="loach" or s.now()-float(session.started)>=C.CHILDHOOD.loach_seconds:return s.fail("这一局时间到了")
			var hold:=float(a.get("hold",0));var target:=int(a.get("target",-1));var turn:=int(session.casts)
			if s.now()-float(session.last_cast)<0.25:return s.fail("让泥水先平静下来")
			var actual:=posmod(turn*5+3,9);session.casts=turn+1;session.last_cast=s.now()
			if target!=actual:return s.success("这里没有水纹，再找找冒泡的地方")
			if hold<.25 or hold>1.1:return s.success("捞早了或握得太久，泥鳅滑走了")
			if turn%5==4:return {"ok":true,"catch":"stone","message":"捞到一块石头，放回水边"}
			if turn%7==6:return {"ok":true,"catch":"crab","message":"小螃蟹跑开了，继续看看水纹"}
			session.caught=int(session.caught)+1;return {"ok":true,"catch":"loach","message":"竹篓里多了一条泥鳅"}
		"loach_finish":
			if id!="loach" or s.now()-float(session.started)<C.CHILDHOOD.loach_seconds:return s.fail("这一局还没到六十秒")
			s.put("loach",int(session.caught));return finish(s,ch,id,"捞到 %d 条泥鳅，已经放入共用篮子。灶屋可以做泥鳅汤。"%int(session.caught))
		"train_buy":
			if id!="train":return s.fail("不是这段回忆")
			var item:=str(a.get("item",""))
			if not PACK.has(item) or item in session.bought:return s.fail("行囊里已经有了")
			if int(session.budget)<int(PACK[item].cost):return s.fail("这次回忆的零花钱不够，取舍一下吧")
			session.budget=int(session.budget)-int(PACK[item].cost);session.bought.append(item);return s.success("采买好了")
		"train_pack":
			if id!="train":return s.fail("不是这段回忆")
			var item:=str(a.get("item",""));var x:=int(a.get("x",-1));var y:=int(a.get("y",-1))
			if not item in session.bought:return s.fail("这件还没买")
			if x<0 or y<0:session.packed.erase(item);return s.success("先拿出箱子")
			var shape:Array=PACK[item].size;var rect:=Rect2i(x,y,int(shape[0]),int(shape[1]))
			if rect.end.x>5 or rect.end.y>3:return s.fail("超出箱子边了")
			for other in session.packed:
				if other==item:continue
				var cell:Array=session.packed[other];var sz:Array=PACK[other].size
				if rect.intersects(Rect2i(cell[0],cell[1],sz[0],sz[1])):return s.fail("这里已经放了东西")
			session.packed[item]=[x,y];return s.success("行李放稳了")
		"train_finish":
			if id!="train":return s.fail("不是这段回忆")
			for item in ["ticket","document","water"]:
				if not session.packed.has(item):return s.fail("还没装好"+str(PACK[item].name)+"，先别出发")
			var text:="车上冷，幸好带了外套。" if session.packed.has("coat") else "冻了一路。"
			s.wallet_add(C.CHILDHOOD.train_reward,"childhood");return finish(s,ch,id,text+"这趟行囊收好了。")
		"daily_pick":
			if not id in ["laundry","vegetables"]:return s.fail("不是家里的小事")
			var index:=int(a.get("index",-1))
			if index<0 or index>=8 or index in session.picked:return s.fail("这个已经收好了")
			if id=="vegetables" and index%3==0:return s.fail("这片叶子很新鲜，留下来吧")
			session.picked.append(index)
			return s.success("衣服收进篮里了" if id=="laundry" else "坏叶挑出去了")
		"daily_finish":
			if not id in ["laundry","vegetables"]:return s.fail("不是家里的小事")
			var needed:=8 if id=="laundry" else 5
			if session.picked.size()<needed:return s.fail("还剩几件，继续慢慢收")
			s.wallet_add(C.CHILDHOOD.daily_reward,"childhood");return finish(s,ch,id,"收衣服赶在雨前完成了。" if id=="laundry" else "黄叶、虫叶挑净了，妈妈做菜就省心了。")
	return s.fail("先看看眼前这一步")
static func daily_story(s) -> String:
	var serial:=int(Time.get_unix_time_from_datetime_string(s.date_key()+"T00:00:00")/86400)
	return "laundry" if posmod(hash(str(serial)+str(s.data.openid)),2)==0 else "vegetables"
static func finish(s,ch:Dictionary,id:String,message:String) -> Dictionary:
	ch.daily[s.date_key()+":"+id]=true
	if not id in ch.pages:ch.pages.append(id)
	ch.active={}
	return {"ok":true,"outcome":"complete","message":message}
