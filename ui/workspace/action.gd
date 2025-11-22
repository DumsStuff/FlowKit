@tool
extends MarginContainer

signal insert_action_requested(action_node)
signal replace_action_requested(action_node)
signal delete_action_requested(action_node)
signal edit_action_requested(action_node)

var action_data: FKEventAction
var event_index: int = -1
var action_index: int = -1

var context_menu: PopupMenu
var label: Label

func _ready() -> void:
	label = get_node_or_null("Panel/MarginContainer/HBoxContainer/Label")
	
	# Connect gui_input for right-click detection
	gui_input.connect(_on_gui_input)
	
	# Try to get context menu and connect if available
	call_deferred("_setup_context_menu")

func _setup_context_menu() -> void:
	context_menu = get_node_or_null("ContextMenu")
	if context_menu:
		context_menu.id_pressed.connect(_on_context_menu_id_pressed)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# Try to get context menu if we don't have it yet
			if not context_menu:
				context_menu = get_node_or_null("ContextMenu")
				if context_menu and not context_menu.id_pressed.is_connected(_on_context_menu_id_pressed):
					context_menu.id_pressed.connect(_on_context_menu_id_pressed)
			
			if context_menu:
				context_menu.position = get_global_mouse_position()
				context_menu.popup()

func _on_context_menu_id_pressed(id: int) -> void:
	match id:
		0: # Add Action Below
			insert_action_requested.emit(self)
		1: # Replace Action
			replace_action_requested.emit(self)
		2: # Edit Action
			edit_action_requested.emit(self)
		3: # Delete Action
			delete_action_requested.emit(self)

func set_action_data(data: FKEventAction, evt_index: int, act_index: int) -> void:
	action_data = data
	event_index = evt_index
	action_index = act_index
	_update_label()

func _update_label() -> void:
	if label and action_data:
		var params_text = ""
		if not action_data.inputs.is_empty():
			var param_pairs = []
			for key in action_data.inputs:
				param_pairs.append("%s: %s" % [key, action_data.inputs[key]])
			params_text = " [" + ", ".join(param_pairs) + "]"
		label.text = "Action: %s%s" % [action_data.action_id, params_text]

func _get_drag_data(at_position: Vector2):
	var preview := duplicate()
	preview.modulate.a = 0.5
	set_drag_preview(preview)
	return self
