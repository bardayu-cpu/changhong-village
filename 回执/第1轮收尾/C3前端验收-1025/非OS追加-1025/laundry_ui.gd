extends SceneTree
const Home=preload("res://ayu_home/v4/home.gd")
const Rules=preload("res://ayu_home/v4/core/childhood_rules.gd")
const Game=preload("res://ayu_home/v4/core/childhood_game.gd")
const C=preload("res://ayu_home/v4/core/config.gd")
var h
var s
var game
var out:=""
var rows:Array=[]
func _initialize():
 for a in OS.get_cmdline_user_args():
  if a.begins_with("--qa-out="):out=a.trim_prefix("--qa-out=")
 root.set_meta("player_profile",{"id":"c3-laundry-front-1025","openid":"c3-laundry-front-1025","avatar":2,"nick":"C3\u6536\u8863\u9694\u79bb"});call_deferred("run")
func check(ok:bool,label:String,info:Dictionary={}):
 rows.append({"pass":ok,"check":label,"details":info});print("CHECK ",ok," ",label)
func snap(name:String):
 for i in 6:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out+"/"+name+".png")
 var texts:Array=[];read_text(root,texts)
 var v=s.data.village
 var data={"name":name,"hour":h.hour,"month":h.month,"weather":h.weather,"area":h.area,"window":[root.size.x,root.size.y],"date":s.date_key(),"test_now":s.now(),"coins":s.data.wallet.coins,"active":v.childhood.active if v.has("childhood") else {},"daily":v.childhood.daily if v.has("childhood") else {},"text":texts}
 FileAccess.open(out+"/"+name+".json",FileAccess.WRITE).store_string(JSON.stringify(data,"  "))
func read_text(node:Node,arr:Array):
 if node is Control and node.is_visible_in_tree() and (node is Label or node is Button or node is RichTextLabel):arr.append(node.text)
 for c in node.get_children():read_text(c,arr)
func run():
 root.size=Vector2i(540,960);h=Home.new();root.add_child(h)
 var deadline=Time.get_ticks_msec()+30000
 while not h.bootstrapped and Time.get_ticks_msec()<deadline:await process_frame
 if not h.bootstrapped:quit(1);return
 root.title="C3\u975eOS \u00b7 \u6536\u8863\u622a\u6b62"
 h.set_test_clock(13,10,"clear");await h.enter_room("living",false);s=h.village_ui.state
 s.now_override=Time.get_unix_time_from_datetime_string("2026-10-25T13:00:00")-int(Time.get_time_zone_from_system().bias)*60
 for day in 14:
  if Rules.daily_story(s)=="laundry":break
  s.now_override+=86400
 check(Rules.daily_story(s)=="laundry","normal daily selection found laundry")
 check(s.act("visit").ok,"normal visit")
 for pet in C.PETS:check(s.act("animal",{"id":pet}).ok,"normal animal supply "+pet)
 check(s.act("plant",{"plot":0,"crop":"pepper"}).ok,"normal pepper plant for positive balance")
 s.now_override+=300
 check(s.act("harvest",{"plot":0}).ok,"normal pepper harvest")
 var paid:=false
 for order in s.orders():
  if not paid and s.has_items(order.items):
   var r:Dictionary=s.act("order",{"id":order.id});paid=r.ok
 check(paid and s.data.wallet.coins>0,"positive coins earned normally",{"coins":s.data.wallet.coins})
 var coins:int=s.data.wallet.coins
 await snap("Ayu-13")
 game=Game.new();h.village_ui.add_child(game);game.setup(h.village_ui)
 game.begin("laundry");await snap("laundry-start-45")
 check(game.clock.text.contains("45"),"visible 45 second countdown",{"text":game.clock.text})
 var started:float=s.data.village.childhood.active.started
 game.send("daily_pick",{"index":0});game.send("daily_pick",{"index":1})
 s.now_override=started+44
 await snap("laundry-one-second-left")
 check(game.clock.text.contains("1"),"visible one second left",{"text":game.clock.text})
 s.now_override=started+45
 for i in 8:await process_frame
 check(game.finished and s.data.village.childhood.active.is_empty(),"deadline UI auto ends unfinished laundry")
 check(int(s.data.wallet.coins)==coins,"rain does not charge or reward positive wallet",{"before":coins,"after":s.data.wallet.coins})
 check(not s.data.village.childhood.daily.has(s.date_key()+":laundry"),"rain does not consume daily completion")
 await snap("laundry-rain-no-penalty")
 game.begin("laundry");check(not game.finished,"same day normal retry")
 var retry:float=s.data.village.childhood.active.started;s.now_override=retry+44.9
 for i in 8:
  game.send("daily_pick",{"index":i});await process_frame
 check(s.data.village.childhood.active.picked.size()==8,"all eight collected before deadline")
 check(int(s.data.wallet.coins)==coins,"no reward before finishing")
 await snap("laundry-eight-before-rain")
 s.now_override=retry+46
 for i in 8:await process_frame
 check(game.finished and s.data.village.childhood.active.is_empty(),"collected before deadline still completes after deadline")
 check(int(s.data.wallet.coins)==coins+int(C.CHILDHOOD.daily_reward),"exact one daily reward",{"before":coins,"after":s.data.wallet.coins})
 await snap("laundry-success-once")
 check(not s.act("daily_finish").ok,"repeat finish rejected")
 check(not s.act("memory_begin",{"id":"laundry"}).ok,"same day repeat reward rejected")
 check(int(s.data.wallet.coins)==coins+int(C.CHILDHOOD.daily_reward),"wallet stays after rejected repeats")
 FileAccess.open(out+"/result.json",FileAccess.WRITE).store_string(JSON.stringify({"mode":"non-OS Home + actual childhood Game.begin/send/automatic countdown; normal transactions, accelerated test clock, no reward injection","rows":rows,"art_scope":"25-object atlas visible only; six backgrounds pending, not S art pass","OS_input":false},"  "))
 game.close();h.village_ui.checkpoint();h.queue_free();await process_frame;quit(0)
