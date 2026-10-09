extends RefCounted
## Decode each original PNG once. Verified cloud paths may replace packaged files.
static var textures: Dictionary = {}
static var sounds: Dictionary = {}
static var resolved_paths: Dictionary = {}
static var used: Dictionary = {} # 运行时真用到了哪些图和声音（量包体、列云上清单用）
static func texture(path: String) -> Texture2D:
	used[path]=true
	if textures.has(path):return textures[path]
	var source:String=resolved_paths.get(path,path)
	# Exported Godot packs remap PNG to lossless CompressedTexture2D. Loading
	# that resource avoids nonexistent source PNGs and any GPU readback.
	if not FileAccess.file_exists(source) and ResourceLoader.exists(path):
		var packed:=load(path) as Texture2D
		if packed:textures[path]=packed
		return packed
	var im:=Image.new()
	var bytes:=FileAccess.get_file_as_bytes(source)
	# 手机上从云上下来的是无损 WebP（tools/ayu_cloud_pack.py），工程里是 PNG
	if (im.load_webp_from_buffer(bytes) if source.get_extension()=="webp" else im.load_png_from_buffer(bytes))!=OK:return null
	var tex:=ImageTexture.create_from_image(im);textures[path]=tex;return tex
static func sound(path: String) -> AudioStreamWAV:
	used[path]=true
	if sounds.has(path):return sounds[path]
	var source:String=resolved_paths.get(path,path)
	if not FileAccess.file_exists(source) and ResourceLoader.exists(path):
		var packed:=load(path) as AudioStreamWAV
		if packed:sounds[path]=packed
		return packed
	var bytes:=FileAccess.get_file_as_bytes(source)
	if bytes.size()<44:return null
	var stream:=AudioStreamWAV.new();stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.mix_rate=22050;stream.stereo=false;stream.data=bytes.slice(44);sounds[path]=stream;return stream
