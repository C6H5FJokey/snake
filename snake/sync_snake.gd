extends Snake
class_name SyncSnake

@onready var sync_controller: SyncController = $SyncController

@export var id: int


func _on_multiplayer_synchronizer_synchronized() -> void:
	pass
