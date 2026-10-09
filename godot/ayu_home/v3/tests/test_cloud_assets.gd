extends SceneTree
const Store=preload("res://ayu_home/v3/cloud_assets.gd")
const Assets=preload("res://ayu_home/v2/assets.gd")
class FixtureBridge extends Node:
	var calls:=0
	var corrupt:=false
	var offline:=false
	func call_fn(_method:String,data:Dictionary,done:Callable,_timeout:float) -> void:
		calls+=1
		if offline:done.call({"ok":false,"reason":"offline"});return
		var f:=FileAccess.open(data.path,FileAccess.WRITE)
		f.store_buffer(PackedByteArray([1,2,3]) if corrupt else FileAccess.get_file_as_bytes("res://ayu_home/v3/assets/xiduo.png"));f.close();done.call({"ok":true})
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var s:=Store.new();root.add_child(s);s.cache_root="/private/tmp/ayu-v3-cloud-%d/"%Time.get_ticks_usec()
	var bridge:=FixtureBridge.new();root.add_child(bridge)
	var r:=await s.ensure_all(null,{},["xiduo.png"]);assert(r.ok and r.downloaded==0)
	r=await s.ensure_all(bridge,{"xiduo.png":"local-test-fixture"},["xiduo.png"],false);assert(r.ok and r.downloaded==1)
	var local:String=Assets.resolved_paths[Store.P+"xiduo.png"]
	assert(Assets.texture(Store.P+"xiduo.png").get_width()==256)
	bridge.offline=true;r=await s.ensure_all(bridge,{},["xiduo.png"],false);assert(r.ok and bridge.calls==1)
	var f:=FileAccess.open(local,FileAccess.WRITE);f.store_string("corrupt");f.close()
	r=await s.ensure_all(bridge,{"xiduo.png":"local-test-fixture"},["xiduo.png"],false);assert(not r.ok and r.reason=="offline")
	bridge.offline=false;bridge.corrupt=true;r=await s.ensure_all(bridge,{"xiduo.png":"local-test-fixture"},["xiduo.png"],false);assert(not r.ok and r.reason=="checksum_mismatch")
	bridge.corrupt=false;r=await s.ensure_all(bridge,{"xiduo.png":"local-test-fixture"},["xiduo.png"],false);assert(r.ok)
	DirAccess.remove_absolute(local);r=await s.ensure_all(null,{},["xiduo.png"],false);assert(not r.ok and r.reason=="cloud_unconfigured")
	r=await s.ensure_all(bridge,{},["../unexpected.png"]);assert(not r.ok and r.reason=="unknown_asset")
	Assets.resolved_paths.clear();Assets.textures.clear();s.queue_free();bridge.queue_free();await process_frame
	print("RESULT PASS cloud assets: local / verified download / offline cache / corrupt cache / network failure / bad hash / retry / absent ID / unknown name");quit()
