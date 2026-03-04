extends Button

@onready var line_edit: LineEdit = $"../../LineEdit"

func _on_pressed() -> void:
	print(line_edit.text)
	pass # Replace with function body.
