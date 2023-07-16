extends Control

signal back_pressed
signal reset_pressed

@onready var label: Label = $Label
@onready var reset_btn: Button = $Buttons/Reset

var text: String : 
	set(v):
		label.text = v

func _on_back_pressed() -> void:
	back_pressed.emit()


func _on_reset_pressed() -> void:
	reset_pressed.emit()
