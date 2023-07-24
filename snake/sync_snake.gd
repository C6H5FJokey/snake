extends Snake
class_name SyncSnake

@onready var sync_controller: SyncController = $SyncController

@export var id: int

func _ready() -> void:
	Net.updated.connect(_on_net_updated)
	super()


func _on_move_requested():
	super()
	if is_multiplayer_authority():
		Net.send_update(0, get_path(), "move_direction")
		Net.send_update(0, get_path(), "snake_body")


func _on_net_updated(path: NodePath, property: String, value: Variant, _from_id: int) -> void:
	if not path == get_path():
		return
	match property:
		"move_direction":
			move_direction = value
			front_body.last_move = move_direction
		"snake_body":
			for i in (value as Array).size():
				if i < snake_body_length:
					snake_body[i] = value[i]
				else:
					snake_body.append(value[i])
					_add_body(snake_body_length, Vector2i.ZERO)
					snake_body_length += 1
			move_finished.emit()
			
