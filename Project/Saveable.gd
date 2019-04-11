extends Node

var SAVE_KEY = null
var saved_vars = []
var my_node = null

func initialize(key : String, vars : Array, node : Node):
	node.add_to_group("Saveable")
	
	SAVE_KEY = key
	saved_vars = vars
	my_node = node
	
	load_data()
	
	SaveSystem.prime()
	
func save_data():
	var data = {}
	
	for vv in saved_vars:
		data[vv] = my_node.get(vv)
		
	return data
	
func load_data():
	if SaveSystem.saved_data.has(SAVE_KEY):
		for vv in saved_vars:
			if SaveSystem.saved_data[SAVE_KEY].has(vv):
				print("Set %s from %s to %s for node %s!" % [vv, my_node.get(vv), SaveSystem.saved_data[SAVE_KEY][vv], my_node.name])
				my_node.set(vv, SaveSystem.saved_data[SAVE_KEY][vv])