extends Panel
class_name PlayerPanel

signal player_removed

@onready var no: Label = $No
@onready var id: int
@onready var player_name: Label = $PlayerName
@onready var ready_label: Label = $HBoxContainer/Ready
@onready var remove_btn: Button = $HBoxContainer/Remove
@onready var player_color: ColorRect = $PlayerName/PlayerColor


func _on_remove_pressed() -> void:
	player_removed.emit()
