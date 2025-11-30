extends FKEvent

func get_description() -> String:
	return "This event occurs when an action from the InputMap is pressed."

func get_id() -> String:
	return "on_action_pressed"

func get_name() -> String:
	return "On Action Pressed"

func get_supported_types() -> Array[String]:
	return ["Node", "System"]

func get_inputs() -> Array:
	return [
		{
			"name": "action_name",
			"type": "String",
			"default": "",
			"hint": "The name of the action from InputMap (e.g., 'ui_accept', 'jump')"
		}
	]

func poll(node: Node, inputs: Dictionary = {}) -> bool:
	if not node or not node.is_inside_tree():
		return false
	
	var action_name = inputs.get("action_name", "")
	
	if action_name.is_empty():
		return false
	
	if not InputMap.has_action(action_name):
		push_warning("Action '%s' not found in InputMap" % action_name)
		return false
	
	return Input.is_action_just_pressed(action_name)
