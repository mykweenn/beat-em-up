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
@onready var cursor: Label = $UI/MenuLayer/Cursor
@onready var title_label: Label = $UI/MenuLayer/TitleLabel
@onready var menu_container: VBoxContainer = $UI/MenuLayer/MenuContainer
@onready var level_panel: Control = $UI/LevelLayer/LevelPanel
@onready var level_container: VBoxContainer = $UI/LevelLayer/LevelPanel/LevelVBox
@onready var level_cursor: Label = $UI/LevelLayer/LevelPanel/LevelCursor
@onready var options_screen: OptionsScreen = $UI/OptionsLayer/OptionsScreen
@onready var fade_overlay: ColorRect = $UI/FadeOverlay
@onready var item_labels: Array[Label] = []

# Визуал
const COLOR_ACTIVE := Color(1.0, 1.0, 1.0)
const COLOR_INACTIVE := Color(0.45, 0.45, 0.45)
const COLOR_LOCKED := Color(0.3, 0.3, 0.3)

# === VHS TRACKING ERROR ===
# Множитель частоты мерцания (sin). Чем выше — тем быстрее «моргает» сигнал.
const VHS_FLICKER_SPEED := 18.0
# Минимальная прозрачность при мерцании (0.85 = не темнее 85%).
const VHS_FLICKER_MIN := 0.85
# Префиксы текста кнопок.
const CURSOR_PREFIX := "> "
const ITEM_PREFIX := "  "

# Материал VHS-тряски надписей (дрожание пикселей текста, без изменения раскладки).
@onready var vhs_label_material: ShaderMaterial = preload("res://Resources/vhs_label_material.tres")


func _ready() -> void:
	for i in range(MENU_ITEMS.size()):
		var label : Label = menu_container.get_child(i)
		item_labels.append(label)
	refresh_menu()
	# VHS-тряска надписей: один шейдерный материал на все надписи главного меню
	# (раскладка VBoxContainer не трогается — смещение делает шейдер по пикселям).
	title_label.material = vhs_label_material
	for label in item_labels:
		label.material = vhs_label_material
	level_panel.visible = false
	options_screen.visible = false
	options_screen.exit.connect(_on_options_exit)
	SoundPlayer.play_static_menu()
	# MusicPlayer.play(MusicManager.Music.MENU)
	$MainMenuMusic.play()
	$AmbientSFX.play()
	# Fade из чёрного
	fade_overlay.visible = true
	var tween := create_tween()
	tween.tween_property(fade_overlay, "color:a", 0.0, 0.8).from(1.0)
	tween.tween_callback(fade_overlay.hide)


func _process(delta: float) -> void:
	handle_input()
	# VHS-эффект применяется каждый кадр к активной/неактивным кнопкам.
	if state == MenuState.MAIN:
		_apply_vhs_effects(delta)


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
			label.text = CURSOR_PREFIX + MENU_ITEMS[i]
			label.add_theme_color_override("font_color", COLOR_ACTIVE)
		else:
			label.text = ITEM_PREFIX + MENU_ITEMS[i]
			label.add_theme_color_override("font_color", COLOR_INACTIVE)


# === VHS TRACKING ERROR ===

func _apply_vhs_effects(_delta: float) -> void:
	for i in range(item_labels.size()):
		var label := item_labels[i]
		if i == current_index:
			# --- АКТИВНАЯ КНОПКА ---
			# Мерцание прозрачности: sin() с высокой частотой.
			# (sin(TIME * speed) + 1) / 2  →  от 0.0 до 1.0
			# Затем map в диапазон [FLICKER_MIN, 1.0].
			var flicker_raw := (sin(Time.get_ticks_msec() * 0.001 * VHS_FLICKER_SPEED) + 1.0) * 0.5
			label.modulate.a = lerpf(VHS_FLICKER_MIN, 1.0, flicker_raw)
		else:
			# --- НЕАКТИВНАЯ КНОПКА ---
			label.modulate.a = 1.0
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
