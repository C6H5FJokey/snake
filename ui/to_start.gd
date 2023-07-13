extends Control

signal to_started

@onready var label: Label = $Label

var wait_time: float = 1

func _ready() -> void:
	#_on_to_start()
	pass

func _on_to_start() -> void:
	show()
	for i in range(3, 0, -1):
		label.text = str(i)
		await get_tree().create_timer(wait_time).timeout
	label.text = "Snake"
	await get_tree().create_timer(wait_time).timeout
	to_started.emit()
	hide()
