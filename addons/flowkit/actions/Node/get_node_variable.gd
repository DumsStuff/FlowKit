extends FKAction

## Get Node Variable Action
## Retrieves a node variable and stores it in a scene variable

func get_id() -> String:
	return "get_node_variable"

func get_name() -> String:
	return "Get Node Variable"

func get_inputs() -> Array[Dictionary]:
	return [
		{"name": "variable_name", "type": "String"},
		{"name": "store_in", "type": "String"}  # Scene variable name to store result
	]

func get_supported_types() -> Array[String]:
	return ["Node"]

func execute(node: Node, inputs: Dictionary) -> void:
	var variable_name: String = str(inputs.get("variable_name", ""))
	var store_in: String = str(inputs.get("store_in", ""))
	
	if variable_name.is_empty() or store_in.is_empty():
		return
	
	# Get the node variable
	var value: Variant = FlowKitSystem.get_node_var(node, variable_name)
	
	# Store it in a scene variable
	FlowKitSystem.set_var(store_in, value)
