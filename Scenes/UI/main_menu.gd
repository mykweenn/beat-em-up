extends Control

var game_scene : PackedScene

func _ready() -> void:
	$Panel/MarginContainer/VBoxContainer/StartButton.pressed.connect(_on_button_start_pressed)
	$Panel/MarginContainer/VBoxContainer/ContinueButton.pressed.connect(_on_button_continue_pressed)
	$Panel/MarginContainer/VBoxContainer/SettingsButton.pressed.connect(_on_button_settings_pressed)
	$Panel/MarginContainer/VBoxContainer/ExitButton.pressed.connect(_on_button_exit_pressed)
	$Settings/BackButton.pressed.connect(_on_button_back_pressed)
	$Settings.visible = false

# main menu ui

func _on_button_start_pressed():
	get_tree().change_scene_to_file("res://Scenes/world.tscn")


func _on_button_settings_pressed():
	$Settings.visible = true


func _on_button_exit_pressed():
	get_tree().quit()


func _on_button_continue_pressed():
	pass

# settings ui

func _on_button_back_pressed():
	$Settings.visible = false
