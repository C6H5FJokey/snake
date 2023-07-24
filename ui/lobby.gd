extends Control

const player_panel_res = preload("res://ui/player_panel.tscn")

@onready var player_container: VBoxContainer = $PlayerContainer
@onready var ready_btn: Button = $Ready
@onready var import: Button = $GridContainer/Panel/Import
@onready var speed_slider: HSlider = $GridContainer/Control/SpeedSlider
@onready var speed_label: Label = $GridContainer/Control/SpeedLabel
@onready var player_1_color: ColorPickerButton = $GridContainer/Player1Color
@onready var file_dialog: FileDialog = $FileDialog
@onready var map_name: Label = $GridContainer/Panel/MapName

var player_id: Array

func _ready() -> void:
	if multiplayer.get_unique_id() == 1 and Net.player_name == "--server":
		ready_btn.hide()
	multiplayer.multiplayer_peer.refuse_new_connections = false
	Net.set_my_player_info(multiplayer.get_unique_id(), Net.player_name, Game.player_1_color)
	player_id = Array(multiplayer.get_peers())
	player_id.append(multiplayer.get_unique_id())
	player_id.sort()
	if not is_multiplayer_authority():
		Net.request_update(multiplayer.get_unique_id(), Net.get_path(), "ready_dict")
		Net.request_update(multiplayer.get_unique_id(), Net.get_path(), "map_info")
	player_1_color.color = Game.player_1_color
	_update_ui()
	ready_btn.grab_focus.call_deferred()
	Net.set_my_player_info.rpc(multiplayer.get_unique_id(), Net.player_name, Game.player_1_color)
	Net.player_info_updated.connect(_update_player_container)
	Net.updated.connect(_on_net_updated)
	multiplayer.peer_connected.connect(_on_multiplayer_peer_connected)
	multiplayer.peer_disconnected.connect(_on_multiplayer_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_multiplayer_server_disconnected)
	

func _on_multiplayer_peer_connected(id: int):
	player_id.insert(player_id.bsearch(id), id)
	if is_multiplayer_authority():
		Net.confirm_connection.rpc_id(id)
	Net.set_my_player_info.rpc_id(id, multiplayer.get_unique_id(), Net.player_name, Game.player_1_color)


func _on_multiplayer_peer_disconnected(id: int):
	Net.player_info.erase(id)
	player_id.erase(id)
	if is_multiplayer_authority() and Net.ready_dict.get(id, false):
		ready_btn.button_pressed = false
		_on_ready_toggled(false)
	_update_player_container()


func _on_multiplayer_server_disconnected() -> void:
	var dialog := AcceptDialog.new()
	dialog.canceled.connect(dialog.queue_free)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.dialog_text = "Server_was_disconnected"
	get_window().add_child(dialog)
	dialog.popup_centered()
	multiplayer.multiplayer_peer.close()
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")


func _update_player_container() -> void:
	for player_panel in player_container.get_children():
		if not player_id.has(player_panel.name.to_int()): # or player_panel.name == "1" and Net.player_info.get(player_panel.name.to_int()) == "--server"
			player_container.remove_child(player_panel)
			player_panel.queue_free()
	var index: int = 0
	for id in player_id:
		if id == 1 and Net.player_info.get(1, {}).get("name") == "--server":
			continue
		var player_panel: PlayerPanel = player_container.get_node_or_null(str(id))
		if not player_panel:
			player_panel = create_player_panel(id)
			player_container.add_child(player_panel)
			player_container.move_child(player_panel, index)
			player_panel.owner = self
		player_panel.no.text = "%dP"%(index+1)
		player_panel.ready_label.visible = Net.ready_dict.get(id, false)
		player_panel.player_name.text = Net.player_info.get(id, {}).get("name", "Player")
		player_panel.player_color.color = Net.player_info.get(id, {}).get("color", Color.WHITE)
		index += 1
		if is_multiplayer_authority() and id != multiplayer.get_unique_id():
			player_panel.remove_btn.show()
		else:
			player_panel.remove_btn.hide()


func _on_back_pressed() -> void:
	multiplayer.server_disconnected.disconnect(_on_multiplayer_server_disconnected)
	multiplayer.multiplayer_peer.close()
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")


func _on_player_panel_player_removed(id: int) -> void:
	if is_multiplayer_authority():
		multiplayer.multiplayer_peer.disconnect_peer(id)


func _on_ready_toggled(button_pressed: bool) -> void:
	_ready_toggled(multiplayer.get_unique_id(), button_pressed)
	if not is_multiplayer_authority():
		Net.update.rpc_id(1, Net.get_path(), "ready_status", button_pressed, multiplayer.get_unique_id())


@rpc("any_peer")
func _ready_toggled(id: int, pressd: bool) -> void:
	Net.ready_dict[id] = pressd
	var player_panel: PlayerPanel = player_container.get_node(str(id))
	player_panel.ready_label.visible = pressd
	if is_multiplayer_authority():
		Net.send_update(0, Net.get_path(), "ready_dict")
		if player_id.all(func(id: int): return Net.ready_dict.get(id, false)):
			start_game.rpc()


@rpc("call_local")
func start_game():
	multiplayer.multiplayer_peer.refuse_new_connections = true
	Net.ready_dict.clear()
	Game.game_speed = Net.game_speed
	Game.map_resource.from_dict(Net.map_info)
	get_tree().change_scene_to_file("res://game_scene/online_scene.tscn")


func create_player_panel(id: int) -> PlayerPanel:
	var player_panel: PlayerPanel = player_panel_res.instantiate()
	player_panel.name = str(id)
	player_panel.player_removed.connect(_on_player_panel_player_removed.bind(id))
	return player_panel


func _on_net_updated(path: NodePath, property: String, value: Variant, from_id: int):
	if path == Net.get_path():
		match property:
			"ready_dict":
				Net.ready_dict = value
				_update_player_container()
			"ready_status":
				Net.ready_dict[from_id] = value
				Net.send_update(0, Net.get_path(), "read_dict")
				_update_player_container()
				if player_id.all(func(id: int): return Net.ready_dict.get(id, false)):
					start_game.rpc()
			"map_info":
				Net.map_info = value
				_update_game_settings()
			"game_speed":
				Net.game_speed = value
				_update_game_settings()


func _on_speed_slider_value_changed(value: float) -> void:
	Net.game_speed = speed_slider.value if not is_zero_approx(value) else 0.5
	speed_label.text = "x%.1f"%Net.game_speed
	Net.send_update(0, Net.get_path(), "game_speed")


func _on_file_dialog_file_selected(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file:
		Net.map_info = file.get_var()
		map_name.text = Net.map_info.get("name", "")
		Net.send_update(0, Net.get_path(), "map_info")


func _on_import_pressed() -> void:
	file_dialog.popup_centered_ratio()


func _update_game_settings():
	if is_multiplayer_authority():
		import.show()
		speed_slider.editable = true
	else:
		import.hide()
		speed_slider.editable = false
	map_name.text = Net.map_info.get("name", "")
	speed_slider.value = Net.game_speed
	speed_label.text = "x%.1f"%Net.game_speed


func _update_ui():
	_update_game_settings()
	_update_player_container()


func _on_player_1_color_color_changed(color: Color) -> void:
	Game.player_1_color = color
	Net.set_my_player_info(multiplayer.get_unique_id(), Net.player_name, color)
	Net.set_my_player_info.rpc(multiplayer.get_unique_id(), Net.player_name, color)
