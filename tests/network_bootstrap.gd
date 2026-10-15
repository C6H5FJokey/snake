extends Node


func _ready() -> void:
	# Survive actual change_scene calls as a sibling of the game's current scene.
	var runner: Node = load("res://tests/network_peer.gd").new()
	get_tree().root.add_child.call_deferred(runner)
