extends SceneTree
const Home=preload("res://ayu_home/v4/home.gd")
const Assets=preload("res://ayu_home/v2/assets.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var vp:=SubViewport.new();vp.size=Vector2i(540,960);vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp)
	var h=Home.new();h.save_path="/private/tmp/ayu-clarity-probe.json";h.town_profile={"id":"clarity-probe","avatar":2};vp.add_child(h);await process_frame;h.set_process(false);h.close_modal();h.set_test_clock(12.25);h.admitted=true;h.enter_room("dining",false);h.player.position=Vector2(262,318);h.camera=h.player.position-Vector2(0,65);h.layout()
	var guide:=Assets.texture("res://ayu_home/v3/assets/floor1-clear.png")
	for kind in ["bounded","guide"]:
		var shader:=Shader.new();shader.code="shader_type canvas_item; uniform sampler2D guide_tex:filter_nearest; uniform vec2 source_origin=vec2(0.0); uniform bool bounded=true;void fragment(){vec4 c=texture(TEXTURE,UV);vec2 g=(source_origin+UV/TEXTURE_PIXEL_SIZE)/vec2(1448.0,1086.0);vec3 target=texture(guide_tex,g).rgb;COLOR=vec4(bounded?clamp(target,c.rgb-vec3(12.0/255.0),c.rgb+vec3(12.0/255.0)):target,c.a);}"
		var mat:=ShaderMaterial.new();mat.shader=shader;mat.set_shader_parameter("guide_tex",guide);mat.set_shader_parameter("bounded",kind=="bounded");h.world.base_sprite.material=mat
		for p in h.world.props:
			var pm:=mat.duplicate();var b:Array=p.config.source_box;pm.set_shader_parameter("source_origin",Vector2(b[0],b[1]));p.sprite.material=pm
		await process_frame;await process_frame;RenderingServer.force_draw(false);vp.get_texture().get_image().save_png("res://ayu_home/v4/evidence/panels/clarity-"+kind+".png")
	h.stop_audio();print("RESULT PASS clarity probe");quit()
