extends HBoxContainer

enum ButtonType {DFFOLDER, COLORS, FONT, PACKS}

export(ButtonType) var button_type

var last_path = ""

signal search_button_pressed
signal file_button_pressed
signal text_entered

func _ready():
	#TODO Placeholder, make a main script that takes care of all style colors and duplication
	$LineEdit.set("custom_styles/normal", load("res://MainTheme.tres").get("LineEdit/styles/normal").duplicate())
	$LineEdit.set("custom_styles/focus", load("res://MainTheme.tres").get("LineEdit/styles/focus").duplicate())
		
	match button_type:
		ButtonType.DFFOLDER:
			$Label.text = "Dwarf Fortress Folder"
			$LineEdit.text = Global.game_path
			Global.connect("game_path_changed", self, "path_changed")
		ButtonType.COLORS:
			$Label.text = "Colors.txt"
			if Global.colors_path == Global.default_colors_path:
				$LineEdit.text = ""
			else:
				$LineEdit.text = Global.colors_path
			Global.connect("colors_path_changed", self, "path_changed")
		ButtonType.FONT:
			$Label.text = "Font"
			if Global.font_path == Global.default_font_path:
				$LineEdit.text == ""
			else:
				$LineEdit.text = Global.font_path
			Global.connect("font_path_changed", self, "path_changed")
		ButtonType.PACKS:
			$Label.text = "Packs"
			$LineEdit.text = Global.packs_paths[0]
			Global.connect("packs_paths_changed", self, "path_changed")

func _on_SearchButton_pressed():
	emit_signal("search_button_pressed", self)

func _on_FileButton_pressed():
	emit_signal("file_button_pressed", self)
	
func set_text(text):
	$LineEdit.text = text
	
func set_normal_color(color):
	$LineEdit.get("custom_styles/normal").border_color = color
	
func set_focus_color(color):
	$LineEdit.get("custom_styles/focus").border_color = color

func _on_LineEdit_text_entered(new_text):
	emit_signal("text_entered", self, new_text)
	
func path_changed(path, valid):
	if !path == last_path:
		last_path = path
		$LineEdit.text = path
		if valid:
			set_focus_color(load("res://MainTheme.tres").get("LineEdit/styles/focus").border_color)
			set_normal_color(load("res://MainTheme.tres").get("LineEdit/styles/normal").border_color)
			match button_type:
				ButtonType.FONT:
					show_reload_prompt("Font change requires reload, this will stop all audio")
				ButtonType.COLORS:
					show_reload_prompt("Colorscheme change requires reload, this will stop all audio")
		else:
			set_focus_color(Global.colors.LRED)
			set_normal_color(Global.colors.RED)
			$RestartButton.visible = false
		
func show_reload_prompt(message):
	set_normal_color(Global.colors.YELLOW)
	set_focus_color(Global.colors.YELLOW)
	$RestartButton.visible = true
	$RestartButton.hint_tooltip = message

func _on_RestartButton_pressed():
	Global.set_font(Global.parsed_font)
	get_tree().reload_current_scene()