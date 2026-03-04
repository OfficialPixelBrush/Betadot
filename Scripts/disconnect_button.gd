extends Button

@onready var client: Node3D = $"../../../../.."

func _on_pressed() -> void:
	client.WriteDisconnect("disconnect.closed")
	Global.unload_game()
	pass # Replace with function body.
