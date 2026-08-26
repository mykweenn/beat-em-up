extends Control

# === СОСТОЯНИЯ МЕНЮ ===
enum MenuState {MAIN, LEVEL_SELECT, OPTIONS}
var state := MenuState.MAIN

# === ГЛАВНОЕ МЕНЮ ===
var current_index := 0
const MENU_ITEMS := ["NEW GAME", "CONTINUE", "SELECT LEVEL", "OPTIONS", "EXIT"]

# === ВЫБОР УРОВНЯ ===
var level_index := 0

# === НОДЫ (заполняются в _ready) ===
@onready var cursor: Label = $MenuLayer/Cursor
@onready var menu_container: VBoxContainer = $MenuLayer/MenuContainer
@onready var level_panel: Control = $LevelLayer/LevelPanel
@onready var level_container: VBoxContainer = $LevelLayer/LevelPanel/LevelVBox
@onready var level_cursor: Label = $LevelLayer/LevelPanel/LevelCursor
@onready var options_screen: OptionsScreen = $OptionsLayer/OptionsScreen
@onready var item_labels: Array[Label] = []

# Визуал
const COLOR_ACTIVE := Color(1.0, 1.0, 1.0)
const COLOR_INACTIVE := Color(0.45, 0.45, 0.45)
const COLOR_LOCKED := Color(0.3, 0.3, 0.3)


func _ready() -> void:
	for i in range(MENU_ITEMS.size()):
		var label : Label = menu_container.get_child(i)
		item_labels.append(label)
	refresh_menu()
	level_panel.visible = false
	options_screen.visible = false
	options_screen.exit.connect(_on_options_exit)
	SoundPlayer.play_static_menu()
	MusicPlayer.play(MusicManager.Music.MENU)


func _process(_delta: float) -> void:
	handle_input()


func handle_input() -> void:
	match state:
		MenuState.MAIN:
			handle_main_input()
		MenuState.LEVEL_SELECT:
			handle_level_input()
		MenuState.OPTIONS:
			pass


# === ГЛАВНОЕ МЕНЮ ===

func handle_main_input() -> void:
	if Input.is_action_just_pressed("ui_up"):
		current_index = wrapi(current_index - 1, 0, MENU_ITEMS.size())
		SoundPlayer.play(SoundManager.Sound.CLICK)
		refresh_menu()
	elif Input.is_action_just_pressed("ui_down"):
		current_index = wrapi(current_index + 1, 0, MENU_ITEMS.size())
		SoundPlayer.play(SoundManager.Sound.CLICK)
		refresh_menu()
	elif Input.is_action_just_pressed("ui_accept"):
		execute_menu_action()


func execute_menu_action() -> void:
	match current_index:
		0:
			SoundPlayer.play(SoundManager.Sound.HIT1)
			SoundPlayer.stop_static_menu()
			GameManager.start_new_game()
		1:
			SoundPlayer.play(SoundManager.Sound.HIT1)
			SoundPlayer.stop_static_menu()
			GameManager.continue_game()
		2:
			SoundPlayer.play(SoundManager.Sound.CLICK)
			state = MenuState.LEVEL_SELECT
			level_index = 0
			show_level_panel()
		3:
			SoundPlayer.play(SoundManager.Sound.CLICK)
			show_options()
		4:
			get_tree().quit()


func refresh_menu() -> void:
	for i in range(item_labels.size()):
		var label := item_labels[i]
		if i == current_index:
			label.text = "> " + MENU_ITEMS[i]
			label.add_theme_color_override("font_color", COLOR_ACTIVE)
		else:
			label.text = "  " + MENU_ITEMS[i]
			label.add_theme_color_override("font_color", COLOR_INACTIVE)


# === ВЫБОР УРОВНЯ ===

func show_level_panel() -> void:
	_rebuild_level_list()
	level_panel.visible = true
	refresh_level_list()


func hide_level_panel() -> void:
	level_panel.visible = false
	state = MenuState.MAIN


func _rebuild_level_list() -> void:
	for child in level_container.get_children():
		level_container.remove_child(child)
		child.queue_free()
	for i in range(GameManager.level_registry.size()):
		var label := Label.new()
		label.text = GameManager.level_registry[i]["name"]
		label.add_theme_font_size_override("font_size", 32)
		level_container.add_child(label)


func handle_level_input() -> void:
	var count := GameManager.level_registry.size()
	if count == 0:
		return
	if Input.is_action_just_pressed("ui_up"):
		level_index = wrapi(level_index - 1, 0, count)
		SoundPlayer.play(SoundManager.Sound.CLICK)
		refresh_level_list()
	elif Input.is_action_just_pressed("ui_down"):
		level_index = wrapi(level_index + 1, 0, count)
		SoundPlayer.play(SoundManager.Sound.CLICK)
		refresh_level_list()
	elif Input.is_action_just_pressed("ui_accept"):
		if level_index < GameManager.get_unlocked_level_count():
			SoundPlayer.play(SoundManager.Sound.HIT1)
			SoundPlayer.stop_static_menu()
			GameManager.load_level(level_index)
		else:
			SoundPlayer.play(SoundManager.Sound.HIT2)
	elif Input.is_action_just_pressed("ui_cancel"):
		SoundPlayer.play(SoundManager.Sound.CLICK)
		hide_level_panel()


func refresh_level_list() -> void:
	var labels := level_container.get_children()
	var unlocked := GameManager.get_unlocked_level_count()
	# Позиция VBoxContainer относительно LevelPanel
	var vbox_offset := level_container.position
	for i in range(labels.size()):
		var label : Label = labels[i]
		if i == level_index:
			level_cursor.position = vbox_offset + label.position + Vector2(-40, 0)
			level_cursor.visible = true
			label.add_theme_color_override("font_color", COLOR_ACTIVE)
		else:
			if i < unlocked:
				label.add_theme_color_override("font_color", COLOR_INACTIVE)
			else:
				label.add_theme_color_override("font_color", COLOR_LOCKED)


# === НАСТРОЙКИ ===

func show_options() -> void:
	state = MenuState.OPTIONS
	options_screen.visible = true
	options_screen.refresh()


func _on_options_exit() -> void:
	options_screen.visible = false
	state = MenuState.MAIN
	SoundPlayer.play(SoundManager.Sound.CLICK)
