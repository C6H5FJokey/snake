extends AudioStreamPlayer

const bgm_list = [
	preload("res://assets/snake.ogg")
]

var current := 0

func _ready() -> void:
	stream = bgm_list[current]
	play()


func _on_finished() -> void:
	current = (current + 1) % bgm_list.size()
	stream = bgm_list[current]
	play()
