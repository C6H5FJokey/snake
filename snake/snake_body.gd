class_name SnakeBody
extends Node2D
## One visual segment. All interpolation is driven by the owning Snake view.

@onready var polygon_2d: Polygon2D = $Polygon2D
@onready var line_next: Line2D = $LineNext
@onready var line_prev: Line2D = $LinePrev


func set_color(value: Color) -> void:
	polygon_2d.color = value
	line_next.default_color = value
	line_prev.default_color = value


func set_pose(value: Vector2, angle: float) -> void:
	position = value
	polygon_2d.rotation = angle


func set_links(previous: Vector2, following: Vector2, has_previous: bool, has_following: bool) -> void:
	line_prev.visible = has_previous
	line_next.visible = has_following
	line_prev.set_point_position(0, Vector2.ZERO)
	line_prev.set_point_position(1, previous / 2.0)
	line_next.set_point_position(0, Vector2.ZERO)
	line_next.set_point_position(1, following / 2.0)
