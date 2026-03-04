extends LineEdit

@onready var client: Node3D = $"../../.."
@onready var player: CharacterBody3D = $"../../../Player"


func _on_text_submitted(new_text: String) -> void:
	client.WriteChatMessage(new_text)
	clear()
	hide()
	player.GrabFocus()
	pass # Replace with function body.
