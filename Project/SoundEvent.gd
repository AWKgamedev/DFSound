extends AudioStreamPlayer2D

onready var root_view = get_tree().get_root()
onready var Debug = get_tree().get_root().find_node("Debug", true, false)
var rng = RandomNumberGenerator.new()

var loop = false
var play_position = 0
var volume_sanity_range = [-40, 6]

var my_event = {}
var picked_sound_UID = 0
var my_sound_template = {}

var muted = false
var muted_types = []
var unmuted_volume_db = 0

enum MuteType {THRESHOLD, IGNORE}

func process_event(event = {}, soundfile_template = {}):
	rng.randomize()
	var Logger = root_view.get_node("Base/Logger")
	
	my_event = event.duplicate(true)
	my_sound_template = soundfile_template.duplicate(true)
	
	if my_event.delay > 0:
		#msg("Delaying for %s seconds" % my_event.delay)
		yield(get_tree().create_timer(1.0), "timeout")
		#msg("Delay ended")
	
	var files = []
	var soundfile = null
	
	for ff in my_event.soundfiles:
		if !Logger.UIDdatabase[ff.UID].has("ignored") or !Logger.UIDdatabase[ff.UID].ignored:
			files.append(ff)
			
	if files.size() > 0:
		var totalweight = 0
		var val = 0
		var file_weightings = []
		
		for ff in files:
			totalweight += ff.weight
			file_weightings.append(totalweight)
		
		var rand_pick = rng.randf_range(0, totalweight)
			
		for ff in file_weightings.size():
			if rand_pick <= file_weightings[ff]:
				val = ff
				break
		
		#msg("Picked sound %s from weight %s/%s" % [val, rand_pick, totalweight])
		soundfile = files[val]
		picked_sound_UID = files[val].UID
	else:
		soundfile = soundfile_template
	
	#File
	#msg("Loading file %s..." % soundfile.filePath)
	if soundfile.filePath != "":
		var file = File.new()
		
		
		var new_stream
		match soundfile.fileExtension:
			"ogg":
				new_stream = AudioStreamOGGVorbis.new()
			"wav":
				new_stream = AudioStreamSample.new()
		
		file.open(soundfile.filePath, File.READ)
		new_stream.data = file.get_buffer(file.get_len())
		file.close()			
		
		stream = new_stream
		
		#msg("Loaded sound %s" % soundfile.filePath)
		add_to_group("SoundEvents")
	#msg("Loaded file %s!" % soundfile.filePath)

	#Position
	var randpos = (root_view.size.x / 2) * rng.randf_range(-soundfile.randomBalance, soundfile.randomBalance)
	position.y = root_view.size.y / 2
	position.x = (root_view.size.x / 2) + randpos + (soundfile.balanceAdjustment * (root_view.size.x / 2))
	
	#Volume
	unmuted_volume_db = clamp(soundfile.volumeAdjustment, volume_sanity_range[0], volume_sanity_range[1])
		
	#Loop
	match my_event.loop:
		"start":
			for nn in get_tree().get_nodes_in_group(my_event.bus):
				if nn.loop and nn != self:
					nn.stop_loop()
			loop = true
		"stop":
			for nn in get_tree().get_nodes_in_group(my_event.bus):
				if nn.loop and nn != self:
					nn.stop_loop()
			loop = false
		_:
			for nn in get_tree().get_nodes_in_group(my_event.bus):
				if nn.loop and nn != self:
					nn.pause_loop(self)
	
	if stream is AudioStreamOGGVorbis:
		stream.loop = false
	elif stream is AudioStreamSample:
		stream.loop_mode = AudioStreamSample.LOOP_DISABLED
	
#	#Loop doesn't send finished info so don't use this
#	if stream is AudioStreamOGGVorbis:
#		stream.loop = loop
#	elif stream is AudioStreamSample:
#		if loop:
#			#Not working for some reason, use finished signal instead
#			stream.loop_begin = 0
#			stream.loop_end = stream.data.size()
#			stream.loop_mode = AudioStreamSample.LOOP_FORWARD
#			pass
#		else:
#			stream.loop_mode = AudioStreamSample.LOOP_DISABLED

	#Bus
	bus = my_event.bus
	$Label.text = bus
	
	#Threshold
	if Logger.active_threshold < my_event.playbackThreshold:
		mute(MuteType.THRESHOLD)
	else:
		volume_db = unmuted_volume_db
	
	if soundfile.filePath == "":
		queue_free()
	else:
		add_to_group(bus)
		get_tree().emit_signal("sound_playing", self)
		play()
	
	#msg("Playing %s (From %s/%s)" % [soundfile.filePath, soundfile.xmlPath, my_event.pattern.get_pattern()])
	
func stop_loop():
	if loop:
		loop = false
		_on_SoundEvent_finished()
		
func pause_loop(node):
	if loop:
		play_position = get_playback_position()
		stop()
		get_tree().emit_signal("sound_pausing", self)
		node.connect("finished", self, "resume_loop", [], CONNECT_ONESHOT)
		
func resume_loop():
	play(play_position)

func _on_SoundEvent_finished():
	if loop:
		msg("Looping event")
		get_tree().emit_signal("sound_stopping", self)
		process_event(my_event, my_sound_template)
	else:
		get_tree().emit_signal("sound_stopping", self)
		queue_free()

func mute(type = MuteType):
	if !muted_types.has(type):
		muted_types.append(type)
		
	if !muted:
		muted = true
		unmuted_volume_db = volume_db
		volume_db = -80
		msg("Muted!")

func unmute(type = MuteType):
	if muted_types.size() > 0:
		muted_types.erase(type)
		
		if muted_types.size() == 0:
			muted = false
			volume_db = unmuted_volume_db
			msg("Unmuted!")
		
func msg(text):
	Debug.msg(text, self, Global.colors.LCYAN)