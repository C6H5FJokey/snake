extends Node
class_name Snake

signal move_finished
signal food_eaten
signal self_eaten
signal wall_eaten


@onready var snake_head: Node2D = $SnakeHead


@export_group("Component")
@export var map_resource: MapResource
@export var controller: Controller
@export_group("property")
@export var start_pos: Vector2i = Vector2i.ZERO ## 初始位置，没定义蛇身坐标时有效
@export var move_direction: Vector2i = Vector2i.RIGHT ## 蛇头方向
@export var snake_body_length: int = 4 ## 蛇身长度
@export var snake_body: Array[Vector2i] ## 蛇身坐标

var is_dead: bool = false
var front_body: SnakeBody
var rear_body: SnakeBody
var wait_time: float

func _ready() -> void:
	_init_snake.call_deferred()


func _init_snake():
	for i in range(snake_body_length):
		if i >= snake_body.size():
			snake_body.append(snake_body[-1]-move_direction if i > 0 else start_pos)
	for i in range(snake_body_length):
		var last_move: Vector2i
		last_move = snake_body[i]-snake_body[i+1] if i < snake_body_length - 1 else Vector2i.ZERO
		_add_body(i, last_move)


func _on_move_requested():
	if is_dead:
		return
	if move_direction + controller.get_next_move() != Vector2i.ZERO and controller.get_next_move() != Vector2i.ZERO:
		move_direction = controller.get_next_move()
	var temp_pos := Vector2i.ZERO
	var target_pos := map_resource.wrap(snake_body[0] + move_direction)
	for i in range(snake_body_length):
		temp_pos = snake_body[i]
		snake_body[i] = target_pos
		target_pos = temp_pos
	front_body.last_move = move_direction
	# 自噬判断
	for i in range(1, snake_body_length):
		if snake_body[0] == snake_body[i]:
			become_dead()
			self_eaten.emit()
			break
	# 食吃判断
	if map_resource.map[map_resource.as_index(snake_body[0])] == MapResource.FOOD:
		snake_body.append(target_pos)
		_add_body(snake_body_length, Vector2i.ZERO)
		snake_body_length += 1
		food_eaten.emit()
	# 撞墙判断
	if map_resource.map[map_resource.as_index(snake_body[0])] == MapResource.WALL:
		become_dead()
		wall_eaten.emit()
	move_finished.emit()


func _add_body(index: int, last_move: Vector2i):
	var body: SnakeBody = preload("res://snake/snake_body.tscn").instantiate()
	body.map_resource = map_resource
	body.body_index = index
	body.last_move = last_move
	body.wait_time = wait_time
	add_child(body)
	body.owner = self
	var gl_pos = map_resource.calculate_map_position(snake_body[index])
	var gl_rot = Vector2(last_move).angle()
	body.set_pos_and_rot(gl_pos, gl_rot)
	# 尾部指针
	if rear_body:
		rear_body.next_body = body
	rear_body = body
	move_finished.connect(body._on_snake_move_finished)
	## 如果是蛇头
	if index == 0:
		front_body = body
		var remote_transform_2d := RemoteTransform2D.new()
		body.add_child(remote_transform_2d)
		snake_head.global_position = body.global_position
		remote_transform_2d.remote_path = remote_transform_2d.get_path_to(snake_head)


func become_dead():
	is_dead = true
