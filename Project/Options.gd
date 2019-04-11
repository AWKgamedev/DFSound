extends MarginContainer

var filedialog = null
onready var Logger = get_tree().get_root().find_node("Logger", true, false)

var current_node = null

func _ready():	
	var filelines = get_tree().get_nodes_in_group("OptionsFileLine")
	
	for ff in filelines:
		ff.connect("file_button_pressed", self, "file_button_pressed")
		ff.connect("search_button_pressed", self, "search_button_pressed")
		ff.connect("text_entered", self, "text_entered")
		
func file_button_pressed(node):
	if filedialog != null:
		filedialog.queue_free()
	filedialog = FileDialog.new()
	
	get_tree().get_root().add_child(filedialog)
	
	var children = filedialog.get_children()

	while children.size() > 0:
		var cc = children.pop_back()
		children = children + cc.get_children()
		if cc.get("text"):
			if cc.text == "Create Folder" or cc.text == "All Files (*)":
				cc.queue_free()
				
	filedialog.connect("dir_selected", self, "dir_selected")
	filedialog.connect("file_selected", self, "file_selected")
	filedialog.connect("popup_hide", self, "dialog_closed")
	filedialog.resizable = true
				
	filedialog.popup_centered(Vector2(410, 500))
	
	var mode = FileDialog.MODE_OPEN_DIR
	var dir = ""
	var access = FileDialog.ACCESS_FILESYSTEM
	var title = ""
	
	match node.button_type:
		node.ButtonType.DFFOLDER:
			if Global.check_folder(Global.game_path):
				dir = Global.game_path.get_base_dir().get_base_dir()
			mode = FileDialog.MODE_OPEN_DIR
			title = "Select DF Folder"
		node.ButtonType.COLORS:
			if Global.check_file(Global.colors_path):
				dir = Global.colors_path.get_base_dir()
			mode = FileDialog.MODE_OPEN_FILE
			title = "Select Colors.txt"
		node.ButtonType.FONT:
			if Global.check_file(Global.font_path):
				dir = Global.font_path.get_base_dir()
			mode = FileDialog.MODE_OPEN_FILE
			title = "Select Font"
		node.ButtonType.PACKS:
			if Global.check_folder(Global.packs_paths[0]):
				dir = Global.packs_paths[0].get_base_dir().get_base_dir()
			mode = FileDialog.MODE_OPEN_DIR
			title = "Select Packs"
			
	current_node = node
	filedialog.mode = mode
	filedialog.access = access
	filedialog.window_title = title
	filedialog.current_dir = dir
	
func text_entered(node, text):
	current_node = node
	match node.button_type:
		node.ButtonType.DFFOLDER:
			text = text.replace("\\", "/")
			if !text.ends_with("/"):
				text += "/"
			Global.game_path = text
			
		node.ButtonType.COLORS:
			Global.colors_path = text
			
		node.ButtonType.FONT:
			Global.font_path = text
			
		node.ButtonType.PACKS:
			text = text.replace("\\", "/")
			if !text.ends_with("/"):
				text += "/"
			Global.packs_paths = text

func dir_selected(dir):
	match current_node.button_type:
		current_node.ButtonType.DFFOLDER:
			dir = dir.replace("\\", "/")
			if !dir.ends_with("/"):
				dir += "/"
			Global.game_path = dir
			
		current_node.ButtonType.PACKS:
			dir = dir.replace("\\", "/")
			if !dir.ends_with("/"):
				dir += "/"
			Global.packs_paths = dir
	
func file_selected(path):
	match current_node.button_type:
		current_node.ButtonType.COLORS:
			Global.colors_path = path
			
		current_node.ButtonType.FONT:
			Global.font_path = path
	
func dialog_closed():
	filedialog.queue_free()
	filedialog = null
		
func msg(text):
	var Debug = get_tree().get_root().find_node("Debug", true, false)
	Debug.msg(text, self, "gray")