extends Node2D
class_name  SnakeBody

@onready var polygon_2d: Polygon2D = $Polygon2D
@onready var line_2d: Line2D = $Line2D

var body_index: int
var last_move: Vector2i : set = _set_last_move
var next_body: SnakeBody : set = _set_next_body
var map_resource: MapResource


func _ready() -> void:
	if not next_body:
		line_2d.hide()
	if not map_resource:
		await owner.ready
		map_resource = owner.map_resource
	line_2d.set_point_position(0, Vector2.ZERO)
	line_2d.set_point_position(1, -last_move * map_resource.cell_size)


func _on_snake_move_finished() -> void:
	var _owner := (owner as Snake)
	var gl_pos = map_resource.calculate_map_position(_owner.snake_body[body_index])
	var gl_rot = Vector2(last_move).angle()
	set_pos_and_rot(gl_pos, gl_rot)
	line_2d.set_point_position(0, Vector2.ZERO)
	line_2d.set_point_position(1, -last_move * map_resource.cell_size)
	

func _set_last_move(v: Vector2i) -> void:
	if next_body:
		next_body.last_move = last_move
	last_move = v


func _set_next_body(v: SnakeBody) -> void:
	next_body = v
	line_2d.show()


func set_pos_and_rot(gl_pos: Vector2, gl_rot: float) -> void:
	global_position = gl_pos
	polygon_2d.global_rotation = gl_rot


func _on_snake_was_dead() -> void:
	pass
