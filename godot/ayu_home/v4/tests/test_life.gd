extends SceneTree
const Life=preload("res://ayu_home/v4/life_state.gd")
var failures:Array=[]
var checks:Array=[]
func check(ok:bool,label:String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:failures.append(label)
func _initialize() -> void:
	var file:="/private/tmp/ayu-v4-unit-life.json"
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(file+suffix):DirAccess.remove_absolute(file+suffix)
	var s=Life.new();s.now_override=1791072000;s.open({"id":"life-qa","avatar":3},file)
	check(s.pack_seeds(10),"妈妈首次备种与备菜")
	var seeds:int=s.data.seeds.pumpkin
	check(not s.pack_seeds(10) and s.data.seeds.pumpkin==seeds,"重开种子盒不刷种子")
	check(s.till(0) and s.plant(0,"pumpkin",10) and s.water(0),"翻土播种浇水顺序")
	check(not s.water(0) and s.harvest(0).is_empty(),"不重复浇水或提前收成")
	s.now_override+=7000;check(s.growth(s.data.plots[0])>0 and s.growth(s.data.plots[0])<1,"按真实秒数慢慢生长")
	s.save();var t=Life.new();t.now_override=s.now_override+7500;t.open({"id":"life-qa","avatar":3},file)
	check(t.growth(t.data.plots[0])==1,"关闭再开计入离线时间")
	var before:int=t.data.basket.pumpkin
	check(not t.harvest(0).is_empty() and t.data.basket.pumpkin==before+2 and t.data.seeds.pumpkin==seeds,"采收回厨房且留种")
	check(t.harvest(0).is_empty(),"不重复采收")
	check(t.till(0,true) and t.plant(0,"apple",10,true) and t.water(0,true),"果树可以种植")
	t.now_override+=259200;check(not t.harvest(0,true).is_empty() and t.data.trees[0].grown and t.stage(t.data.trees[0])=="等下一批果子","三天长成的树采后仍在，并提示等待新果")
	check(t.harvest(0,true).is_empty(),"果树采后等待新一轮结果")
	check(not t.fruit_pick(10).is_empty() and t.fruit_pick(10).is_empty(),"老果园一日一篮")
	t.pet("qiuqiu");t.pet("luoluo");t.pet("tiantian");t.pet("qiuqiu");check(t.cats_today()==3 and t.data.cards.has("cats"),"三猫每日名单不重复")
	var q:Dictionary=t.daily_tasks()[0];q.accepted=true;t.event(q.event);check(q.done,"当日请求完成")
	t.data.resident=true;t.wish("希望花开",.2);t.keep_photo({"room":"garden","pose":0,"actors":[],"date":t.date_key()});t.save()
	var u=Life.new();u.now_override=t.now_override;u.open({"id":"life-qa","avatar":3},file)
	check(u.data.resident and u.data.photos.size()==1 and u.data.wishes.size()==1,"留宿相片愿望重新打开都保留")
	check(u.invite_key(12.25)!="" and u.invite_key(11.5)=="","饭点窗口明确")
	var z=Life.new();z.now_override=t.now_override;z.open({"id":"life-qa-other"},file+"-other");check(not z.data.resident and z.data.photos.is_empty(),"不同玩家不串档")
	u.save();var corrupt:=FileAccess.open(file,FileAccess.WRITE);corrupt.store_string("{broken");corrupt.close();var r=Life.new();r.now_override=u.now_override;r.open({"id":"life-qa"},file);check(r.data.resident and not r.last_error.is_empty(),"损坏主档回退上一份备份")
	var out:=FileAccess.open("res://ayu_home/v4/evidence/life-state.json",FileAccess.WRITE);out.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"));out.close()
	print(JSON.stringify({"checks":checks.size(),"failed":failures}));print("RESULT ","PASS" if failures.is_empty() else "FAIL"," life-state");quit(0 if failures.is_empty() else 1)
