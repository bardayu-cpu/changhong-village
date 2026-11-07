extends Node

func _ready() -> void:
	var destination := "res://hongyuan/player.tscn"
	var saved := preload("res://hongyuan/checkpoint.gd").read()
	if str(saved.get("worldRoute", "")) in ["wedding", "village"]:
		destination = "res://hongyuan/world_entry.tscn"
	if not ProjectSettings.get_setting("application/hongyuan/enabled", true):
		destination = "res://ayu_home/v4/phone_boot.tscn"
	get_tree().change_scene_to_file.call_deferred(destination)
