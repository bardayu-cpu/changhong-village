extends SceneTree
const World=preload("res://ayu_home/v4/world.gd")
const Assets=preload("res://ayu_home/v2/assets.gd")
const Data=preload("res://ayu_home/home_data.gd")
const REPORT="res://../回执/第1轮/春季v1-资源与参数核对.json"
var results:Array=[]
var failures:=0
func check(ok:bool,label:String) -> void:
	results.append({"check":label,"pass":ok})
	if not ok:failures+=1
	print(("PASS " if ok else "FAIL ")+label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var contract:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../回执/第1轮/设计/春季补强/v1/C2春季接入-v1.json"))
	var w:=World.new();root.add_child(w);w.set_process(false);w.load_room("village")
	var bindings:Dictionary=w.get_village_spring_bindings()
	var masks_ok:=true
	for entry in contract.texture_bindings:
		var tex:Texture2D=Assets.texture(str(entry.mask_target))
		masks_ok=masks_ok and tex!=null and tex.get_size()==Vector2(entry.mask_size[0],entry.mask_size[1])
	check(masks_ok and bindings.textures.size()==50,"all 50 authored masks load at approved dimensions")
	check(w.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST,"world retains nearest filtering")
	var ground_binding:Dictionary=bindings.textures[w.asset_path(w.cfg.background)]
	check(w.base_sprite.material==w.season_material and w.season_material.shader==World.SPRING_SHADER and w.season_material.get_shader_parameter("spring_plant_mask")==Assets.texture(ground_binding.mask) and w.season_material.get_shader_parameter("spring_layer_kind")==0,"background uses only the ground mask and layer 0")
	var props_ok:=true;var registration_ok:=true;var isolation_ok:=true;var positions_ok:=true
	var material_keys:Dictionary={};var prop_rows:Array=[]
	for prop in w.props:
		var b:Dictionary=bindings.props[prop.config.id]
		var m:ShaderMaterial=prop.sprite.material
		var mask:Texture2D=Assets.texture(bindings.textures[b.texture].mask)
		props_ok=props_ok and m.shader==World.SPRING_SHADER and m.get_shader_parameter("spring_plant_mask")==mask and m.get_shader_parameter("plant_kind")==int(b.plant_kind) and m.get_shader_parameter("spring_layer_kind")==int(b.spring_layer_kind) and m.get_shader_parameter("spring_mask_enabled")==true
		registration_ok=registration_ok and w.plant_materials.has(m)
		isolation_ok=isolation_ok and m!=w.season_material
		positions_ok=positions_ok and prop.root.position==Vector2(0,prop.config.foot) and prop.sprite.position==Vector2(prop.config.pos[0],prop.config.pos[1])-prop.root.position and prop.sprite.texture==Assets.texture(w.asset_path(prop.config.file))
		var key:String=str(b.texture)+"|"+str(int(b.plant_kind))+"|"+str(int(b.spring_layer_kind))
		if material_keys.has(key):isolation_ok=isolation_ok and material_keys[key]==m
		else:material_keys[key]=m
		prop_rows.append({"id":prop.config.id,"mask":bindings.textures[b.texture].mask,"plant_kind":b.plant_kind,"spring_layer_kind":b.spring_layer_kind})
	check(props_ok and w.props.size()==50,"all 50 props bind their own approved source mask, plant kind and layer")
	check(isolation_ok and w.plant_materials.size()==material_keys.size(),"no prop shares ground material; same source/kind/layer reuses one material")
	check(registration_ok,"every prop material registered in existing season/rain update path")
	check(positions_ok,"source textures and authored prop positions remain exact")
	var expected_nodes:int=5+w.cfg.props.size()*2+w.cfg.lamps.size()+w.tap_layers.size()
	check(w.find_children("*","",true,false).size()==expected_nodes,"no spring sprites or scene nodes added")
	var all_materials:Array=[w.season_material]+w.plant_materials
	var samples:Array=[];var updates_ok:=true
	for sample in [[4,"clear",true],[4,"rain",true],[7,"clear",true],[10,"clear",true],[1,"snow",true],[1,"rain",true],[4,"rain",false]]:
		w.month=sample[0];w.weather=sample[1];w.effects_enabled=sample[2];w.update_light()
		var expected_season:int=Data.season(w.month) if w.effects_enabled else 1
		var expected_rain:float=1.0 if w.weather=="rain" and w.effects_enabled else 0.0
		for m in all_materials:updates_ok=updates_ok and m.get_shader_parameter("season")==expected_season and m.get_shader_parameter("rain")==expected_rain
		samples.append({"month":w.month,"weather":w.weather,"effects_enabled":w.effects_enabled,"season":expected_season,"rain":expected_rain})
	check(updates_ok,"all materials receive seven seasonal/weather/effects parameter combinations")
	var missing:=w.make_village_season_material("res://missing-spring-source.png",0,1)
	var rejected:=w.make_village_season_material(w.asset_path(w.cfg.props[0].file),0,1,false)
	check(missing.get_shader_parameter("spring_mask_enabled")==true and missing.get_shader_parameter("spring_plant_mask")==World.black_spring_mask and World.black_spring_mask.get_size()==Vector2.ONE and rejected.get_shader_parameter("spring_plant_mask")==World.black_spring_mask,"missing or mismatched binding fails closed with enabled black mask")
	var uniform_count:int=World.SPRING_SHADER.get_shader_uniform_list().size()
	var old_shader_code:String=w.make_season_material().shader.code
	for area in ["exterior","side_path","bridge","oldhouse","grove","my_yard","garden"]:
		w.load_room(area)
		var isolated:bool=w.village_material_cache.is_empty()
		if area=="garden":isolated=isolated and w.season_material==null
		else:
			isolated=isolated and w.season_material.shader.code==old_shader_code and w.season_material.shader!=World.SPRING_SHADER
			for prop in w.props:isolated=isolated and prop.sprite.material.shader!=World.SPRING_SHADER
		check(isolated,"other outdoor retains its original material: "+area)
	w.load_room("village")
	check(w.village_material_cache.size()==50 and w.plant_materials.size()==49,"returning to village rebuilds exactly 50 materials without stale room bindings")
	var report={"mode":"headless; dummy renderer; not a screenshot/GPU/performance acceptance","checks":results,"failures":failures,"shader_uniform_count_reported_by_headless":uniform_count,"props":prop_rows,"season_parameter_samples":samples,"pending":"C3 actual N3 spring/summer at gate and fields, autumn/winter, passage and performance; N6 and WTH on same stable commit"}
	var out:=FileAccess.open(REPORT,FileAccess.WRITE);out.store_string(JSON.stringify(report,"\t")+"\n");out.close()
	w.queue_free();await process_frame
	print("SPRING ","PASS" if failures==0 else "FAIL"," ",results.size()," targeted checks; real-window N3 remains C3")
	quit(0 if failures==0 else 1)
