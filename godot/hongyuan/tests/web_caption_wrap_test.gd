extends SceneTree
const Caption := preload("res://hongyuan/ui/story_caption.gd")
func _initialize() -> void:
	var copy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://hongyuan/copy.json"))
	var failures := 0
	var count := 0
	for key in ["R1-B01-MOTIVE","A4-2b","A3-2q","A3-2r","A3-2s","A3-2t","R1-I02-REUNION","R1-I02-YOU"]:
		for width in [174,220,232,264,308]:
			var original := str(copy[key])
			var wrapped := Caption.wrap_text(original,width,16)
			if wrapped.replace("\n","") != original.replace("\n",""): failures += 1
			for line in wrapped.split("\n"):
				if Caption.FONT.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x > width+0.01: failures += 1
			count += 1
	print("CAPTION_CASES ",count," FAILURES ",failures)
	quit(failures)
