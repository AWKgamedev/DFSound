extends Node

func _ready():
	if Global.game_path == "":
		Global.game_path = Global.find_game_path()
	
	Global.parse_colorscheme(Global.colors_path)
	
	if !Global.game_path_is_valid:
		Global.parse_font(Global.font_path)
		
	Global.set_font(Global.parsed_font)
	Global.update_maintheme()
	
	get_tree().add_user_signal("sound_playing", [{"name": "SoundNode", "type": Node}])
	get_tree().add_user_signal("sound_stopping", [{"name": "SoundNode", "type": Node}])
	get_tree().add_user_signal("sound_pausing", [{"name": "SoundNode", "type": Node}])
	
	get_tree().change_scene("res://Base.tscn")