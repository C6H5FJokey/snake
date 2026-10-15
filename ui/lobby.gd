extends Control

@onready var player_container: VBoxContainer = $PlayerContainer
@onready var ready_btn: Button = $Ready
@onready var import_button: Button = $GridContainer/Panel/Import
@onready var speed_slider: HSlider = $GridContainer/Control/SpeedSlider
@onready var speed_label: Label = $GridContainer/Control/SpeedLabel
@onready var player_color: ColorPickerButton = $GridContainer/Player1Color
@onready var file_dialog: FileDialog = $FileDialog
@onready var map_name: Label = $GridContainer/Panel/MapName

var _updating: bool = false


func _ready() -> void:
	Net.lobby_updated.connect(_update_ui)
	Net.connection_error.connect(_show_error)
	player_color.color = Game.player_1_color
	_update_ui()
	ready_btn.grab_focus.call_deferred()
	if not Net.status_message.is_empty():
		_show_error(Net.status_message)
		Net.status_message = ""


func _update_ui() -> void:
	_updating = true
	var is_host: bool = multiplayer.is_server()
	import_button.visible = is_host
	speed_slider.editable = is_host
	speed_slider.set_value_no_signal(Net.game_speed)
	speed_label.text = "x%.1f" % Net.game_speed
	map_name.text = Net.map_info.get("name", "")
	ready_btn.visible = not Net.player_info.get(multiplayer.get_unique_id(), {}).get("dedicated", false)
	ready_btn.set_pressed_no_signal(Net.ready_dict.get(multiplayer.get_unique_id(), false))
	for child: Node in player_container.get_children():
		player_container.remove_child(child)
		child.queue_free()
	for player: Dictionary in Net.match_players():
		var panel: PlayerPanel = preload("res://ui/player_panel.tscn").instantiate()
		panel.name = str(player.id)
		player_container.add_child(panel)
		panel.no.text = "%dP" % (panel.get_index() + 1)
		panel.player_name.text = player.name
		panel.player_color.color = player.color
		panel.ready_label.visible = Net.ready_dict.get(player.id, false)
		panel.remove_btn.visible = is_host and player.id != 1
		panel.player_removed.connect(_on_player_removed.bind(player.id))
	_updating = false


func _on_ready_toggled(value: bool) -> void:
	if not _updating:
		Net.set_ready(value)


func _on_back_pressed() -> void:
	Net.leave_session()
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")


func _on_player_removed(id: int) -> void:
	if multiplayer.is_server():
		multiplayer.multiplayer_peer.disconnect_peer(id)


func _on_speed_slider_value_changed(value: float) -> void:
	if not _updating:
		Net.set_game_settings(Net.map_info, value if value > 0.0 else 0.5)


func _on_import_pressed() -> void:
	file_dialog.popup_centered_ratio()


func _on_file_dialog_file_selected(path: String) -> void:
	var layout := MapResource.new()
	if not layout.load_map(path) or not Net.set_game_settings(layout.to_dict(), Net.game_speed):
		_show_error("Invalid map. Check dimensions, cells and snake spawns.")


func _on_player_1_color_color_changed(color: Color) -> void:
	if not _updating:
		Game.player_1_color = color
		Net.set_profile(Net.player_name, color)


func _show_error(message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.dialog_text = message
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()
