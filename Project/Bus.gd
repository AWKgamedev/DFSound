extends MarginContainer

onready var Main = get_tree().get_root().get_node("Base/Logger")
onready var Debug = get_tree().get_root().find_node("Debug", true, false)
onready var tree = find_node("SoundTree")
var Save = load("res://Saveable.gd").new()

var bus = "" setget set_bus
var bus_index = -1

var bus_volume = 0

var bus_current_volume_db = [0, 0]

#Status  are prioritized by their position here, top being top priority
enum Status {PLAYING, IGNORED_PLAYING, MUTED_PLAYING, PLAYED, IGNORED_PLAYED, MUTED_PLAYED, IGNORED_NOTPLAYED, MUTED_NOTPLAYED, NOTPLAYED}
				
#BLACK, BLUE, GREEN, CYAN, RED, MAGENTA, BROWN, LGRAY, DGRAY, LBLUE, LGREEN, LCYAN, LRED, LMAGENTA, YELLOW, WHITE
								#color, upwards recursion, downwards recursion
onready var status_colors = {	Status.NOTPLAYED: [Global.colors.LGRAY, true, false], 
								Status.PLAYING: [Global.colors.GREEN, true, false],
								Status.PLAYED: [Global.colors.WHITE, true, false],
								Status.IGNORED_NOTPLAYED: [Global.colors.RED, false, true],
								Status.IGNORED_PLAYING: [Global.colors.LRED, false, true],
								Status.IGNORED_PLAYED: [Global.colors.RED, false, true],
								Status.MUTED_NOTPLAYED: [Global.colors.DGRAY, false, true],
								Status.MUTED_PLAYING: [Global.colors.DGRAY, false, true],
								Status.MUTED_PLAYED: [Global.colors.DGRAY, false, true],
							}
							
var volume_range = [-80, 6]

var playing_items = []

func _ready():
	get_tree().connect("sound_playing", self, "check_starting_sound", [])
	get_tree().connect("sound_stopping", self, "check_stopping_sound", [])
	get_tree().connect("sound_pausing", self, "check_pausing_sound", [])
	#tree.set("custom_constants/vseparation", Global.font_size.y)
	
	$LabelPosition/VolumeLabel.set("custom_colors/font_color", Global.colors.LGRAY)
	
func check_starting_sound(sound):
	#msg("Checking starting sound %s" % sound)
	if sound.my_event.bus == bus:
		var item = tree_create_item(Main.ItemType.SOUNDFILE, bus, "", "", sound.my_event, sound.picked_sound_UID)
		tree_set_status(item, Status.PLAYING, sound)
		update_status_tree()
		#var rect = msg(tree.get_item_area_rect(item))
		
func check_stopping_sound(sound):
	if sound.my_event.bus == bus:
		var item = tree_create_item(Main.ItemType.SOUNDFILE, bus, "", "", sound.my_event, sound.picked_sound_UID)
		tree_set_status(item, Status.PLAYED, sound)
		item.set_text(0, item.get_metadata(0).filePath.get_file())
		update_status_tree()
		#var rect = msg(tree.get_item_area_rect(item))
	
func set_bus(b):
	bus = b
	bus_index = AudioServer.get_bus_index(b)
	
	Save.initialize("Bus_" + bus, ["bus_volume"], self)
	
	find_node("BusName").text = b
	$"HBoxContainer/VolumeSlider".min_value = volume_range[0]
	$"HBoxContainer/VolumeSlider".max_value = volume_range[1]
	$"HBoxContainer/VolumeSlider".value = clamp(bus_volume, volume_range[0], volume_range[1])
	_on_VolumeSlider_value_changed($"HBoxContainer/VolumeSlider".value)
	AudioServer.set_bus_volume_db(bus_index, bus_volume)
	
	tree = find_node("SoundTree")
	tree.set_column_expand(0, true)
	tree.create_item()
	tree.get_root().set_metadata(0, {})
	
func tree_create_item(type = Main.ItemType, bus = "", title = "", path = "", event = {}, sound_UID = 0):
	match type:
		Main.ItemType.BUS:
			var child = tree.get_root().get_children()
			
			while child != null:
				if child.get_parent() == tree.get_root():
					if child.get_text(0) == bus:
						#msg("Bus already exists")
						return child
					else:
						child = child.get_next()
				else:
					child = null
			
			var new = tree.create_item()
			new.set_text(0, bus)
			new.set_icon(0, load("res://IconBus.png"))
			new.collapsed = true
			new.set_selectable(0, false)
			new.set_metadata(0, {})
			new.get_metadata(0).itemtype = type
			new.get_metadata(0).UID = str(bus).md5_text()
			new.get_metadata(0).tree_status = Status.NOTPLAYED
			
			if !Main.UIDdatabase.has([new.get_metadata(0).UID]):
				Main.UIDdatabase[new.get_metadata(0).UID] = {}
			
			return new
			
		Main.ItemType.FILE:
			var treebus = tree_create_item(Main.ItemType.BUS, bus)
			var child = treebus.get_children()
			
			while child != null:
				if child.get_parent() == treebus:
					if child.get_tooltip(0) == path:
						#msg("File already exists")
						return child
					else:
						child = child.get_next()
				else:
					child = null
			
			var new = tree.create_item(treebus)
			new.set_text(0, title)
			new.set_tooltip(0, path)
			new.set_icon(0, load("res://IconFile.png"))
			new.collapsed = true
			new.set_selectable(0, false)
			new.set_metadata(0, {})
			new.get_metadata(0).itemtype = type
			new.get_metadata(0).UID = str(path).md5_text()
			new.get_metadata(0).tree_status = Status.NOTPLAYED
			
			if !Main.UIDdatabase.has([new.get_metadata(0).UID]):
				Main.UIDdatabase[new.get_metadata(0).UID] = {}
			
			return new
			
		Main.ItemType.EVENT:
			var treefile = tree_create_item(Main.ItemType.FILE, bus, event.xmlPath.get_file(), event.xmlPath)
			var child = treefile.get_children()
			
			while child != null:
				if child.get_parent() == treefile:
					if child.get_metadata(0).UID == event.UID:
						#msg("Event already exists")
						return child
					else:
						child = child.get_next()
				else:
					child = null
			
			var new = tree.create_item(treefile)
			new.set_text(0, event.pattern.get_pattern())
			new.set_tooltip(0, path)
			new.set_icon(0, load("res://IconEvent.png"))
			new.collapsed = true
			new.set_selectable(0, false)
			new.set_metadata(0, {})
			new.get_metadata(0).itemtype = type
			new.get_metadata(0).UID = event.UID
			new.get_metadata(0).tree_status = Status.NOTPLAYED
			
			for ff in event.soundfiles:
				var newfile = tree.create_item(new)
				newfile.set_text(0, ff.filePath.get_file())
				newfile.set_tooltip(0, ff.filePath)
				newfile.set_icon(0, load("res://IconSoundFile.png"))
				#newfile.set_selectable(0, false)
				newfile.set_metadata(0, {})
				newfile.get_metadata(0).filePath = ff.filePath
				newfile.get_metadata(0).itemtype = Main.ItemType.SOUNDFILE
				newfile.get_metadata(0).UID = ff.UID
				newfile.get_metadata(0).tree_status = Status.NOTPLAYED
			
			return new
			
		Main.ItemType.SOUNDFILE:
			var treeevent = tree_create_item(Main.ItemType.EVENT, bus, "", "", event)
			var child = treeevent.get_children()
			
			while child != null or child.get_parent() != treeevent:
				if child.get_metadata(0).UID == sound_UID:
					return child
				child = child.get_next()
				
			breakpoint
			
func tree_set_status(item = TreeItem, status = Status, soundnode = AudioStreamPlayer2D):
	item.get_metadata(0).status = status
	
	match status:
		Status.PLAYING:
			item.get_metadata(0).soundnode = soundnode
		Status.IGNORED_PLAYING:
			item.get_metadata(0).soundnode = soundnode
		
func update_status_tree():
	var all_items = get_item_children(tree.get_root(), true)
	playing_items = []
	
	for ii in all_items:
		ii.get_metadata(0).tree_status = Status.NOTPLAYED
	
	for ii in all_items:
		var ignored = false
		var playing = Status.NOTPLAYED
		var status = Status.NOTPLAYED
		
		if ii.get_metadata(0).has("status"):
			playing = ii.get_metadata(0).status
		
		#msg("UID: %s, Item %s" % [ii.get_metadata(0).UID, ii.get_text(0)])
		
		if Main.UIDdatabase.has(ii.get_metadata(0).UID):
			if Main.UIDdatabase[ii.get_metadata(0).UID].has("ignored"):
				ignored = Main.UIDdatabase[ii.get_metadata(0).UID].ignored
			
		if ignored:
			match playing:
				Status.NOTPLAYED:
					status = Status.IGNORED_NOTPLAYED
				Status.PLAYING:
					status = Status.IGNORED_PLAYING
				Status.PLAYED:
					status = Status.IGNORED_PLAYED
		else:
			status = playing
			
		match status:
			Status.PLAYING:
				playing_items.append(ii)
			Status.IGNORED_PLAYING:
				playing_items.append(ii)
			#msg("Appended item")
		var recursion = true
		
		if status > ii.get_metadata(0).tree_status:
			status = ii.get_metadata(0).tree_status
			recursion = false
		
		ii.set_custom_color(0, status_colors[status][0])
		
		#Upwards recursion
		if status_colors[status][1] and recursion:
			var parents = get_item_parents(ii)
			
			for pp in parents:
				if pp.get_metadata(0).has("tree_status"):
					if pp.get_metadata(0).tree_status > status:
						#msg("Setting %s's color to %s" % [pp.get_text(0), status_colors[status][0]])
						pp.set_custom_color(0, status_colors[status][0])
						pp.get_metadata(0).tree_status = status
				else:
					#msg("Setting %s's color to %s" % [pp.get_text(0), status_colors[status][0]])
					pp.set_custom_color(0, status_colors[status][0])
					pp.get_metadata(0).tree_status = status
					
	update_tree_height()

func get_item_children(item, recursive = true):
	var child = item.get_children()
	var children = []
	
	while child != null:
		if child.get_parent() == item:
			children.append(child)
			child = child.get_next()
		else:
			child = null
		
	if recursive:
		for cc in children:
			children += get_item_children(cc, true)
			
	return children
	
func get_item_parents(item):
	var parents = []
	var parent = item.get_parent()
	
	while parent != tree.get_root():
		parents.append(parent)
		parent = parent.get_parent()
	
	parents.append(parent)
	
	return parents
	
func _process(delta):
	if bus_index != -1:
		var left = AudioServer.get_bus_peak_volume_left_db(bus_index, 0)
		var right = AudioServer.get_bus_peak_volume_right_db(bus_index, 0)
		
		if left != bus_current_volume_db[0]:
			find_node("VolumeBarL").value = ((left - volume_range[0]) / (volume_range[1]-volume_range[0])) * 100
			bus_current_volume_db[0] = left
		if right != bus_current_volume_db[1]:
			find_node("VolumeBarR").value = ((right - volume_range[0]) / (volume_range[1]-volume_range[0])) * 100
			bus_current_volume_db[1] = right
	
	#update_tree_height()
	update_playing_items()
	
func update_playing_items():
	for pp in playing_items:
		var length = pp.get_metadata(0).soundnode.stream.get_length()
		var position = pp.get_metadata(0).soundnode.get_playback_position()
		var length_left = length - position
		
		var seconds = wrapf(length_left * 10, 0, 600) / 10
		var minutes = int(length_left / 60)
		seconds = floor(seconds * 10) / 10
		
		if seconds < 10:
			seconds = "%.1f" % seconds
			seconds = "0" + seconds
		else:
			seconds = "%.1f" % seconds

		var timer = "%01d:%s" % [minutes, seconds]
		
		pp.set_text(0, pp.get_metadata(0).filePath.get_file() + " (%s)" % timer)
		#pp.set_tooltip(0, pp.get_metadata(0).filePath + " (%s)" % timer)
			
func update_tree_height(min_height = 0, max_height = -1):
	var items = 0
	var root = tree.get_root()
	var rr = root.get_next_visible()
	
	if !tree.hide_root:
		items += 1
	
	while rr != null:
		items += 1
		rr = rr.get_next_visible()
	
	tree.rect_min_size.y = (max(Global.font_size.y, 16) * items) + 18

func msg(text):
	Debug.msg(text, self, Global.colors.LGRAY)

func _on_VolumeSlider_value_changed(value):
	AudioServer.set_bus_volume_db(bus_index, value)
	bus_volume = value
	
	$LabelPosition/VolumeLabel.text = str(value)
	$LabelPosition.position.y = (-$HBoxContainer/VolumeSlider.rect_size.y * $HBoxContainer/VolumeSlider.ratio) + $HBoxContainer/VolumeSlider.rect_size.y - 5
	
	SaveSystem.prime()

func _on_SoundTree_item_selected():
	#msg("Selected %s" % tree.get_selected().get_text(0))
	pass

func _on_SoundTree_item_rmb_selected(position):
	#msg("Right clicked on %s" % tree.get_selected().get_text(0))
	
	var popup = find_node("SelectedItemPopup")
	popup.clear()
	popup.popup(Rect2(get_global_mouse_position(), Vector2(1,1)))
	popup.add_check_item("Ignore", 0)
	
	if Main.UIDdatabase[tree.get_selected().get_metadata(0).UID].has("ignored"):
		popup.set_item_checked(0, Main.UIDdatabase[tree.get_selected().get_metadata(0).UID].ignored)

func _on_SelectedItemPopup_id_pressed(ID):
	#msg("Selected %s for item %s (%s)" % [popup.get_item_text(ID), tree.get_selected().get_text(0), tree.get_selected().get_metadata(0).UID])
	Main.set_ignore(tree.get_selected().get_metadata(0).UID, Main.IgnoreType.TOGGLE)
	update_status_tree()

func _on_VolumeSlider_gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_RIGHT:
			$HBoxContainer/VolumeSlider.value = 0

func _on_VolumeSlider_mouse_entered():
	$LabelPosition/VolumeLabel.visible = true

func _on_VolumeSlider_mouse_exited():
	$LabelPosition/VolumeLabel.visible = false