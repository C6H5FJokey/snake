extends TouchScreenButton

@export var is_pressing: bool = false
@export var action_left: String
@export var action_right: String
@export var action_up: String
@export var action_down: String

var center_position: Vector2 = Vector2.ZERO
var touch_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	var texture: Texture2D = texture_normal
	var bitmap: BitMap = BitMap.new()
	bitmap.create_from_image_alpha(texture.get_image())
	bitmask = bitmap
	center_position = texture.get_size()/2 * scale

func _input(event: InputEvent) -> void:
	if not is_pressing:
		return
	var parse_event := InputEventAction.new()
	parse_event.pressed = true
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		touch_position = event.position - (global_position + center_position)
		if abs(touch_position.aspect())>=1:
			if touch_position.x <= 0:
				parse_event.action = action_left
			else:
				parse_event.action = action_right
		else:
			if touch_position.y <= 0:
				parse_event.action = action_up
			else:
				parse_event.action = action_down
		Input.parse_input_event(parse_event)
			


func _on_pressed() -> void:
	is_pressing = true


func _on_released() -> void:
	is_pressing = false
