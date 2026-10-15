class_name SyncController
extends InputController
## Compatibility scene component; transport belongs exclusively to Net.

@export var id: int = 0


func _unhandled_input(event: InputEvent) -> void:
	if id == multiplayer.get_unique_id():
		super(event)
