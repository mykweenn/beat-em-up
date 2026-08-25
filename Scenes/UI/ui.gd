class_name UI
extends CanvasLayer

const DEATH_SCREEN_PREFAB := preload("res://Scenes/UI/death_screen.tscn")
const GAME_OVER_PREFAB := preload("res://Scenes/UI/game_over_screen.tscn")
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

const AVATAR_MAP : Dictionary = {
	Character.Type.GOON: preload("res://Assets/Art/ui/avatars/avatar-goon.png"),
	Character.Type.PUNK: preload("res://Assets/Art/ui/avatars/avatar-punk.png"),
	Character.Type.THUG: preload("res://Assets/Art/ui/avatars/avatar-thug.png"),
	#Character.Type.PLAYER: preload("res://Assets/Art/ui/avatars/avatar-player.png"),
	Character.Type.PLAYER: preload("res://Assets/Art/ui/avatars/muromec.webp"),
	Character.Type.BOUNCER: preload("res://Assets/Art/ui/avatars/avatar-boss.png"),
	Character.Type.HEAVY: preload("res://Assets/Art/ui/avatars/avatar-boss.png"),
}

var death_screen : DeathScreen = null
var game_over_screen : GameOverScreen = null
var options_screen : OptionsScreen = null
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
	if Input.is_action_just_pressed("ui_cancel"):
		if options_screen == null:
			options_screen = OPTIONS_SCREEN_PREFAB.instantiate()
			options_screen.exit.connect(unpause)
			add_child(options_screen)
			get_tree().paused = true
			SoundPlayer.play(SoundManager.Sound.PAUSE)
		else:
			unpause()
			SoundPlayer.play(SoundManager.Sound.UNPAUSE)


func unpause() -> void:
	options_screen.queue_free()
	get_tree().paused = false
	


func on_combo_reset(points: int) -> void:
	score_indicator.add_combo(points)


func on_character_health_change(type: Character.Type, current_health: int, max_health: int) -> void:
	if type == Character.Type.PLAYER:
		player_health_bar.refresh(current_health, max_health)
		if current_health <= 0 and death_screen == null:
			death_screen = DEATH_SCREEN_PREFAB.instantiate()
			death_screen.game_over.connect(on_game_over.bind())
			add_child(death_screen)
	else:
		time_start_health_bar_visible = Time.get_ticks_msec()
		enemy_avatar.texture = AVATAR_MAP[type]
		enemy_health_bar.refresh(current_health, max_health)
		enemy_avatar.visible = true
		enemy_health_bar.visible = true


func on_game_over() -> void:
	if game_over_screen == null:
		game_over_screen = GAME_OVER_PREFAB.instantiate()
		game_over_screen.set_score(score_indicator.real_score)
		add_child(game_over_screen)


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
