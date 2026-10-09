from pathlib import Path
R=Path(__file__).resolve().parents[1];c=R/'godot/ayu_home/v4/core'
p=c/'state.gd';s=p.read_text();s=s.replace('"household":\n\t\t\tv.household=', '''"import_household_inventory":
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
			v.household=''')
s=s.replace('for id in items:text.append("%s×%d"%[C.ITEMS.get(id,id),items[id]])','for id in items:\n\t\tif int(items[id])>0:text.append("%s×%d"%[item_name(id),items[id]])')
s+='''
func item_name(id:String) -> String:
	if C.ITEMS.has(id):return str(C.ITEMS[id])
	var old=preload("res://ayu_home/v4/life_state.gd")
	var key:=id.trim_suffix("_seed")
	return str(old.CROPS[key].name)+("种" if id.ends_with("_seed") else "") if old.CROPS.has(key) else id
func neighbour_request(id:String) -> Dictionary:
	var visits:=int(data.village.helped.get(id,0))
	if id=="honey":return [{"honey":1},{"fruit":2},{"egg":2}][visits%3]
	return [{"flour":1},{"grain":3},{"porridge":1}][visits%3]
'''
s=s.replace('var c:Dictionary=C.NEIGHBOURS[id];var key:=date_key()+":"+id','var c:Dictionary=C.NEIGHBOURS[id].duplicate(true);c.request=neighbour_request(id);var key:=date_key()+":"+id')
p.write_text(s)
p=R/'godot/ayu_home/v4/life_state.gd';s=p.read_text();s=s.replace('var result:Dictionary=shared_state.act("household",{"data":data})','''var stock_delta:Dictionary={}
		for key in ["basket","seeds"]:
			for id in data[key]:
				var delta:=int(data[key].get(id,0))-int(base.get(key,{}).get(id,0))
				if delta!=0:
					var stock_id:String=str(id)+("_seed" if key=="seeds" else "")
					stock_delta[stock_id]=int(stock_delta.get(stock_id,0))+delta
		var result:Dictionary=shared_state.act("household",{"data":data,"stock_delta":stock_delta})
		if not result.ok and not shared_state.data.village.household.is_empty():data=shared_state.data.village.household.duplicate(true)
		sync_inventory()''')
s+='''
func sync_inventory() -> void:
	if shared_state==null:return
	var basket:Dictionary={};var seeds:Dictionary={}
	for id in CROPS:
		if shared_state.count(id)>0:basket[id]=shared_state.count(id)
		seeds[id]=shared_state.count(str(id)+"_seed")
	data.basket=basket;data.seeds=seeds
	base.basket=basket.duplicate(true);base.seeds=seeds.duplicate(true)
''';p.write_text(s)
p=c/'interface.gd';s=p.read_text();s=s.replace('home.life.shared_state=state;home.journal=home.life.data;','''if not state.data.village.get("inventory_migrated",false):state.act("import_household_inventory",{"data":home.life.data})
		home.life.shared_state=state;home.life.sync_inventory();home.journal=home.life.data;''')
s=s.replace('if state.blocked:hud_button.text="生活存档需要检查";return','if state.blocked:hud_button.text="生活存档需要检查";return\n\tif home.life.shared_state!=null:home.life.sync_inventory()')
s=s.replace('var c:Dictionary=C.NEIGHBOURS[context_id];var v:Dictionary=state.data.village','var c:Dictionary=C.NEIGHBOURS[context_id].duplicate(true);c.request=state.neighbour_request(context_id);var v:Dictionary=state.data.village')
p.write_text(s)
p=R/'godot/ayu_home/v4/home.gd';s=p.read_text();s=s.replace('if outcome.get("keep",false):life.data.fish.append({"name":outcome.fish,"at":life.now()})','''if outcome.get("keep",false):
		life.data.fish.append({"name":outcome.fish,"at":life.now()})
		if village_ui!=null:village_ui.state.act("fishing_reward",{"id":str(life.data.fish.size())+":"+str(life.data.fish[-1].at)})''')
p.write_text(s)
# Furniture uses the same original pixel artwork in the editor and physical house.
p=c/'yard.gd';s=p.read_text();a=s.index('\t\tvar wood:=');b=s.index('\nfunc _process',a);s=s[:a]+'''\t\tvar path:String=preload("res://ayu_home/v4/core/world_life.gd").new().furniture_texture(str(f.kind))
		var texture=preload("res://ayu_home/v2/assets.gd").texture(path)
		draw_texture_rect(texture,Rect2(p-Vector2(30,32),Vector2(60,58)),false)
'''+s[b:];s=s.replace('var path:String=preload("res://ayu_home/v4/core/world_life.gd").new().furniture_texture(str(f.kind))','var path:String={"chair":"res://ayu_home/v4/assets/floor1-redraw/living-chair.png","table":"res://ayu_home/v4/assets/floor1-redraw/living-table.png","planter":"res://ayu_home/v3/assets/exterior_pot_window_left.png"}[str(f.kind)]');p.write_text(s)
