extends Label


func _on_Link_gui_input(event):
	if event is InputEventMouseButton and has_focus():
		if event.button_index == BUTTON_LEFT and !event.pressed:
			OS.shell_open(text)
