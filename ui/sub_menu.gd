extends Control

@onready var map_name: Label = $GridContainer/Panel/MapName
@onready var import: Button = $GridContainer/Panel/Import
@onready var speed_slider: HSlider = $GridContainer/Control/SpeedSlider
@onready var speed_label: Label = $GridContainer/Control/SpeedLabel
@onready var color_1_label: Label = $GridContainer/Color1Label
@onready var player_1_color: ColorPickerButton = $GridContainer/Player1Color
@onready var color_2_label: Label = $GridContainer/Color2Label
@onready var player_2_color: ColorPickerButton = $GridContainer/Player2Color
@onready var file_dialog: FileDialog = $FileDialog


func _ready() -> void:
	$StartGame.grab_focus.call_deferred()
	map_name.text = Game.map_info.name
	speed_slider.value = Game.game_speed if Game.game_speed >= 1.0 else 0.0
	speed_label.text = "x%.1f"%Game.game_speed
	player_1_color.color = Game.player_1_color
	if Game.play_mode == Game.MULTIPLAYER:
		color_2_label.show()
		player_2_color.show()
		color_1_label.text = "Player1 Color"
		player_2_color.color = Game.player_2_color


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")


func _on_start_game_pressed() -> void:
	var layout := MapResource.new()
	var player_count: int = 2 if Game.play_mode == Game.MULTIPLAYER else 1
	if not layout.from_dict(Game.map_info) or not layout.validate(player_count).is_empty():
		_show_map_error()
		return
	Game.map_resource = layout
	match Game.play_mode:
		Game.SINGLE:
			get_tree().change_scene_to_file("res://game_scene/singleplayer_scene.tscn")
		Game.MULTIPLAYER:
			get_tree().change_scene_to_file("res://game_scene/multiplayer_scene.tscn")


func _on_import_pressed() -> void:
	file_dialog.popup_centered_ratio()


func _on_speed_slider_value_changed(value: float) -> void:
	Game.game_speed = speed_slider.value if not is_zero_approx(value) else 0.5
	speed_label.text = "x%.1f"%Game.game_speed


func _on_player_1_color_color_changed(color: Color) -> void:
	Game.player_1_color = color


func _on_player_2_color_color_changed(color: Color) -> void:
	Game.player_2_color = color


func _on_file_dialog_file_selected(path: String) -> void:
	var layout := MapResource.new()
	if not layout.load_map(path):
		_show_map_error()
		return
	Game.map_info = layout.to_dict()
	map_name.text = Game.map_info.name


func _show_map_error() -> void:
	var dialog := AcceptDialog.new()
	dialog.dialog_text = "Invalid map. Check dimensions, cells and snake spawns."
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()
