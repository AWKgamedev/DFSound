extends Node

var saved_data = {}
var save_path = "res://Settings.ini"

var save_wait = 1
var save_cooldown = 5
var save_primed = false
var save_timer = 0

func _ready():
	_load_data()
	
func prime():
	save_timer = max(save_timer, save_wait)
	save_primed = true
	set_process(true)
	
func _process(delta):
	save_timer -= delta
	
	if save_timer <= 0:
		if save_primed:
			_gather_data()
			_save_file()
			print("Saved! In cooldown...")
			save_primed = false
			save_timer = save_cooldown
		else:
			print("Cooldown ended.")
			set_process(false)

func _load_data():
	var config = ConfigFile.new()
	
	var err = config.load("res://Settings.ini")
	
	if err == OK:
		var nodes = config.get_sections()
		
		for nn in nodes:
			var variables = config.get_section_keys(nn)
			saved_data[nn] = {}
			
			for vv in variables:
				var value = config.get_value(nn, vv)
				
				saved_data[nn][vv] = value
	
	#print(save_data)
	
func _gather_data():
	var nodes = get_tree().get_nodes_in_group("Saveable")
	
	for nn in nodes:
		var key = nn.Save.SAVE_KEY
		var data = nn.Save.save_data()
		
		saved_data[key] = data
		
	#print(save_data)
	
func _save_file():
	var config = ConfigFile.new()
	for node in saved_data.keys():
		var section = node
		for variable in saved_data[node].keys():
			var key = variable
			var value = saved_data[node][variable]
			
			config.set_value(section, key, value)
			
	config.save(save_path)