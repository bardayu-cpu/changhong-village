extends SceneTree
const D="/Users/kayra_ayu/Desktop/苏七镇奇缘/cursor-claude-1010/裳泓村/回执/第1轮/设计/夏秋荷塘/v1/"
func _initialize() -> void:
	for name in ["夏秋植物材质.gdshader","麦田热浪.gdshader"]:
		var shader=Shader.new();shader.code=FileAccess.get_file_as_string(D+name)
		var uniforms=shader.get_shader_uniform_list()
		print(name," parser uniforms: ",uniforms.map(func(u):return u.name))
	quit()
