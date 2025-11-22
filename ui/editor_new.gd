@tool
extends Control

var scene_name: String
var editor_interface: EditorInterface
var is_loading: bool = false  # Flag to prevent reload during operations

# Preload scene files for instantiation
var event_scene = preload("res://addons/flowkit/ui/workspace/event.tscn")
var condition_scene = preload("res://addons/flowkit/ui/workspace/condition.tscn")
var action_scene = preload("res://addons/flowkit/ui/workspace/action.tscn")

@onready var menubar := $OuterVBox/TopMargin/MenuBar
@onready var content_container := $OuterVBox/ScrollContainer/MarginContainer/VBoxContainer
@onready var no_action_available := $"OuterVBox/ScrollContainer/MarginContainer/VBoxContainer/No Action Available"
@onready var add_event_button := $OuterVBox/BottomMargin/ButtonContainer/AddEventButton
@onready var add_condition_button := $OuterVBox/BottomMargin/ButtonContainer/AddConditionButton
@onready var add_action_button := $OuterVBox/BottomMargin/ButtonContainer/AddActionButton
@onready var select_modal := $SelectModal
@onready var select_event_modal := $SelectEventModal
@onready var select_action_node_modal := $SelectActionNodeModal
@onready var select_action_modal := $SelectActionModal
@onready var select_condition_node_modal := $SelectConditionNodeModal
@onready var select_condition_modal := $SelectConditionModal
@onready var expression_editor_modal := $ExpressionEditorModal
@onready var condition_expression_editor_modal := $ConditionExpressionEditorModal
@onready var event_expression_editor_modal := $EventExpressionEditorModal

func _ready() -> void:
	# Connect visibility changes
	visibility_changed.connect(_on_visibility_changed)
	
	# Show empty state by default
	_show_empty_state()

func _on_visibility_changed() -> void:
	"""Called when the panel is shown or hidden."""
	if visible and editor_interface:
		var current_scene = editor_interface.get_edited_scene_root()
		if current_scene:
			var scene_path = current_scene.scene_file_path
			var new_name = scene_path.get_file().get_basename()
			# Only load if switching to a different scene
			if new_name != scene_name and new_name != "":
				scene_name = new_name
				_load_event_sheet()

func _process(_delta: float) -> void:
	if editor_interface:
		_check_scene_change()

func _check_scene_change():
	"""Check if the scene has changed and load appropriate event sheet."""
	if is_loading:
		return
		
	var current_scene = editor_interface.get_edited_scene_root()
	var new_name = ""
	
	if current_scene:
		var scene_path = current_scene.scene_file_path
		if scene_path != "":
			new_name = scene_path.get_file().get_basename()
	
	# Only reload if we're switching to a DIFFERENT scene
	if new_name != scene_name and new_name != "":
		scene_name = new_name
		_load_event_sheet()

func set_editor_interface(interface: EditorInterface):
	editor_interface = interface
	# Initial scene name setup
	var current_scene = editor_interface.get_edited_scene_root()
	if current_scene:
		var scene_path = current_scene.scene_file_path
		if scene_path != "":
			scene_name = scene_path.get_file().get_basename()
			_load_event_sheet()

func _on_new_sheet():
	"""Create a new empty event sheet."""
	if scene_name.is_empty():
		push_warning("Cannot create event sheet: Scene has not been saved yet.")
		return
	
	print("Creating new FlowKit event sheet...")
	_clear_content()
	_show_content_state()

func _on_save_sheet():
	"""Generate and save event sheet from current node structure."""
	if scene_name.is_empty():
		push_warning("Cannot save event sheet: Scene has not been saved yet.")
		return
	
	var sheet = _generate_event_sheet()
	
	# Ensure directory exists
	var dir_path = "res://addons/flowkit/saved/event_sheet"
	DirAccess.make_dir_recursive_absolute(dir_path)
	
	# Save to resource file
	var file_path = "%s/%s.tres" % [dir_path, scene_name]
	var error = ResourceSaver.save(sheet, file_path)
	
	if error == OK:
		print("Event sheet saved successfully to: ", file_path)
	else:
		push_error("Failed to save event sheet. Error code: ", error)

func _generate_event_sheet() -> FKEventSheet:
	"""Generate FKEventSheet by looping through physical node order."""
	var sheet = FKEventSheet.new()
	var events: Array[FKEventBlock] = []
	var standalone_conditions: Array[FKEventCondition] = []
	
	var current_event: FKEventBlock = null
	var current_standalone_condition: FKEventCondition = null
	
	# Loop through all children in physical order
	for child in content_container.get_children():
		if child == no_action_available:
			continue
		
		if child.has_method("get_event_data"):
			# It's an event node
			if current_event:
				events.append(current_event)
			if current_standalone_condition:
				standalone_conditions.append(current_standalone_condition)
				current_standalone_condition = null
			
			# Create a fresh copy of the event data
			var event_data = child.get_event_data()
			current_event = FKEventBlock.new()
			current_event.event_id = event_data.event_id
			current_event.target_node = event_data.target_node
			current_event.inputs = event_data.inputs.duplicate()
			current_event.conditions = []
			current_event.actions = []
			
		elif child.has_method("get_condition_data"):
			# It's a condition node
			var condition_data = child.get_condition_data()
			
			# Create a fresh copy of the condition data
			var new_condition = FKEventCondition.new()
			new_condition.condition_id = condition_data.condition_id
			new_condition.target_node = condition_data.target_node
			new_condition.inputs = condition_data.inputs.duplicate()
			new_condition.negated = condition_data.negated
			new_condition.actions = []
			
			if current_event:
				# Add to current event's conditions
				current_event.conditions.append(new_condition)
			else:
				# It's a standalone condition
				if current_standalone_condition:
					standalone_conditions.append(current_standalone_condition)
				current_standalone_condition = new_condition
		
		elif child.has_method("get_action_data"):
			# It's an action node
			var action_data = child.get_action_data()
			
			# Create a fresh copy of the action data
			var new_action = FKEventAction.new()
			new_action.action_id = action_data.action_id
			new_action.target_node = action_data.target_node
			new_action.inputs = action_data.inputs.duplicate()
			
			if current_standalone_condition:
				# Add to standalone condition's actions
				current_standalone_condition.actions.append(new_action)
			elif current_event:
				# Add to current event's actions
				current_event.actions.append(new_action)
	
	# Add the last event or standalone condition
	if current_event:
		events.append(current_event)
	if current_standalone_condition:
		standalone_conditions.append(current_standalone_condition)
	
	sheet.events = events
	sheet.standalone_conditions = standalone_conditions
	
	return sheet

func _load_event_sheet() -> void:
	"""Load existing event sheet and populate UI."""
	if scene_name.is_empty():
		_show_empty_state()
		return
	
	if is_loading:
		return
	
	is_loading = true
	
	# Clear content first to prevent duplication
	_clear_content()
	
	var file_path = "res://addons/flowkit/saved/event_sheet/%s.tres" % scene_name
	if FileAccess.file_exists(file_path):
		var sheet = ResourceLoader.load(file_path)
		if sheet is FKEventSheet:
			_populate_from_sheet(sheet)
		else:
			_show_empty_state()
	else:
		_show_empty_state()
	
	is_loading = false

func _populate_from_sheet(sheet: FKEventSheet) -> void:
	"""Populate UI from event sheet."""
	_clear_content()
	_show_content_state()
	
	var insert_index = 0
	
	# Add standalone conditions first
	for condition in sheet.standalone_conditions:
		var condition_node = condition_scene.instantiate()
		content_container.add_child(condition_node)
		content_container.move_child(condition_node, insert_index)
		
		# Create a copy to avoid read-only issues
		var condition_copy = FKEventCondition.new()
		condition_copy.condition_id = condition.condition_id
		condition_copy.target_node = condition.target_node
		condition_copy.inputs = condition.inputs.duplicate()
		condition_copy.negated = condition.negated
		var empty_actions: Array[FKEventAction] = []
		condition_copy.actions = empty_actions
		
		condition_node.set_condition_data(condition_copy)
		_connect_condition_signals(condition_node)
		insert_index += 1
		
		# Add actions for this standalone condition
		for action in condition.actions:
			var action_node = action_scene.instantiate()
			content_container.add_child(action_node)
			content_container.move_child(action_node, insert_index)
			
			# Create a copy to avoid read-only issues
			var action_copy = FKEventAction.new()
			action_copy.action_id = action.action_id
			action_copy.target_node = action.target_node
			action_copy.inputs = action.inputs.duplicate()
			
			action_node.set_action_data(action_copy)
			_connect_action_signals(action_node)
			insert_index += 1
	
	# Add events
	for event in sheet.events:
		var event_node = event_scene.instantiate()
		content_container.add_child(event_node)
		content_container.move_child(event_node, insert_index)
		
		# Create a copy to avoid read-only issues
		var event_copy = FKEventBlock.new()
		event_copy.event_id = event.event_id
		event_copy.target_node = event.target_node
		event_copy.inputs = event.inputs.duplicate()
		var empty_conditions: Array[FKEventCondition] = []
		var empty_actions: Array[FKEventAction] = []
		event_copy.conditions = empty_conditions
		event_copy.actions = empty_actions
		
		event_node.set_event_data(event_copy)
		_connect_event_signals(event_node)
		insert_index += 1
		
		# Add conditions for this event
		for condition in event.conditions:
			var condition_node = condition_scene.instantiate()
			content_container.add_child(condition_node)
			content_container.move_child(condition_node, insert_index)
			
			# Create a copy to avoid read-only issues
			var condition_copy = FKEventCondition.new()
			condition_copy.condition_id = condition.condition_id
			condition_copy.target_node = condition.target_node
			condition_copy.inputs = condition.inputs.duplicate()
			condition_copy.negated = condition.negated
			var cond_empty_actions: Array[FKEventAction] = []
			condition_copy.actions = cond_empty_actions
			
			condition_node.set_condition_data(condition_copy)
			_connect_condition_signals(condition_node)
			insert_index += 1
		
		# Add actions for this event
		for action in event.actions:
			var action_node = action_scene.instantiate()
			content_container.add_child(action_node)
			content_container.move_child(action_node, insert_index)
			
			# Create a copy to avoid read-only issues
			var action_copy = FKEventAction.new()
			action_copy.action_id = action.action_id
			action_copy.target_node = action.target_node
			action_copy.inputs = action.inputs.duplicate()
			
			action_node.set_action_data(action_copy)
			_connect_action_signals(action_node)
			insert_index += 1

func _clear_content() -> void:
	"""Clear all dynamically created nodes."""
	if not content_container:
		return
	
	var no_action_index = no_action_available.get_index()
	
	# Collect nodes to remove
	var nodes_to_remove = []
	for i in range(no_action_index):
		nodes_to_remove.append(content_container.get_child(i))
	
	# Remove and free them immediately
	for node in nodes_to_remove:
		content_container.remove_child(node)
		node.queue_free()

func _show_empty_state() -> void:
	"""Show empty state message."""
	_clear_content()
	if no_action_available:
		no_action_available.visible = true
	if add_event_button:
		add_event_button.visible = false
	if add_condition_button:
		add_condition_button.visible = false
	if add_action_button:
		add_action_button.visible = false

func _show_content_state() -> void:
	"""Show content state with buttons."""
	if no_action_available:
		no_action_available.visible = false
	if add_event_button:
		add_event_button.visible = true
	if add_condition_button:
		add_condition_button.visible = true
	if add_action_button:
		add_action_button.visible = true

# === Add Button Handlers ===

func _on_add_event_button_pressed() -> void:
	"""Add a new event to the end."""
	if not editor_interface:
		return
	
	var current_scene = editor_interface.get_edited_scene_root()
	if not current_scene:
		return
	
	select_modal.set_editor_interface(editor_interface)
	select_modal.populate_from_scene(current_scene)
	select_modal.popup_centered()

func _on_select_modal_node_selected(node_path: String, node_class: String) -> void:
	"""Node selected for event."""
	select_modal.hide()
	select_event_modal.populate_events(node_path, node_class)
	select_event_modal.popup_centered()

func _on_select_modal_event_selected(node_path: String, event_id: String, event_inputs: Array) -> void:
	"""Event type selected."""
	select_event_modal.hide()
	
	if event_inputs.size() > 0:
		event_expression_editor_modal.populate_inputs(node_path, event_id, event_inputs)
		event_expression_editor_modal.set_meta("node_path", node_path)
		event_expression_editor_modal.set_meta("event_id", event_id)
		event_expression_editor_modal.popup_centered()
	else:
		_create_event_node(node_path, event_id, {})

func _on_event_expression_editor_confirmed(node_path: String, event_id: String, expressions: Dictionary) -> void:
	"""Event expressions confirmed."""
	_create_event_node(node_path, event_id, expressions)

func _create_event_node(node_path: String, event_id: String, inputs: Dictionary) -> void:
	"""Create and add a new event node."""
	var event_data = FKEventBlock.new()
	event_data.event_id = event_id
	event_data.target_node = node_path
	event_data.inputs = inputs
	
	var event_node = event_scene.instantiate()
	content_container.add_child(event_node)
	event_node.set_event_data(event_data)
	_connect_event_signals(event_node)

func _on_add_condition_button_pressed() -> void:
	"""Add a new standalone condition to the end."""
	if not editor_interface:
		return
	
	var current_scene = editor_interface.get_edited_scene_root()
	if not current_scene:
		return
	
	select_condition_node_modal.set_editor_interface(editor_interface)
	select_condition_node_modal.populate_from_scene(current_scene)
	select_condition_node_modal.popup_centered()

func _on_select_condition_node_selected(node_path: String, node_class: String) -> void:
	"""Node selected for condition."""
	select_condition_node_modal.hide()
	select_condition_modal.populate_conditions(node_path, node_class)
	select_condition_modal.popup_centered()

func _on_select_condition_modal_condition_selected(node_path: String, condition_id: String, condition_inputs: Array) -> void:
	"""Condition type selected."""
	select_condition_modal.hide()
	
	if condition_inputs.size() > 0:
		condition_expression_editor_modal.populate_inputs(node_path, condition_id, condition_inputs)
		condition_expression_editor_modal.set_meta("node_path", node_path)
		condition_expression_editor_modal.set_meta("condition_id", condition_id)
		condition_expression_editor_modal.popup_centered()
	else:
		_create_condition_node(node_path, condition_id, {})

func _on_condition_expression_editor_confirmed(node_path: String, condition_id: String, expressions: Dictionary) -> void:
	"""Condition expressions confirmed."""
	_create_condition_node(node_path, condition_id, expressions)

func _create_condition_node(node_path: String, condition_id: String, inputs: Dictionary) -> void:
	"""Create and add a new condition node."""
	var condition_data = FKEventCondition.new()
	condition_data.condition_id = condition_id
	condition_data.target_node = node_path
	condition_data.inputs = inputs
	
	var condition_node = condition_scene.instantiate()
	content_container.add_child(condition_node)
	condition_node.set_condition_data(condition_data)
	_connect_condition_signals(condition_node)

func _on_add_action_button_pressed() -> void:
	"""Add a new action to the end."""
	if not editor_interface:
		return
	
	var current_scene = editor_interface.get_edited_scene_root()
	if not current_scene:
		return
	
	select_action_node_modal.set_editor_interface(editor_interface)
	select_action_node_modal.populate_from_scene(current_scene)
	select_action_node_modal.popup_centered()

func _on_select_action_node_selected(node_path: String, node_class: String) -> void:
	"""Node selected for action."""
	select_action_node_modal.hide()
	select_action_modal.populate_actions(node_path, node_class)
	select_action_modal.popup_centered()

func _on_select_action_modal_action_selected(node_path: String, action_id: String, action_inputs: Array) -> void:
	"""Action type selected."""
	select_action_modal.hide()
	
	if action_inputs.size() > 0:
		expression_editor_modal.populate_inputs(node_path, action_id, action_inputs)
		expression_editor_modal.set_meta("node_path", node_path)
		expression_editor_modal.set_meta("action_id", action_id)
		expression_editor_modal.popup_centered()
	else:
		_create_action_node(node_path, action_id, {})

func _on_expression_editor_confirmed(node_path: String, action_id: String, expressions: Dictionary) -> void:
	"""Action expressions confirmed."""
	_create_action_node(node_path, action_id, expressions)

func _create_action_node(node_path: String, action_id: String, inputs: Dictionary) -> void:
	"""Create and add a new action node."""
	var action_data = FKEventAction.new()
	action_data.action_id = action_id
	action_data.target_node = node_path
	action_data.inputs = inputs
	
	var action_node = action_scene.instantiate()
	content_container.add_child(action_node)
	action_node.set_action_data(action_data)
	_connect_action_signals(action_node)

# === Signal Connections ===

func _connect_event_signals(event_node) -> void:
	"""Connect all event node signals."""
	event_node.insert_condition_requested.connect(_on_event_insert_condition_requested)
	event_node.replace_event_requested.connect(_on_replace_event_requested)
	event_node.delete_event_requested.connect(_on_delete_event_requested)
	event_node.edit_event_requested.connect(_on_edit_event_requested)

func _connect_condition_signals(condition_node) -> void:
	"""Connect all condition node signals."""
	condition_node.insert_condition_requested.connect(_on_condition_insert_condition_requested)
	condition_node.replace_condition_requested.connect(_on_replace_condition_requested)
	condition_node.delete_condition_requested.connect(_on_delete_condition_requested)
	condition_node.negate_condition_requested.connect(_on_negate_condition_requested)
	condition_node.edit_condition_requested.connect(_on_edit_condition_requested)

func _connect_action_signals(action_node) -> void:
	"""Connect all action node signals."""
	action_node.insert_action_requested.connect(_on_insert_action_requested)
	action_node.replace_action_requested.connect(_on_replace_action_requested)
	action_node.delete_action_requested.connect(_on_delete_action_requested)
	action_node.edit_action_requested.connect(_on_edit_action_requested)

# === Event Context Menu Handlers ===

func _on_event_insert_condition_requested(event_node) -> void:
	"""Insert condition below event."""
	if not editor_interface:
		return
	
	var current_scene = editor_interface.get_edited_scene_root()
	if not current_scene:
		return
	
	select_condition_node_modal.set_editor_interface(editor_interface)
	select_condition_node_modal.populate_from_scene(current_scene)
	select_condition_node_modal.set_meta("insert_after", event_node)
	select_condition_node_modal.popup_centered()

func _on_replace_event_requested(event_node) -> void:
	"""Replace an event."""
	if not editor_interface:
		return
	
	var current_scene = editor_interface.get_edited_scene_root()
	if not current_scene:
		return
	
	select_modal.set_editor_interface(editor_interface)
	select_modal.populate_from_scene(current_scene)
	select_modal.set_meta("replace_node", event_node)
	select_modal.popup_centered()

func _on_delete_event_requested(event_node) -> void:
	"""Delete an event."""
	event_node.queue_free()

func _on_edit_event_requested(event_node) -> void:
	"""Edit event parameters."""
	var event_data = event_node.get_event_data()
	
	# Get event provider to check inputs
	var registry = FKRegistry.new()
	registry.load_all()
	
	var event_inputs: Array = []
	for provider in registry.event_providers:
		if provider.get_id() == event_data.event_id:
			event_inputs = provider.get_inputs()
			break
	
	if event_inputs.size() == 0:
		return
	
	event_expression_editor_modal.populate_inputs(String(event_data.target_node), event_data.event_id, event_inputs)
	event_expression_editor_modal.set_meta("edit_node", event_node)
	event_expression_editor_modal.popup_centered()

# === Condition Context Menu Handlers ===

func _on_condition_insert_condition_requested(condition_node) -> void:
	"""Insert condition below another condition."""
	if not editor_interface:
		return
	
	var current_scene = editor_interface.get_edited_scene_root()
	if not current_scene:
		return
	
	select_condition_node_modal.set_editor_interface(editor_interface)
	select_condition_node_modal.populate_from_scene(current_scene)
	select_condition_node_modal.set_meta("insert_after", condition_node)
	select_condition_node_modal.popup_centered()

func _on_replace_condition_requested(condition_node) -> void:
	"""Replace a condition."""
	if not editor_interface:
		return
	
	var current_scene = editor_interface.get_edited_scene_root()
	if not current_scene:
		return
	
	select_condition_node_modal.set_editor_interface(editor_interface)
	select_condition_node_modal.populate_from_scene(current_scene)
	select_condition_node_modal.set_meta("replace_node", condition_node)
	select_condition_node_modal.popup_centered()

func _on_delete_condition_requested(condition_node) -> void:
	"""Delete a condition."""
	condition_node.queue_free()

func _on_negate_condition_requested(condition_node) -> void:
	"""Toggle condition negation."""
	var condition_data = condition_node.get_condition_data()
	condition_data.negated = not condition_data.negated
	condition_node.update_display()

func _on_edit_condition_requested(condition_node) -> void:
	"""Edit condition parameters."""
	var condition_data = condition_node.get_condition_data()
	
	# Get condition provider to check inputs
	var registry = FKRegistry.new()
	registry.load_all()
	
	var condition_inputs: Array = []
	for provider in registry.condition_providers:
		if provider.get_id() == condition_data.condition_id:
			condition_inputs = provider.get_inputs()
			break
	
	if condition_inputs.size() == 0:
		return
	
	condition_expression_editor_modal.populate_inputs(String(condition_data.target_node), condition_data.condition_id, condition_inputs)
	condition_expression_editor_modal.set_meta("edit_node", condition_node)
	condition_expression_editor_modal.popup_centered()

# === Action Context Menu Handlers ===

func _on_insert_action_requested(action_node) -> void:
	"""Insert action below another action."""
	if not editor_interface:
		return
	
	var current_scene = editor_interface.get_edited_scene_root()
	if not current_scene:
		return
	
	select_action_node_modal.set_editor_interface(editor_interface)
	select_action_node_modal.populate_from_scene(current_scene)
	select_action_node_modal.set_meta("insert_after", action_node)
	select_action_node_modal.popup_centered()

func _on_replace_action_requested(action_node) -> void:
	"""Replace an action."""
	if not editor_interface:
		return
	
	var current_scene = editor_interface.get_edited_scene_root()
	if not current_scene:
		return
	
	select_action_node_modal.set_editor_interface(editor_interface)
	select_action_node_modal.populate_from_scene(current_scene)
	select_action_node_modal.set_meta("replace_node", action_node)
	select_action_node_modal.popup_centered()

func _on_delete_action_requested(action_node) -> void:
	"""Delete an action."""
	action_node.queue_free()

func _on_edit_action_requested(action_node) -> void:
	"""Edit action parameters."""
	var action_data = action_node.get_action_data()
	
	# Get action provider to check inputs
	var registry = FKRegistry.new()
	registry.load_all()
	
	var action_inputs: Array = []
	for provider in registry.action_providers:
		if provider.get_id() == action_data.action_id:
			action_inputs = provider.get_inputs()
			break
	
	if action_inputs.size() == 0:
		return
	
	expression_editor_modal.populate_inputs(String(action_data.target_node), action_data.action_id, action_inputs)
	expression_editor_modal.set_meta("edit_node", action_node)
	expression_editor_modal.popup_centered()
