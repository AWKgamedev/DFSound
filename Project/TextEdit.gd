extends TextEdit

var input_texts = []
var history_position = -1

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func _input(event):
	if event.is_action_pressed("ui_accept") and has_focus():
		connect("text_changed", self, "deferred_cleanup", [], CONNECT_DEFERRED)
		
		if (input_texts.size() == 0 or input_texts[0] != text) and text != "":
			input_texts.push_front(text)
			
		get_tree().get_root().get_node("Base/Logger").insert_string(text)
		
		history_position = -1
		
	elif event.is_action_pressed("ui_up"):
		history_position = wrapi(history_position + 1, -1, input_texts.size())
		
		if history_position == -1:
			text = ""
		else:
			text = input_texts[history_position]
		
	elif event.is_action_pressed("ui_down"):
		history_position = wrapi(history_position - 1, -1, input_texts.size())
		
		if history_position == -1:
			text = ""
		else:
			text = input_texts[history_position]
		
func deferred_cleanup():
	text = ""
	disconnect("text_changed", self, "deferred_cleanup")