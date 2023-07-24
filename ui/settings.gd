extends Control

@onready var master_volume: HSlider = $GridContainer/MasterVolume
@onready var music_volume: HSlider = $GridContainer/MusicVolume
@onready var sound_volume: HSlider = $GridContainer/SoundVolume
@onready var tween_speed: HSlider = $GridContainer/TweenSpeed
@onready var show_scores: CheckButton = $GridContainer/ShowScores


func _ready() -> void:
	$Back.grab_focus.call_deferred()
	master_volume.value = Settings.master_volume
	music_volume.value = Settings.music_volume
	sound_volume.value = Settings.sound_volume
	tween_speed.value = Settings.tween_speed
	show_scores.button_pressed = Settings.show_scores
	master_volume.value_changed.connect(_on_value_changed.bind(master_volume))
	music_volume.value_changed.connect(_on_value_changed.bind(music_volume))
	sound_volume.value_changed.connect(_on_value_changed.bind(sound_volume))



func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")



func _on_value_changed(value: float, slider: VolumeSlider) -> void:
	AudioServer.set_bus_volume_db(
		slider.bus_index,
		linear_to_db(value)
	)
	Settings.set("%s_volume"%slider.bus_name.to_lower(), value)


func _on_tween_speed_value_changed(value: float) -> void:
	Settings.tween_speed = value


func _on_show_scores_toggled(button_pressed: bool) -> void:
	Settings.show_scores = button_pressed
