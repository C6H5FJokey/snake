extends Node2D
class_name  SnakeBody

@onready var polygon_2d: Polygon2D = $Polygon2D
@onready var line_next: Line2D = $LineNext
@onready var line_prev: Line2D = $LinePrev

var body_index: int
var last_move: Vector2i : set = _set_last_move
var next_body: SnakeBody : set = _set_next_body
var prev_body: SnakeBody : set = _set_prev_body
var map_resource: MapResource
var wait_time: float
var color: Color


func _ready() -> void:
	polygon_2d.color = color
	line_next.default_color = color
	line_prev.default_color = color
	if not next_body:
		line_next.hide()
		line_prev.hide()
	if not map_resource:
		await owner.ready
		map_resource = owner.map_resource
	line_next.set_point_position(0, Vector2.ZERO)
	line_next.set_point_position(1, -last_move * map_resource.cell_size)
	line_prev.set_point_position(0, prev_body.last_move * map_resource.cell_size / 2.0 if prev_body else Vector2.ZERO)
	line_prev.set_point_position(1, Vector2.ZERO)

func _on_snake_move_finished() -> void:
	var _owner := (owner as Snake)
	var gl_pos = map_resource.calculate_map_position(_owner.snake_body[body_index])
	if is_zero_approx(Settings.tween_speed):
		global_position = gl_pos
		polygon_2d.global_rotation = Vector2(last_move).angle()
		line_next.set_point_position(0, Vector2.ZERO)
		line_next.set_point_position(1, -last_move * map_resource.cell_size / 2.0)
		line_prev.set_point_position(0, Vector2.ZERO)
		line_prev.set_point_position(1, prev_body.last_move * map_resource.cell_size / 2.0 if prev_body else Vector2.ZERO)
	else:
		var tween := create_tween().set_parallel()
		var gl_rot = Vector2.from_angle(polygon_2d.global_rotation).angle_to(last_move) + polygon_2d.global_rotation
		var set_prev_pos_0 := func(x:Vector2):line_prev.set_point_position(0, x)
		var set_prev_pos_1 := func(x:Vector2):line_prev.set_point_position(1, x)
		var set_next_pos_0 := func(x:Vector2):line_next.set_point_position(0, x)
		var set_next_pos_1 := func(x:Vector2):line_next.set_point_position(1, x)
		line_next.set_point_position(0, Vector2.ZERO)
		line_prev.set_point_position(0, Vector2.ZERO)
		tween.tween_property(polygon_2d, "global_rotation", gl_rot, wait_time * Settings.tween_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		if next_body:
			tween.tween_method(set_next_pos_1, line_next.get_point_position(1), -last_move * map_resource.cell_size / 2.0, wait_time * Settings.tween_speed)
		else:
			line_next.set_point_position(1, -last_move * map_resource.cell_size / 2.0)
		if prev_body:
			tween.tween_method(set_prev_pos_1, line_prev.get_point_position(1), prev_body.last_move * map_resource.cell_size / 2.0, wait_time * Settings.tween_speed)
		else:
			line_prev.set_point_position(1, prev_body.last_move * map_resource.cell_size / 2.0 if prev_body else Vector2.ZERO)
		if map_resource.is_within_bounds(_owner.snake_body[body_index]-last_move):
			tween.tween_property(self, "global_position", gl_pos, wait_time * Settings.tween_speed)
		else:
			tween = create_tween()
			tween.tween_property(self, "global_position", global_position + Vector2(last_move * map_resource.half_cell_size), wait_time * Settings.tween_speed / 2.0)
			tween.tween_property(self, "global_position", gl_pos, wait_time * Settings.tween_speed / 2.0).from(gl_pos - Vector2(last_move * map_resource.half_cell_size))


func _set_last_move(v: Vector2i) -> void:
	if next_body:
		next_body.last_move = last_move
	last_move = v


func _set_next_body(v: SnakeBody) -> void:
	next_body = v
	line_next.show()


func _set_prev_body(v: SnakeBody) -> void:
	prev_body = v
	line_prev.show()


func set_pos_and_rot(gl_pos: Vector2, gl_rot: float) -> void:
	global_position = gl_pos
	polygon_2d.global_rotation = gl_rot


func _on_snake_was_dead() -> void:
	pass
