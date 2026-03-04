extends Button

@onready var username: LineEdit = $"../../username"
@onready var server_address: LineEdit = $"../../server_address"

func _on_pressed() -> void:
	Global.username = username.text
	if (username.text.is_empty()):
		push_error("No username passed!")
	var temp_ip = server_address.text.split(":")
	if (temp_ip.size() < 1):
		push_error("No IP passed!")
	Global.ip = String(temp_ip[0])
	if (temp_ip.size() > 1):
		Global.port = int(temp_ip[1])
	Global.load_game()
	pass # Replace with function body.
