extends Node

var Save = load("res://Saveable.gd").new()
onready var Debug = get_tree().get_root().find_node("Debug", true, false)
var rng = RandomNumberGenerator.new()

var dir = Directory.new()
var latest_length = 0
var unprocessed_strings = []

var max_pack_folder_depth = 3

var strings_per_frame = 7

var update_rate = 0.1
var update_timer = 0.0
var same_event_concurrency = false

var first_process = true
var gamelog_found = true

var compiled_events = []
var UIDdatabase = {}
var supported_filetypes = ["ogg", "wav"]

enum Threshold {NOTHING, CRITICAL, IMPORTANT, FLUFFY, EVERYTHING}
enum ItemType {BUS, FILE, EVENT, SOUNDFILE}
enum IgnoreType {TRUE, FALSE, TOGGLE}

var active_threshold = Threshold.EVERYTHING setget set_threshold
var ignored_items = []

var event_template = {	"xmlPath": "",
						"pattern": "",
					  	"soundfiles": [],
					  	"bus": "SFX",
						"loop": "",
						"concurrency": -1,
						"timeout": 0.0,
					  	"delay": 0.0,
					  	"haltOnMatch": true,
						"probability": 1.0,
						"playbackThreshold": Threshold.EVERYTHING,
						"speech": false,
						"lastPlayed": -999.0,
						"UID": 0
						}

var soundfile_template = {"xmlPath": "",
						  "filePath": "", 
						  "weight": 1.0, 
						  "volumeAdjustment": 0.0, 
						  "randomBalance": 0.0, 
						  "balanceAdjustment": 0.0
						 }

var parse_new = true
var parse_legacy = true
var soundnode = load("res://SoundEvent.tscn")

func _ready():
	Save.initialize("Logging", ["update_rate", "max_pack_folder_depth", "strings_per_frame", "active_threshold", "ignored_items"], self)
	rng.randomize()
	
	initialize("", true)
	
	Global.connect("game_path_changed", self, "game_path_changed")
	Global.connect("packs_paths_changed", self, "initialize")
	
	for ii in ignored_items:
		set_ignore(ii, IgnoreType.TRUE)
	
func initialize(path, valid):
	$"../LoadingScreen".visible = true
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	compile_events()
	generate_buses()
	refresh_log()
	$"../LoadingScreen".visible = false
	
func game_path_changed(path, valid):
	first_process = true
	gamelog_found = true
	latest_length = 0
	
func _process(delta):
	update_timer += delta
	
	if unprocessed_strings.size() > 0:
		process_string(strings_per_frame)
	
	if update_timer >= update_rate:
		update_timer = 0
		refresh_log()
		#if !Debug.is_processing():
		#	Debug.test_regex_performance(compiled_events, unprocessed_strings)
		#	unprocessed_strings.clear()
	
func compile_events():
	UIDdatabase.clear()
	compiled_events.clear()
	var compdir = Directory.new()
	
	var pendingfiles = []
	var pendingdirs = [] + Global.packs_paths
	var base_depth = Global.packs_paths[0].split("/").size() - 2
	#Get all XMLs
	while !pendingdirs.empty():
		var path = pendingdirs.pop_back()
		#msg(path)
		
		if compdir.dir_exists(path):
			compdir.open(path)
			compdir.list_dir_begin(true, true)
			var instance = compdir.get_next()
			while instance != "":
				instance = compdir.get_current_dir() + "/" + instance
				#print(instance)
				if compdir.current_is_dir():
					if instance.split("/").size() - base_depth <= max_pack_folder_depth:
						pendingdirs.append(instance)
					else:
						#msg("%s is too deep! %s/%s" % [instance, instance.split("/").size() - base_depth, max_pack_folder_depth], Global.colors.DGRAY)
						pass
				else:
					if instance.get_extension() == "xml":
						#msg("%s is an XML!" % instance)
						pendingfiles.append(instance)
					
				instance = compdir.get_next()
		else:
			pass
			#msg("Folder %s doesn't exist!" % path)
	
	#msg(pendingfiles)
	
	var parser = XMLParser.new()
	for ff in pendingfiles:
		parser.open(ff)
		var error = parser.read()
		var known_legacy = false
		var is_legacy = false
		var within_event = false
		
		while error == 0:
			if !known_legacy:
				if parser.get_node_type() == XMLParser.NODE_ELEMENT and parser.get_node_name() == "sounds":
					known_legacy = true
					is_legacy = true
					if !parse_legacy:
						break
				
				if parser.get_node_type() == XMLParser.NODE_ELEMENT and parser.get_node_name() == "events":
					known_legacy = true
					is_legacy = false
					if !parse_new:
						break
			
			match is_legacy:
				true:
					if parser.get_node_type() == XMLParser.NODE_ELEMENT_END:
						match parser.get_node_name():
							"sound":
								within_event = false
					elif parser.get_node_type() == XMLParser.NODE_ELEMENT:
						match parser.get_node_name():
							"sound":
								var event = event_template.duplicate(true)
								for aa in parser.get_attribute_count():
									var attribute_name = parser.get_attribute_name(aa)
									var attribute_val = parser.get_attribute_value(aa)
									match attribute_name:
										"logPattern":
											var regex = RegEx.new()
											regex.compile(attribute_val)
											
											event.pattern = regex
											event.xmlPath = ff
											#msg("Appending pattern %s" % attribute_val)
											compiled_events.append(event)
										"channel":
											event.bus = attribute_val
											if AudioServer.get_bus_index(attribute_val) == -1:
												var pos = AudioServer.get_bus_count()
												AudioServer.add_bus(pos)
												AudioServer.set_bus_name(pos, attribute_val)
												
												msg("Created bus %s" % AudioServer.get_bus_name(pos))
										"loop":
											event.loop = attribute_val
										"concurency":
											event.concurrency = int(attribute_val)
										"timeout":
											event.timeout = float(attribute_val) / 1000
										"delay":
											event.delay = float(attribute_val) / 1000
										"haltOnMatch":
											if attribute_val == "false":
												event.haltOnMatch = false
											elif attribute_val == "true":
												event.haltOnMatch = true
										"speech":
											if attribute_val == "false":
												event.speech = false
											elif attribute_val == "true":
												event.speech = true
										"playbackThreshhold":
											event.playbackThreshold = int(attribute_val)
										"propability":
											event.probability = float(attribute_val) / 100
									
								within_event = true
							"soundFile":
								if within_event:
									var soundfile = soundfile_template.duplicate(true)
									
									for aa in parser.get_attribute_count():
										var attribute_name = parser.get_attribute_name(aa)
										var attribute_val = parser.get_attribute_value(aa)
										
										match attribute_name:
											"fileName":
												if attribute_val != "" and supported_filetypes.has(attribute_val.get_extension()):
													var abs_path = ""
													
													if attribute_val.begins_with("../"):
														abs_path = ff.get_base_dir().get_base_dir() + attribute_val.right(2)
													elif attribute_val.begins_with("/"):
														abs_path = ff.get_base_dir() + attribute_val
													else:
														abs_path = ff.get_base_dir() + "/" + attribute_val
													
													var audiofinder = File.new()
													if audiofinder.file_exists(abs_path):
														soundfile.filePath = abs_path
														soundfile.fileExtension = abs_path.get_extension()
														#msg("%s: Loaded %s, triggered at %s" % [ff, abs_path, compiled_events.back().pattern.get_pattern()])
													else:
														msg("%s: Didn't find %s " % [ff, abs_path], Global.colors.LRED)
												else:
													msg("Unsupported filetype: %s! (%s)" % [attribute_val, ff.get_file()], Global.colors.LRED)
													pass
											"weight":
													if attribute_val != "":
														soundfile.weight = float(attribute_val) / 100
											"volumeAdjustment":
													if attribute_val != "":
														soundfile.volumeAdjustment = float(attribute_val)
											"randomBalance":
													if attribute_val != "":
														soundfile.randomBalance = float(bool(attribute_val))
											"balanceAdjustment":
													if attribute_val != "":
														soundfile.balanceAdjustment = float(attribute_val)
										
									#Append this sound to event
									if soundfile.filePath != "":
										soundfile.xmlPath = ff
										#msg("Adding %s to event %s" % [soundfile.filePath, compiled_events.back().pattern.get_pattern()])
										compiled_events.back().soundfiles.append(soundfile)
								
								else:
									msg("Sound files are not within sound event, parsing is incorrect!", Global.colors.LRED)
			error = parser.read()
			
	#Generate UIDs for compiled events and soundfiles
	for ee in compiled_events:
		ee.UID = str(ee).md5_text()
		UIDdatabase[ee.UID] = {}
		UIDdatabase[ee.UID].item = ee
		UIDdatabase[ee.UID].itemType = ItemType.EVENT
		
		for ss in ee.soundfiles:
			ss.UID = str(ss).md5_text()
			UIDdatabase[ss.UID] = {}
			UIDdatabase[ss.UID].item = ss
			UIDdatabase[ss.UID].itemType = ItemType.SOUNDFILE
			
	msg("Compiled %s events" % compiled_events.size())
		
func generate_buses(vert = false):
	var vertcontainer = get_tree().get_root().find_node("VertBusContainer", true, false)
	var horicontainer = get_tree().get_root().find_node("HoriBusContainer", true, false)
	
	if horicontainer != null:
		for cc in horicontainer.get_children():
			cc.queue_free()
	
	if vertcontainer != null:
		for cc in vertcontainer.get_children():
			cc.queue_free()
		
	var bus_num = AudioServer.get_bus_count()
	
	if vert:
		for bb in bus_num:
			var busres = load("res://BusVertical.tscn")
			var bus = busres.instance()
			
			vertcontainer.add_child(bus)
			bus.set_bus(AudioServer.get_bus_name(bb))
	else:
		for bb in bus_num:
			var busres = load("res://BusHorizontal.tscn")
			var bus = busres.instance()
			
			horicontainer.add_child(bus)
			bus.set_bus(AudioServer.get_bus_name(bb))
			
func check_folder(folder):
	return dir.dir_exists(folder)
	
func check_file(file):
	return dir.file_exists(file)
		
func refresh_log():
	var gamelog_path = Global.game_path + "gamelog.txt"
	var exists = check_file(gamelog_path)
	if exists:
		gamelog_found = true
		var file = File.new()
		
		file.open(gamelog_path, File.READ)
		var new_length = file.get_len()
		
		if new_length != latest_length:
			if first_process:
				latest_length = new_length
				first_process = false
				return true
			else:
				file.seek(latest_length)
				var new_log = file.get_buffer(new_length - latest_length)
				file.close()
				latest_length = new_length
				
				new_log = new_log.get_string_from_utf8()
				#Split mode
				for ss in new_log.split("\n"):
					unprocessed_strings.append(ss)
	
				#Batched mode
				#unprocessed_strings.append(new_log)
	
	else:
		if gamelog_found:
			msg("Can't open gamelog!")
		gamelog_found = false
	
	return exists
		
func process_string(amt):
	var search_amt = 0
	var line_amt = 0
	var already_played_events = []
	
	if first_process:
		amt = unprocessed_strings.size()
	
	for aa in amt:
		if !unprocessed_strings.empty():
			var string = unprocessed_strings.pop_back()
			line_amt += 1
			
			for event in compiled_events:
				if !first_process:
					if !already_played_events.has(event) or same_event_concurrency == true:
						#msg("Looking at event %s" % event)
						var result = event.pattern.search(string)
						search_amt += 1
						if result != null:
							if event.probability > rng.randf():
								if event.concurrency == -1 or event.concurrency >= get_tree().get_nodes_in_group("SoundEvents").size():
									if event.timeout < float(OS.get_ticks_msec() - event.lastPlayed) / 1000: 
										msg("The event %s was triggered by the string \"%s\"" % [event.pattern.get_pattern(), string])
										#msg("Event not in timeout! Timeout: %s, Last Played: %s" % [event.timeout, float(OS.get_ticks_msec() - event.lastPlayed) / 1000])
										event.lastPlayed = OS.get_ticks_msec()
										
										var new_node = soundnode.instance()
										add_child(new_node)
										new_node.process_event(event, soundfile_template.duplicate(true))						
										already_played_events.append(event.UID)
										
										if event.haltOnMatch:
											break
									else:
										msg("Event is still in timeout! Timeout: %s, Last Played: %s seconds ago" % [event.timeout, float(OS.get_ticks_msec() - event.lastPlayed) / 1000])
										pass
								else:
									msg("Sound's concurrency is %s, there are %s sounds playing!" % [event.concurrency, get_tree().get_nodes_in_group("SoundEvents").size()])
									pass
							else:
								#msg("Probability %s, didn't play!" % event.probability)
								pass
					else:
						#msg("Already played this one in this frame!")
						pass
					
	#if unprocessed_strings.size() > 0:
	#	msg("Lines processed: %s, RegEx searches: %s" % [line_amt, search_amt])
	#	#msg(unprocessed_strings.size())
	
	if unprocessed_strings.size() <= 0:
		first_process = false

		
func insert_string(string):
	unprocessed_strings.append(string)
	
func set_threshold(val):
	msg("Setting threshold to %s" % val)
	if active_threshold != val:
		active_threshold = val
		
		for nn in get_tree().get_nodes_in_group("SoundEvents"):
			if nn.my_event.playbackThreshold > active_threshold:
				msg("Muting %s, threshold %s" % [nn.my_event.pattern.get_pattern(), nn.my_event.playbackThreshold])
				nn.mute(nn.MuteType.THRESHOLD)
			else:
				nn.unmute(nn.MuteType.THRESHOLD)
				
	SaveSystem.prime()
				
func set_ignore(UID, type = IgnoreType):
	var item = UIDdatabase[UID]
	var ignore = null
	
	match item.itemType:
		ItemType.EVENT:
			pass
		ItemType.SOUNDFILE:
			match type:
				IgnoreType.TRUE:
					ignore = true
				IgnoreType.FALSE:
					ignore = false
				IgnoreType.TOGGLE:
					if item.has("ignored"):
						ignore = !item.ignored
					else:
						ignore = true
			
			item.ignored = ignore
		
	for nn in get_tree().get_nodes_in_group("SoundEvents"):
		if nn.picked_sound_UID == UID:
			msg("Muting %s" % UID)
			if ignore:
				nn.mute(nn.MuteType.IGNORE)
			else:
				nn.unmute(nn.MuteType.IGNORE)
				
	if ignore:
		if !ignored_items.has(UID):
			ignored_items.append(UID)
	else:
		ignored_items.erase(UID)
		
	SaveSystem.prime()
			
	msg("Setting ignore to %s" % item.ignored)
		
func msg(text, color := Global.colors.WHITE):
	Debug.msg(text, self, color)