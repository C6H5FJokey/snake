extends Control

signal to_started

@onready var label: Label = $Label

var wait_time: float = 1.0
var _elapsed: float = 0.0
var _count: int = 3
var _active: bool = false


func _on_to_start() -> void:
	_count = 3
	_elapsed = 0.0
	_active = true
	label.text = "3"
	show()


func _process(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	while _elapsed >= wait_time and _active:
		_elapsed -= wait_time
		_count -= 1
		if _count < 0:
			_active = false
			hide()
			to_started.emit()
		else:
			label.text = str(_count) if _count > 0 else "Snake"
