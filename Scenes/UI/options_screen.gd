class_name OptionsScreen
extends Control

signal exit

@onready var music_volume_control: RangePicker = $Background/MarginContainer/VBoxContainer/MusicVolumeControl
@onready var sfx_control: RangePicker = $Background/MarginContainer/VBoxContainer/SoundVolumeControl
@onready var shake_toggle: TogglePicker = $Background/MarginContainer/VBoxContainer/ShakeToggle
@onready var return_button: LabelPicker = $Background/MarginContainer/VBoxContainer/ReturnButton
@onready var activables : Array[ActivableControl] = [music_volume_control, sfx_control, shake_toggle, return_button]

var current_selection_index := 0


func _ready() -> void:
	music_volume_control.set_value(OptionsManager.music_volume)
	sfx_control.set_value(OptionsManager.sfx_volume)
	shake_toggle.set_value(OptionsManager.is_screenshake_enabled as int)
	music_volume_control.value_change.connect(on_music_volume_change.bind())
	sfx_control.value_change.connect(on_sfx_value_change.bind())
	shake_toggle.value_change.connect(on_screenshake_value_change.bind())
	return_button.press.connect(on_return_press.bind())
	refresh()

func refresh() -> void:
	for i in range(0, activables.size()):
		activables[i].set_active(current_selection_index == i)


func _process(_delta: float) -> void:
	handle_input()


func handle_input() -> void:
	if Input.is_action_just_pressed("ui_down"):
		current_selection_index = clampi(current_selection_index + 1, 0, activables.size() - 1)
		refresh()
		SoundPlayer.play(SoundManager.Sound.CLICK)
	if Input.is_action_just_pressed("ui_up"):
		current_selection_index = clampi(current_selection_index - 1, 0, activables.size() - 1)
		refresh()
		SoundPlayer.play(SoundManager.Sound.CLICK)


func on_music_volume_change(value: int) -> void:
	OptionsManager.set_music_volume(value)


func on_sfx_value_change(value: int) -> void:
	OptionsManager.set_sfx_volume(value)
	SoundPlayer.play(SoundManager.Sound.HIT1)


func on_screenshake_value_change(value: int) -> void:
	OptionsManager.set_screenshake(value == 1)


func on_return_press() -> void:
	exit.emit()
