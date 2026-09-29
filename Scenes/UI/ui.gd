class_name UI
extends CanvasLayer

const OPTIONS_SCREEN_PREFAB := preload("res://Scenes/UI/options_screen.tscn")

@onready var enemy_avatar: TextureRect = %EnemyAvatar
@onready var enemy_health_bar: HealthBar = %EnemyHealthBar
@onready var player_avatar: TextureRect = %PlayerAvatar
@onready var player_health_bar: HealthBar = %PlayerHealthBar
@onready var combo_indicator: ComboIndicator = %ComboIndicator
@onready var score_indicator: ScoreIndicator = %ScoreIndicator
@onready var go_indicator: FlickeringTextureRect = %GoIndicator
@onready var stage_transition: StageTransition = %StageTransition
@onready var current_task_label: Label = $MarginContainer/UIContainer/CurrentTaskLabel

@export var duration_health_bar_visible : int
@export var hint_scene: PackedScene = preload("res://Scenes/UI/hint_popup.tscn")

@export_group("Death Sequence")
## Целевой масштаб времени во время смерти игрока (меньше 1 = slow-mo).
@export var death_slowmo_scale := 0.25
## Время плавного замедления времени (сек).
@export var death_slowmo_ramp_time := 0.4
## Во сколько раз камера приближается к игроку при смерти.
@export var death_camera_zoom := 1.6
## Время наезда камеры на игрока (сек).
@export var death_camera_time := 0.7
## Пауза на кадре с игроком до затемнения (сек).
@export var death_hold_time := 1.1
## Плавность затемнения экрана (сек).
@export var death_fade_time := 1.5
## Пауза в черноте перед рестартом уровня (сек).
@export var death_black_hold_time := 0.6

const AVATAR_MAP : Dictionary = {
	Character.Type.GOON: preload("res://Assets/Art/ui/avatars/avatar-goon.png"),
	Character.Type.PUNK: preload("res://Assets/Art/ui/avatars/avatar-punk.png"),
	Character.Type.THUG: preload("res://Assets/Art/ui/avatars/avatar-thug.png"),
	#Character.Type.PLAYER: preload("res://Assets/Art/ui/avatars/avatar-player.png"),
	Character.Type.PLAYER: preload("res://Assets/Art/ui/avatars/muromec.webp"),
	Character.Type.BOUNCER: preload("res://Assets/Art/ui/avatars/avatar-boss.png"),
	Character.Type.HEAVY: preload("res://Assets/Art/ui/avatars/avatar-boss.png"),
	Character.Type.LEAPER: preload("res://Assets/Art/ui/avatars/avatar-thug.png"),
}

var options_screen : OptionsScreen = null
var is_death_sequence_active := false
var _death_black_overlay : ColorRect = null
var time_start_health_bar_visible = Time.get_ticks_msec()


func _init() -> void:
	DamageManager.health_change.connect(on_character_health_change.bind())
	StageManager.checkpoint_complete.connect(on_checkpoint_complete.bind())
	StageManager.stage_complete.connect(on_stage_complete.bind())


func _ready() -> void:
	enemy_avatar.visible = false
	enemy_health_bar.visible = false
	combo_indicator.combo_reset.connect(on_combo_reset.bind())
	start_wiggle()


func _process(_delta: float) -> void:
	if enemy_health_bar.visible and (Time.get_ticks_msec() - time_start_health_bar_visible > duration_health_bar_visible):
		enemy_avatar.visible = false
		enemy_health_bar.visible = false
	handle_input()


func handle_input() -> void:
	# Не даём открыть паузу во время кинематографичной смерти
	if is_death_sequence_active:
		return
	if Input.is_action_just_pressed("ui_cancel"):
		if options_screen == null:
			options_screen = OPTIONS_SCREEN_PREFAB.instantiate()
			options_screen.exit.connect(unpause)
			add_child(options_screen)
			# Музыка продолжает играть, но приглушается — удобно настраивать громкость
			MusicPlayer.set_ducked(true)
			get_tree().paused = true
			SoundPlayer.play(SoundManager.Sound.PAUSE)
			SoundPlayer.play_static_menu()
		else:
			unpause()
			SoundPlayer.play(SoundManager.Sound.UNPAUSE)


func unpause() -> void:
	options_screen.queue_free()
	MusicPlayer.set_ducked(false)
	get_tree().paused = false
	SoundPlayer.stop_static_menu()
	


func on_combo_reset(points: int) -> void:
	score_indicator.add_combo(points)


func on_character_health_change(type: Character.Type, current_health: int, max_health: int) -> void:
	if type == Character.Type.PLAYER:
		player_health_bar.refresh(current_health, max_health)
		if current_health <= 0:
			start_death_sequence()
	else:
		time_start_health_bar_visible = Time.get_ticks_msec()
		enemy_avatar.texture = AVATAR_MAP[type]
		enemy_health_bar.refresh(current_health, max_health)
		enemy_avatar.visible = true
		enemy_health_bar.visible = true


func on_checkpoint_complete(_checkpoint: Checkpoint) -> void:
	go_indicator.start_flickering()


func on_stage_complete() -> void:
	stage_transition.start_transition()


func start_wiggle() -> void:
	var tween = create_tween()
	tween.set_loops()
	current_task_label.pivot_offset = current_task_label.size / 2
	tween.tween_property(current_task_label, "rotation_degrees", -5, 0.8)
	tween.tween_property(current_task_label, "rotation_degrees", 5, 0.8)
	tween.tween_property(current_task_label, "rotation_degrees", 0, 0.35)


## Кинематографичная смерть игрока:
## 1) плавное замедление времени (slow-mo) + замедление музыки и звуков;
## 2) камера подъезжает к игроку и приближается;
## 3) затемнение экрана; 4) перезапуск текущего уровня.
func start_death_sequence() -> void:
	if is_death_sequence_active:
		return
	is_death_sequence_active = true

	var world := get_parent() as World
	var cam := world.get_node_or_null("Camera") as Camera2D

	# 1. Плавно замедляем время (весь мир уходит в slow-mo) и аудио
	var slow_tween := create_tween()
	slow_tween.set_ignore_time_scale(true)
	slow_tween.tween_method(_set_time_scale, Engine.time_scale, death_slowmo_scale, death_slowmo_ramp_time)
	MusicPlayer.set_slowmo(true)
	SoundPlayer.set_slowmo(true)

	# 2. Камера наезжает на игрока и приближается
	if cam != null:
		world.is_death_sequence_active = true
		cam.position_smoothing_enabled = false
		if cam.has_method("set_handheld_shake"):
			cam.set_handheld_shake(false)
		if cam.has_method("set_finisher_zoom"):
			cam.set_finisher_zoom(false)
		var focus := world.player.global_position if world.player != null else cam.global_position
		var cam_tween := create_tween().set_parallel(true).set_ignore_time_scale(true)
		cam_tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		cam_tween.tween_property(cam, "global_position", focus, death_camera_time)
		cam_tween.tween_property(cam, "zoom", Vector2(death_camera_zoom, death_camera_zoom), death_camera_time)

	# 3. Держим кадр на умирающем игроке
	await get_tree().create_timer(death_hold_time, true, false, true).timeout

	# 4. Затемнение экрана
	_create_death_overlay()
	var fade_tween := create_tween().set_ignore_time_scale(true)
	fade_tween.tween_property(_death_black_overlay, "color:a", 1.0, death_fade_time)

	# 5. Короткая пауза в темноте
	await get_tree().create_timer(death_black_hold_time, true, false, true).timeout

	# 6. Возвращаем время и аудио, перезапускаем уровень
	_set_time_scale(1.0)
	MusicPlayer.set_slowmo(false)
	SoundPlayer.set_slowmo(false)
	GameManager.load_level(GameManager.current_level_index)


func _set_time_scale(value: float) -> void:
	Engine.time_scale = value


func _create_death_overlay() -> void:
	if _death_black_overlay != null:
		return
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_death_black_overlay = overlay
	add_child(overlay)
