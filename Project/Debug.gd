extends RichTextLabel

var test_mode = false
var regex_performance_table = []
var testing_events = []
var testing_strings = []

var event_pos = 0
var string_pos = 0
var looped_amt = 0

var pending_messages = []
var maximum_length = 50000

var party_mode = false

func _ready():
	set_process(true)

func msg(txt, node = self, color : = Global.colors.WHITE):
	pending_messages.append([txt, node, "#%s" % color.to_html()])
	
func push_message(txt, node, color):
	if party_mode:
		var party_text = ""
		for c in txt:
			var keys = Global.colors.keys()
			party_text += "[color=#%s]%s[/color]" % [Global.colors[keys[randi() % keys.size()]].to_html(), c]
		
		txt = party_text
		
	print("%s: %s" % [node.get_path(), txt])
	var new_text = "\n[color=%s]%s[/color]" % [color, txt]
	
	if bbcode_text.find(new_text, bbcode_text.rfind("\n")) == -1:
		bbcode_text += new_text
		looped_amt = 0
	else:
		if looped_amt == 0:
			bbcode_text += " "
		bbcode_text += "[color=#%s]|[/color]" % [Global.colors.LGRAY.to_html()]
		looped_amt += 1
	
	if bbcode_text.length() > maximum_length:
		bbcode_text = bbcode_text.right(bbcode_text.length() - maximum_length)
	
func test_regex_performance(events, strings):
	regex_performance_table = []
	
	testing_events = events.duplicate(true)
	testing_strings = strings.duplicate(true)
	
	event_pos = 0
	string_pos = 0
	
	if testing_events.size() > 0 and testing_strings.size() > 0:
		msg("Testing %s events and %s strings" % [testing_events.size(), testing_strings.size()])
		set_process(true)
	
func _process(delta):
	#msg("%sms" % get_process_delta_time())
	
	if pending_messages.size() > 0:
		var message = pending_messages.pop_back()
		push_message(message[0], message[1], message[2])
	
	if test_mode:
		if event_pos >= testing_events.size():
			string_pos += 1
			event_pos = 0
			msg("%s/%s events tested, %s/%s strings tested" % [event_pos, testing_events.size(), string_pos, testing_strings.size()])
			
		if string_pos >= testing_strings.size():
			set_process(false)
			
			msg("Finished testing, sorting results")
			regex_performance_table.sort_custom(self, "sort_results")
			
			var limit = 50
			for ll in limit:
				msg(regex_performance_table[ll])
			
		else:
			var regexresult = testing_events[event_pos].pattern.search(testing_strings[string_pos])
			
			var result = {}
			
			if regexresult != null:
				result.regexresult = true
			else:
				result.regexresult = false
				
			result.regex = testing_events[event_pos].pattern.get_pattern()
			result.string = testing_strings[string_pos]
			result.ms = 0
			
			if regex_performance_table.size() > 0:
				regex_performance_table.back().ms = get_process_delta_time()
			
			regex_performance_table.append(result)
			
			event_pos += 1
		
func sort_results(aa, bb):
	if aa.ms > bb.ms:
		return true
	else:
		return false