class_name Snake
extends Node
## Snapshot-only view. Never advances rules, modifies scores or sends network messages.

@export var controller: Controller
@export var start_pos: Vector2i = Vector2i.ZERO
@export var move_direction: Vector2i = Vector2i.RIGHT
@export var snake_body_length: int = 4
@export var color: Color = Color.WHITE

@onready var snake_head: Node2D = $SnakeHead

var player_id: int = 0
var snake_body: Array[Vector2i] = []
var is_dead: bool = false
var _layout: MapResource
var _segments: Array[SnakeBody] = []
var _from: Array[Vector2] = []
var _to: Array[Vector2] = []
var _from_angles: Array[float] = []
var _angles: Array[float] = []
var _tick: int = -1
var _elapsed: float = 0.0
var _duration: float = 0.0


func apply_snapshot(state: Dictionary, layout: MapResource, tick: int, step_seconds: float) -> void:
	_layout = layout
	player_id = state.id
	color = state.color
	is_dead = state.dead
	move_direction = state.direction
	var adjacent: bool = _tick >= 0 and tick == _tick + 1
	_tick = tick
	snake_body.clear()
	for cell: Vector2 in state.body:
		snake_body.append(Vector2i(cell))
	snake_body_length = snake_body.size()
	var previous_count: int = _segments.size()
	while _segments.size() < snake_body.size():
		var segment: SnakeBody = preload("res://snake/snake_body.tscn").instantiate()
		add_child(segment)
		_segments.append(segment)
	while _segments.size() > snake_body.size():
		_segments.pop_back().queue_free()
	_from.clear()
	_to.clear()
	_from_angles.clear()
	_angles.clear()
	for i: int in snake_body.size():
		var target: Vector2 = layout.calculate_map_position(snake_body[i])
		var direction: Vector2i = move_direction if i == 0 else _cell_direction(snake_body[i - 1] - snake_body[i])
		_from.append(_segments[i].position if adjacent and i < previous_count else target)
		_to.append(target)
		_from_angles.append(_segments[i].polygon_2d.rotation if adjacent and i < previous_count else Vector2(direction).angle())
		_angles.append(Vector2(direction).angle())
		_segments[i].set_color(color)
	_elapsed = 0.0
	_duration = step_seconds * Settings.tween_speed if adjacent else 0.0
	_update_visual(0.0 if _duration > 0.0 else 1.0)
	set_process(_duration > 0.0)


func _process(delta: float) -> void:
	if _layout == null or _segments.is_empty():
		return
	_elapsed += delta
	var weight: float = clampf(_elapsed / _duration, 0.0, 1.0) if _duration > 0.0 else 1.0
	_update_visual(weight)
	if weight >= 1.0:
		set_process(false)


func _update_visual(weight: float) -> void:
	for i: int in _segments.size():
		var value: Vector2 = _from[i].lerp(_to[i], weight)
		var difference: Vector2 = _to[i] - _from[i]
		var board: Vector2 = Vector2(_layout.size * _layout.cell_size)
		# Cross the nearest edge in two halves, rather than traversing the whole board.
		for axis: int in 2:
			if absf(difference[axis]) > board[axis] / 2.0:
				var movement: float = difference[axis] - signf(difference[axis]) * board[axis]
				value[axis] = _from[i][axis] + movement * weight
				value[axis] = wrapf(value[axis], 0.0, board[axis])
		_segments[i].set_pose(value, lerp_angle(_from_angles[i], _angles[i], sin(weight * PI / 2.0)))
	for i: int in _segments.size():
		var previous: Vector2 = _visual_delta(_segments[i - 1].position - _segments[i].position) if i > 0 else Vector2.ZERO
		var following: Vector2 = _visual_delta(_segments[i + 1].position - _segments[i].position) if i + 1 < _segments.size() else Vector2.ZERO
		_segments[i].set_links(previous, following, i > 0, i + 1 < _segments.size())
	if not _segments.is_empty():
		snake_head.position = _segments[0].position


func _visual_delta(value: Vector2) -> Vector2:
	var board: Vector2 = Vector2(_layout.size * _layout.cell_size)
	for axis: int in 2:
		if absf(value[axis]) > board[axis] / 2.0:
			value[axis] -= signf(value[axis]) * board[axis]
	return value


func _cell_direction(value: Vector2i) -> Vector2i:
	for axis: int in 2:
		if absi(value[axis]) > 1:
			value[axis] = -signi(value[axis])
	return value
