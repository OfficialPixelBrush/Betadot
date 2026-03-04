extends Node

var ip : String = "127.0.0.1"
var port : int = 25565
var username : String = "BetadotPlayer"

func load_game():
	get_tree().change_scene_to_file("res://Scenes/world_root.tscn")
