extends GameScene

@export var sub_viewports_path: Array[NodePath] = []
@export var scores_labels_path: Array[NodePath] = []


func _init_game() -> void:
	for path: NodePath in sub_viewports_path:
		var viewport: SubViewport = get_node(path)
		viewport.world_2d = get_viewport().world_2d


func _update_scores(state: Dictionary) -> void:
	for i: int in scores_labels_path.size():
		var label: Label = get_node(scores_labels_path[i])
		label.visible = Settings.show_scores
		label.text = str(state.snakes[i].score)
