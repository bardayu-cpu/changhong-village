extends SceneTree
const State=preload("res://ayu_home/v4/core/state.gd")
const Rules=preload("res://ayu_home/v4/core/childhood_rules.gd")
const Screen=preload("res://ayu_home/v4/core/childhood_game.gd")
var failures:Array=[]
var count:=0
func check(ok:bool,label:String) -> void:
	count+=1
	if not ok:failures.append(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var s:=State.new();s.now_override=1792929600
	var file:String=OS.get_cmdline_user_args()[0]+"/laundry-"+str(Time.get_ticks_usec())
	check(s.open({"id":"c2-front-laundry"},file),"isolated save")
	for day in 20:
		if Rules.daily_story(s)=="laundry":break
		s.now_override+=86400
	check(s.act("memory_begin",{"id":"laundry"}).ok,"begin laundry")
	var coins:int=s.data.wallet.coins
	s.act("daily_pick",{"index":0});s.now_override+=State.C.CHILDHOOD.laundry_seconds
	var result:=s.act("daily_pick",{"index":1})
	check(result.get("outcome","")=="rain","late click ends round")
	check(s.data.village.childhood.active.is_empty(),"expired active cleared")
	check(int(s.data.wallet.coins)==coins,"no late reward or penalty")
	check(s.act("memory_begin",{"id":"laundry"}).ok,"retry same day")
	s.now_override+=State.C.CHILDHOOD.laundry_seconds-1
	for i in 8:check(s.act("daily_pick",{"index":i}).ok,"clothing "+str(i))
	s.now_override+=2
	check(s.act("daily_finish").get("outcome","")=="complete","collected before rain remains successful")
	check(int(s.data.wallet.coins)==coins+State.C.CHILDHOOD.daily_reward,"reward once")
	check(not s.act("daily_finish").ok,"repeat finish rejected")
	check(not s.act("memory_begin",{"id":"laundry"}).ok,"repeat reward same day rejected")
	print(JSON.stringify({"checks":count,"failures":failures,"pass":failures.is_empty()}));quit(0 if failures.is_empty() else 1)
