extends Node

var Save = load("res://Saveable.gd").new()

var default_colors_path = "res://colors.gd"
var default_font_path = "res://curses_640x300.png"

var game_path = "" setget set_game_path
var colors_path = default_colors_path setget set_colors_path
var font_path = default_font_path setget set_font_path
var packs_paths = [""] setget set_packs_paths

var font_size = Vector2(12,12)

var game_path_is_valid = false
var colors_path_is_valid = false
var font_path_is_valid = false
var packs_paths_is_valid = false

var parsed_font_set = false

var search_depth_up = 3
var search_depth_down = 2
#var sanity_limit = 25

const FONT_FILE_BOUNDS = Vector2(16, 16)
var font_chroma_key = Color(255, 0, 255)

var default_colors = 	{"BLACK": Color(0,0,0),
						"BLUE": Color(0,0,0.501961),
						"GREEN": Color(0,0.501961,0),
						"CYAN": Color(0,0.501961,0.501961),
						"RED": Color(0.501961,0,0),
						"MAGENTA": Color(0.501961,0,0.501961),
						"BROWN": Color(0.501961,0.501961,0),
						"LGRAY": Color(0.752941,0.752941,0.752941),
						"DGRAY": Color(0.501961,0.501961,0.501961),
						"LBLUE": Color(0,0,1),
						"LGREEN": Color(0,1,0),
						"LCYAN": Color(0,1,1),
						"LRED": Color(1,0,0),
						"LMAGENTA": Color(1,0,1),
						"YELLOW": Color(1,1,0),
						"WHITE": Color(1,1,1)
						}
var colors = {}
var parsed_font = null

signal game_path_changed
signal colors_path_changed
signal font_path_changed
signal packs_paths_changed
signal font_parsed

func _ready():
	Save.initialize("Global", ["game_path", "colors_path", "font_path", "packs_paths"], self)

func check_folder(folder):
	var dir = Directory.new()
	return dir.dir_exists(folder)
	
func check_file(file):
	var dir = Directory.new()
	return dir.file_exists(file)
	
func set_font(font):
	if parsed_font != null:
		load("res://MainTheme.tres").default_font = parsed_font.duplicate()
		parsed_font_set = true

func set_game_path(path):
	game_path = path
	game_path_is_valid = check_file(path + "gamelog.txt")
	emit_signal("game_path_changed", path, game_path_is_valid)

	if game_path_is_valid:
		if !check_file(colors_path) or colors_path == default_colors_path:
			self.colors_path = find_colors(game_path)
		if !check_file(font_path) or font_path == default_font_path:
			self.font_path = find_font(game_path)
		
	SaveSystem.prime()
	
func set_colors_path(path):
	colors_path = path
	colors_path_is_valid = parse_colorscheme(path)
	emit_signal("colors_path_changed", path, colors_path_is_valid)
	
	SaveSystem.prime()
	
func set_font_path(path):
	font_path = path
	font_path_is_valid = parse_font(path)
	emit_signal("font_path_changed", path, font_path_is_valid)
	
	SaveSystem.prime()
	
func set_packs_paths(path):
	if path is String:
		packs_paths[0] = path
		packs_paths_is_valid = check_folder(path)
		emit_signal("packs_paths_changed", path, packs_paths_is_valid)
	elif path is Array:
		packs_paths[0] = path[0]
		packs_paths_is_valid = check_folder(path[0])
		emit_signal("packs_paths_changed", path[0], packs_paths_is_valid)
		
	SaveSystem.prime()

func find_game_path():
	#TODO: Doesn't work on exported project, ignore this for now
	return ""
	
	var dir = Directory.new()
	var folders_to_search = []
	
	var app_folder = ProjectSettings.globalize_path("res://")
	folders_to_search.append(get_parent_folder(app_folder, search_depth_up))
	var base_depth = folders_to_search[0].split("/").size()
	
	while !folders_to_search.empty():
		var path = folders_to_search.pop_front()
		dir.open(path)
		dir.list_dir_begin(true, true)
		var instance = dir.get_next()
		
		while instance != "":
			print("Searching %s%s" % [path, instance])
			var depth = (path + instance).split("/").size()
			if dir.current_is_dir():
				if (depth - base_depth) <= search_depth_down:
					folders_to_search.append(path + instance + "/")
					instance = dir.get_next()
				else:
					#print("Too deep! %s %s/%s" % [path + instance, depth - base_depth, search_depth_down])
					instance = dir.get_next()
			elif instance == "gamelog.txt":
				print("Game path is %s" % path)
				dir.list_dir_end()
				game_path_is_valid = true
				return path
			else:
				instance = dir.get_next()
				
		dir.list_dir_end()
	
	print("Couldn't find game path!")
	game_path_is_valid = false
	return ""
	
func find_colors(path):
	var new_path = ""
	
	var file = File.new()
	if file.file_exists(path + "data/init/colors.txt"):
		new_path = path + "data/init/colors.txt"
	else:
		new_path = default_colors_path
	
	return new_path
	
func find_font(path):
	var new_path = ""
	
	var file = File.new()
	if file.file_exists(path + "data/init/init.txt"):
		file.open(path + "data/init/init.txt", file.READ)
		var init = file.get_as_text()
		file.close()
		
		var windowed = false
		var graphics = false
		
		var regex = RegEx.new()
		regex.compile("\\[WINDOWED:(.*)\\]")
		
		match regex.search(init).get_string(1):
			"YES":
				windowed = true
			"NO":
				windowed = false
		
		regex.clear()
		regex.compile("\\[GRAPHICS:(.*)\\]")
		
		match regex.search(init).get_string(1):
			"YES":
				graphics = true
			"NO":
				graphics = false
				
		regex.clear()
				
		if windowed:
			if graphics:
				regex.compile("\\[GRAPHICS_FONT:(.*)\\]")
			else:
				regex.compile("\\[FONT:(.*)\\]")
		else:
			if graphics:
				regex.compile("\\[GRAPHICS_FULLFONT:(.*)\\]")
			else:
				regex.compile("\\[FULLFONT:(.*)\\]")
				
		var font = regex.search(init).get_string(1)
		
		new_path = game_path + "data/art/%s" % font
		
	else:
		new_path = default_font_path #ProjectSettings.globalize_path(default_font_path)
		
	print("Font path is %s" % new_path)
	return new_path
	
func parse_font(path):
	var src_img
	var error = OK
	
	if path == default_font_path:
		src_img = load(path)
	else:
		src_img = Image.new()
		error = src_img.load(path)
	
	if error == OK:
		var img_data = src_img.get_data()
		var new_data = PoolByteArray()
		
		#print("Image Format: %s" % src_img.get_format())
		#Generate our own image with alpha based on the original
		match src_img.get_format():
			Image.FORMAT_RGB8:
				for pp in range(0, img_data.size(), 3):
					#print("R:%s, G:%s, B:%s" % [img_data[pp], img_data[pp+1], img_data[pp+2]]) 
					new_data.append(img_data[pp])
					new_data.append(img_data[pp+1])
					new_data.append(img_data[pp+2])
					var pixel = Color(img_data[pp], img_data[pp+1], img_data[pp+2])
					if pixel == font_chroma_key:
						new_data.append(0)
					else:
						new_data.append(255)
						
			Image.FORMAT_RGBA8:
				for pp in range(0, img_data.size(), 4):
					#print("R:%s, G:%s, B:%s, A:%s" % [img_data[pp], img_data[pp+1], img_data[pp+2], img_data[pp+3]]) 
					new_data.append(img_data[pp])
					new_data.append(img_data[pp+1])
					new_data.append(img_data[pp+2])
					var pixel = Color(img_data[pp], img_data[pp+1], img_data[pp+2])
					if pixel == font_chroma_key:
						new_data.append(0)
					else:
						new_data.append(img_data[pp+3])
			_:
				print("Invalid image format (%s)" % src_img.get_format())
				self.font_path = default_font_path
				return false
					
		var font_img = Image.new()
		font_img.create_from_data(src_img.get_width(), src_img.get_height(), false, Image.FORMAT_RGBA8, new_data)
		var font_tex = ImageTexture.new()
		var font = BitmapFont.new()
		font_tex.create_from_image(font_img)
		
		font.add_texture(font_tex)
		#Determine font size
		font_size = font_tex.get_size() / FONT_FILE_BOUNDS
		font.height = font_size.y
		
		#Build font
		var pos = Vector2(0,0)
		var num = 0
		for yy in FONT_FILE_BOUNDS.y:
			for xx in FONT_FILE_BOUNDS.x:
				font.add_char(num, 0, Rect2(pos * font_size, font_size))
				#print("Adding character %s (%s)" % [num, Rect2(pos * font_size, font_size)])
				num += 1
				pos.x += 1
			pos.y += 1
			pos.x = 0
		
		parsed_font = font
		parsed_font_set = false
		emit_signal("font_parsed")
		print("Font parsed!")
		return true
	else:
		self.font_path = default_font_path
		return false
		
func parse_colorscheme(path):
	var new_colors = {}
	
	var error = OK
	var text = ""
	
	if path == default_colors_path:
		colors = default_colors
		return true
	else:
		var file = File.new()
		error = file.open(path, File.READ)
		if error == OK:
			text = file.get_as_text()
			file.close()

	if error == OK:
		var regex = RegEx.new()
		regex.compile("\\[(.+)_(.)\\:(.+)\\]")
		
		var results = regex.search_all(text)
		
		if results.size() <= 0:
			return false
		#1: Color name, 2: Color channel, 3: Value
		for rr in results:
			var color = rr.get_string(1)
			var channel = rr.get_string(2)
			var value = rr.get_string(3)
			
			if !new_colors.has(color):
				new_colors[color] = Color()
				
			match channel:
				"R":
					new_colors[color].r8 = int(value)
				"G":
					new_colors[color].g8 = int(value)
				"B":
					new_colors[color].b8 = int(value)
		
		#for color in new_colors.keys():
		#	print("\"%s\": Color(%s,%s,%s), " % [color, new_colors[color].r, new_colors[color].g, new_colors[color].b])

		colors = new_colors
		return true
	else:
		print("No color scheme found!")
		return false
	
func update_maintheme():
	VisualServer.set_default_clear_color(colors.BLACK)
	
	#for tt in types:
	#	var typecolors = theme.get_color_list(tt)
		
	#	for ttc in typecolors:
	#		theme.set_color(ttc, tt, colors.WHITE)
	
func get_parent_folder(path, depth):
	if path.ends_with("/"):
		path = path.substr(0, path.length() - 1)
			
	for dd in depth:
		var pos = path.find_last("/")
		path = path.left(pos)
		
	return path + "/"
	
