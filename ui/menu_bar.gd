@tool
extends MenuBar

signal new_sheet
signal save_sheet

func _on_file_id_pressed(id: int) -> void:
	match id:
		0: # New Event Sheet
			emit_signal("new_sheet")
		1: # Save Event Sheet
			emit_signal("save_sheet")
