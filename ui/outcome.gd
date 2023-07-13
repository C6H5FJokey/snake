extends Control

@onready var label: Label = $Label

var text: String : 
	set(v):
		label.text = v

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")


func _on_reset_pressed() -> void:
	get_tree().reload_current_scene()
