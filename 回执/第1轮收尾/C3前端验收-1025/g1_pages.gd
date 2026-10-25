extends SceneTree
const Home=preload("res://ayu_home/v4/home.gd")
var h
var s
var out:=""
var result:Array=[]
func _initialize():
 for a in OS.get_cmdline_user_args():
  if a.begins_with("--qa-out="):out=a.trim_prefix("--qa-out=")
 root.set_meta("player_profile",{"id":"c3-front-g1-1025","openid":"c3-front-g1-1025","avatar":2,"nick":"C3\u56fe\u7eb8\u9694\u79bb"})
 call_deferred("run")
func snap(name:String):
 for i in 8:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out+"/"+name+".png")
 var texts:Array=[];read_text(root,texts)
 var proof={"name":name,"hour":h.hour,"month":h.month,"weather":h.weather,"area":h.area,"window":[root.size.x,root.size.y],"world_scale":[h.world.scale.x,h.world.scale.y],"friendship":{},"blueprints":s.data.village.blueprints.duplicate(),"visible_text":texts}
 for who in ["\u51ef\u51ef","\u5c0f\u6d9b","\u6797\u4f2f"]:proof.friendship[who]=s.friendship(who)
 FileAccess.open(out+"/"+name+".json",FileAccess.WRITE).store_string(JSON.stringify(proof,"  "))
func read_text(node:Node,arr:Array):
 if node is Control and node.is_visible_in_tree():
  if node is Label or node is Button or node is RichTextLabel:arr.append(node.text)
 for c in node.get_children():read_text(c,arr)
func plans(id:String):
 h.village_ui.show_page("\u7bee\u5b50")
 for i in 2:await process_frame
 h.village_ui.root.switch_group("plans")
 for i in 2:await process_frame
 h.village_ui.root.select_item(id)
func run():
 root.size=Vector2i(540,960);h=Home.new();root.add_child(h)
 var deadline=Time.get_ticks_msec()+30000
 while not h.bootstrapped and Time.get_ticks_msec()<deadline:await process_frame
 if not h.bootstrapped:quit(1);return
 root.title="C3\u524d\u7aefQA \u00b7 G1\u56fe\u7eb8\u9875"
 h.set_test_clock(13,10,"clear");await h.enter_room("living",false)
 s=h.village_ui.state
 await snap("Ayu-13")
 var cases=[["\u51ef\u51ef","v_h5",["wash","filter","bottle"],"honey_rack"],["\u5c0f\u6d9b","v_h3",["sift","tea","sweep"],"grain_crate"],["\u6797\u4f2f","v_mayor",["register","notice","bundle"],"notice_easel"]]
 for c in cases:
  var before:bool=c[3] in s.data.village.blueprints
  await plans(c[3]);await snap(str(c[3])+"-before")
  h.village_ui.close()
  for spot in c[2]:
   var r:Dictionary=s.act("institution_effect",{"room":c[1],"spot":spot})
   result.append({"command":"institution_effect","room":c[1],"spot":spot,"result":r})
  h.village_ui.show_page("\u65e5\u5e38")
  h.village_ui.action("friend_claim",{"who":c[0]})
  result.append({"who":c[0],"before":before,"friendship":s.friendship(c[0]),"after":c[3] in s.data.village.blueprints,"notice":h.village_ui.notice})
  await plans(c[3]);await snap(str(c[3])+"-after")
 h.village_ui.close();h.village_ui.checkpoint()
 FileAccess.open(out+"/result.json",FileAccess.WRITE).store_string(JSON.stringify({"mode":"actual Home/InventoryView rendering, normal institution_effect + UI friend_claim transaction, no reward injection; not OS input playthrough","rows":result},"  "))
 h.queue_free();await process_frame;quit(0)
