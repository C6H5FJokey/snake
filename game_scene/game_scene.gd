class_name GameScene
extends Node
## Scene composition and presentation. Rules live in MatchSimulation.

@export var map_resource_instance: MapResource
@export var snakes_path: Array[NodePath] = []
@export_range(0.1, 2.0) var wait_time: float = 0.5

@onready var playground: Polygon2D = %Playground
@onready var to_start: Control = %ToStart
@onready var outcome: Control = %Outcome

var snakes: Array[Snake] = []
var map_resource: MapResource
var simulation: MatchSimulation
var food_node: Node2D
var _elapsed: float = 0.0
var _started: bool = false
var _finished: bool = false
var _pads: Array[TouchPad] = []


func is_online() -> bool:
	return false


func _ready() -> void:
	if is_online():
		map_resource = MapResource.new()
		if Net.round_config.is_empty() or not map_resource.from_dict(Net.round_config.map):
			Net.leave_session()
			get_tree().change_scene_to_file.call_deferred("res://ui/main_menu.tscn")
			return
		wait_time = Net.round_config.step_seconds
	else:
		map_resource = (map_resource_instance if map_resource_instance else Game.map_resource).duplicate(true)
		wait_time /= Game.game_speed
	var map_error: String = map_resource.validate(Net.round_config.players.size() if is_online() else snakes_path.size())
	if not map_error.is_empty():
		push_error(map_error)
		return
	var extent: Vector2 = Vector2(map_resource.size * map_resource.cell_size)
	playground.polygon = PackedVector2Array([Vector2.ZERO, Vector2(extent.x, 0), extent, Vector2(0, extent.y)])
	for i: int in map_resource.map.size():
		if map_resource.map[i] == MapResource.WALL:
			var wall: Node2D = preload("res://map/piece/wall.tscn").instantiate()
			add_child(wall)
			wall.position = map_resource.calculate_map_position(map_resource.from_index(i))
	_init_snakes()
	_init_game()
	_connect_inputs()
	if is_online():
		outcome.reset_btn.hide()
		Net.snapshot_received.connect(_apply_snapshot)
		Net.countdown_updated.connect(_on_countdown)
		_apply_snapshot(Net.latest_snapshot)
		if Net.phase in ["loading", "countdown"]:
			to_start.show()
			to_start.get_node("Label").text = "Waiting..."
			if Net.phase == "countdown":
				_on_countdown(Net.countdown_value)
		Net.notify_scene_ready.call_deferred()
	else:
		var players: Array = []
		for snake: Snake in snakes:
			players.append({"id": snake.player_id, "name": str(snake.name), "color": snake.color})
		simulation = MatchSimulation.new()
		simulation.configure(map_resource, players, randi())
		_apply_snapshot(simulation.snapshot())
		to_start.call_deferred("_on_to_start")


func _init_snakes() -> void:
	for i: int in snakes_path.size():
		var snake: Snake = get_node(snakes_path[i])
		snake.player_id = i + 1
		snake.color = Game.player_1_color if i == 0 else Game.player_2_color
		snakes.append(snake)


func _init_game() -> void:
	pass


func _connect_inputs() -> void:
	for snake: Snake in snakes:
		if snake.controller:
			snake.controller.direction_requested.connect(_on_direction_requested.bind(snake.player_id))
	for node: Node in find_children("*", "", true, false):
		if node is TouchPad:
			_pads.append(node)
			var desired_id: int = multiplayer.get_unique_id() if is_online() else (2 if node.action_left.begins_with("p2_") else 1)
			for snake: Snake in snakes:
				if snake.player_id == desired_id and snake.controller:
					node.direction_requested.connect(snake.controller.submit_direction)


func _on_direction_requested(direction: Vector2i, player_id: int) -> void:
	if _finished:
		return
	if is_online():
		Net.submit_direction(direction)
	elif simulation:
		simulation.submit_direction(player_id, direction)


func _physics_process(delta: float) -> void:
	if is_online() or not _started or _finished:
		return
	_elapsed += delta
	while _elapsed >= wait_time and not _finished:
		_elapsed -= wait_time
		simulation.step()
		_apply_snapshot(simulation.snapshot())


func _apply_snapshot(state: Dictionary) -> void:
	if state.is_empty():
		return
	for snake_state: Dictionary in state.snakes:
		for snake: Snake in snakes:
			if snake.player_id == snake_state.id:
				snake.apply_snapshot(snake_state, map_resource, state.tick, wait_time)
	_update_food(state.food)
	_update_scores(state)
	if state.phase == "running":
		to_start.hide()
	if state.phase == "finished" and not _finished:
		_finished = true
		to_start.hide()
		for snake: Snake in snakes:
			if snake.controller:
				snake.controller.enabled = false
		for pad: TouchPad in _pads:
			pad.enabled = false
		if snakes.size() > 1:
			outcome.text = "Draw"
			for snake_state: Dictionary in state.snakes:
				if snake_state.id == state.winner_id:
					outcome.text = "%s Win!" % snake_state.name
		outcome.show()
		var focus: Button = outcome.get_node("Buttons/Back" if is_online() else "Buttons/Reset")
		focus.grab_focus.call_deferred()


func _update_food(cell: Vector2i) -> void:
	if cell == Vector2i(-1, -1):
		if food_node:
			food_node.hide()
		return
	if not food_node:
		food_node = preload("res://map/piece/food.tscn").instantiate()
		add_child(food_node)
	food_node.show()
	food_node.position = map_resource.calculate_map_position(cell)


func _update_scores(state: Dictionary) -> void:
	var label: Label = get_node_or_null("UI/Scores")
	if not label:
		return
	for snake_state: Dictionary in state.snakes:
		if snake_state.id == (multiplayer.get_unique_id() if is_online() else 1):
			label.text = str(snake_state.score)
			label.visible = Settings.show_scores
			return
	label.hide()


func _on_countdown(value: int) -> void:
	to_start.show()
	to_start.get_node("Label").text = str(value) if value > 0 else "Snake"


func _on_to_start_to_started() -> void:
	if is_online() or _started:
		return
	simulation.start()
	_started = true
	_apply_snapshot(simulation.snapshot())


func _on_outcome_back_pressed() -> void:
	if is_online():
		Net.request_return_to_lobby()
	else:
		get_tree().change_scene_to_file("res://ui/main_menu.tscn")


func _on_outcome_reset_pressed() -> void:
	if not is_online():
		get_tree().reload_current_scene()
