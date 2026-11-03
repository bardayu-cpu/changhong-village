extends SceneTree
const Home=preload("res://ayu_home/v4/home.gd")
const Game=preload("res://ayu_home/v4/core/childhood_game.gd")
const Rules=preload("res://ayu_home/v4/core/childhood_rules.gd")
var h
var g
var s
var out:=""
var rows:Array=[]
var shots:Array=[]
func _initialize():
 for a in OS.get_cmdline_user_args():
  if a.begins_with("--qa-out="):out=a.trim_prefix("--qa-out=")
 root.set_meta("player_profile",{"id":"c3-S-art","openid":"c3-S-art","avatar":2,"nick":"C3 S art"});call_deferred("run")
func check(ok:bool,label:String,info:Dictionary={}):
 rows.append({"pass":ok,"check":label,"details":info});print("CHECK ",ok," ",label)
func text_of(n:Node,a:Array):
 if n is Control and n.is_visible_in_tree() and (n is Label or n is Button):a.append(n.text)
 for c in n.get_children():text_of(c,a)
func boards(n:Node,a:Array):
 if n is Control and n.get("kind")!=null and n.get("owner_game")!=null and n.has_method("at"):
  var positions:Array=[]
  var count:int=n.session.cards.size() if n.kind=="milk" else (9 if n.kind=="loach" else 8)
  for i in count:
   var at:Vector2=n.at(i)*n.size;positions.append({"i":i,"local":[at.x,at.y],"index_at_center":n.index_at(at)})
  a.append({"kind":n.kind,"global":[n.global_position.x,n.global_position.y],"size":[n.size.x,n.size.y],"positions":positions})
 for c in n.get_children():boards(c,a)
func snap(name:String):
 for i in 5:await process_frame
 await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+"/"+name+".png")
 var text:Array=[];text_of(root,text);var art:Array=[];boards(root,art)
 var m={"name":name,"hour":h.hour,"month":h.month,"weather":h.weather,"date":s.date_key(),"text":text,"boards":art,"coins":s.data.wallet.coins}
 FileAccess.open(out+"/"+name+".json",FileAccess.WRITE).store_string(JSON.stringify(m,"  "));shots.append(m)
func game():
 g=Game.new();h.village_ui.add_child(g);g.setup(h.village_ui)
func run():
 root.size=Vector2i(540,960);Engine.max_fps=30;h=Home.new();root.add_child(h)
 var until=Time.get_ticks_msec()+30000
 while not h.bootstrapped and Time.get_ticks_msec()<until:await process_frame
 if not h.bootstrapped:quit(1);return
 root.title="C3 non-OS S actual art"
 h.set_test_clock(13,10,"clear");await h.enter_room("living",false);s=h.village_ui.state
 s.now_override=Time.get_unix_time_from_datetime_string("2027-10-25T13:00:00")-int(Time.get_time_zone_from_system().bias)*60
 h.player.position=h.world.nearest(Vector2(385,338));h.camera=h.room_camera_target();h.layout();await snap("Ayu-13")
 game();g.begin("milk");await snap("milk-level1-table")
 g.send("milk_finish");check(g.finished,"milk failure actual UI outcome")
 await snap("milk-hospital-failure")
 g.begin("milk")
 for level in 3:
  var ses:Dictionary=s.data.village.childhood.active
  check(int(ses.level)==level,"milk actual level "+str(level+1))
  for i in ses.cards.size():
   if ses.cards[i].bad:g.send("milk_isolate",{"index":i})
  await snap("milk-level"+str(level+1)+"-isolated")
  g.send("milk_finish")
 check(g.finished,"milk actual three levels success");await snap("milk-success")
 g.close();await process_frame
 await h.enter_room("village",false);game();g.begin("loach");await snap("loach-start")
 var session:Dictionary=s.data.village.childhood.active
 g.send("loach_cast",{"target":posmod(int(session.casts)*5+3,9),"hold":.5});await snap("loach-catch")
 s.now_override=float(session.started)+60.1
 for i in 8:await process_frame
 await snap("loach-end");g.close();await process_frame
 await h.enter_room("living",false);game();g.begin("train");await snap("train-shop")
 for item in ["ticket","document","water","coat"]:g.send("train_buy",{"item":item})
 g.send("train_pack",{"item":"ticket","x":0,"y":0});g.send("train_pack",{"item":"document","x":1,"y":0});g.send("train_pack",{"item":"water","x":2,"y":0});g.send("train_pack",{"item":"coat","x":3,"y":0})
 await snap("train-packed");g.send("train_finish");await snap("train-result");g.close();await process_frame
 for kind in ["laundry","vegetables"]:
  for day in 14:
   if Rules.daily_story(s)==kind:break
   s.now_override+=86400
  check(Rules.daily_story(s)==kind,"actual daily kind selected "+kind)
  game();g.begin(kind);await snap(kind+"-start")
  g.send("daily_pick",{"index":1});g.send("daily_pick",{"index":2});await snap(kind+"-two-picked")
  g.close();await process_frame
 FileAccess.open(out+"/result.json",FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"shots":shots,"OS_input":false,"mode":"actual Game.begin/send with normal transactions and accelerated diagnostic dates; visual follow-up only, not full rules rerun","visual_review_pending":true,"S_overall_pass":false},"  "))
 h.queue_free();await process_frame;quit(0)
