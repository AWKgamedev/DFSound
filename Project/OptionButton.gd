extends OptionButton

func _ready():
	var thresholds =  get_tree().get_root().get_node("Base/Logger").Threshold
	for kk in thresholds.keys():
		add_item(kk, thresholds[kk])
		
	select(get_tree().get_root().get_node("Base/Logger").active_threshold)

func _on_OptionButton_item_selected(ID):
	get_tree().get_root().get_node("Base/Logger").active_threshold = ID