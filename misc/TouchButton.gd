class_name TouchPad
extends Control
## A captured finger submits discrete intents, never synthetic pressed actions.

signal direction_requested(direction: Vector2i)

@export var texture_normal: Texture2D
@export var action_left: String = "p1_left"
@export var action_right: String = "p1_right"
@export var action_up: String = "p1_up"
@export var action_down: String = "p1_down"
@export_range(0.0, 0.5) var deadzone_ratio: float = 0.18
@export_range(0.0, 30.0) var hysteresis_degrees: float = 10.0

var enabled: bool = true:
	set(value):
		enabled = value
		if not value:
			cancel_touch()
var finger_index: int = -1
var _direction: Vector2i = Vector2i.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visibility_changed.connect(cancel_touch)
	visible = DisplayServer.is_touchscreen_available()
	queue_redraw()


func _draw() -> void:
	if texture_normal:
		draw_texture_rect(texture_normal, Rect2(Vector2.ZERO, size), false)


func _input(event: InputEvent) -> void:
	if handle_touch(event):
		get_viewport().set_input_as_handled()


func handle_touch(event: InputEvent) -> bool:
	if not enabled or not is_visible_in_tree():
		return false
	if event is InputEventScreenTouch:
		if event.index == finger_index and (not event.pressed or event.canceled):
			cancel_touch()
			return true
		if not event.pressed or event.canceled or finger_index != -1:
			return false
		var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if not Rect2(Vector2.ZERO, size).has_point(local):
			return false
		finger_index = event.index
		_update_direction(local)
		return true
	if event is InputEventScreenDrag and event.index == finger_index:
		var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if Rect2(Vector2.ZERO, size).has_point(local):
			_update_direction(local)
		else:
			_direction = Vector2i.ZERO
		return true
	return false


func _update_direction(local: Vector2) -> void:
	var offset: Vector2 = local - size / 2.0
	if offset.length() <= minf(size.x, size.y) * 0.5 * deadzone_ratio:
		_direction = Vector2i.ZERO
		return
	if _direction != Vector2i.ZERO:
		var difference: float = absf(Vector2(_direction).angle_to(offset))
		if difference <= PI / 4.0 + deg_to_rad(hysteresis_degrees):
			return
	var direction: Vector2i
	if absf(offset.x) >= absf(offset.y):
		direction = Vector2i(signi(int(offset.x)), 0)
	else:
		direction = Vector2i(0, signi(int(offset.y)))
	if direction != _direction:
		_direction = direction
		direction_requested.emit(direction)


func cancel_touch() -> void:
	finger_index = -1
	_direction = Vector2i.ZERO


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_EXIT_TREE:
		cancel_touch()
