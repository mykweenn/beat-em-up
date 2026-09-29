class_name MusicManager
extends Node

enum Music {INTRO, MENU, STAGE1, STAGE2, STAGE1_ALT, ARENA, STREETS, BACK_STREETS}

## Индекс шины музыки в AudioServer (см. OptionsManager.set_music_volume).
const MUSIC_BUS_IDX := 1

@export_group("Pause Ducking")
## Насколько приглушать музыку в паузе (дБ, отрицательное — тише).
@export var duck_offset_db := -18.0
## Плавность перехода громкости при входе/выходе из паузы (сек).
@export var duck_fade_duration := 0.3

@export_group("Death Slowmo")
## Во сколько раз замедлять воспроизведение музыки при смерти игрока.
## pitch_scale < 1 = медленнее и ниже по тону (эффект slow-mo).
@export var slowmo_pitch := 0.55
## Плавность перехода к замедленному воспроизведению (сек).
@export var slowmo_fade_duration := 0.4

@onready var music_stream_player: AudioStreamPlayer = $MusicStreamPlayer

var autoplayer_music : AudioStream = null

var is_ducked := false
var _restore_volume_db := 0.0
var _duck_volume := 0.0
var _duck_tween : Tween = null
var _slowmo_tween : Tween = null

const MUSIC_MAP : Dictionary = {
	Music.INTRO: preload("res://Assets/Music/Kane   Lynch 2 Dog Days - Singapore Nights.mp3"),
	Music.MENU: preload("res://Assets/Music/Kane   Lynch 2 Dog Days - Singapore Nights.mp3"),
	Music.STAGE1: preload("res://Assets/Music/Le perv - Carpenter Brut.mp3"),
	Music.STAGE2: preload("res://Assets/Music/Le perv - Carpenter Brut.mp3"),
	Music.STAGE1_ALT: preload("res://Assets/Music/Le perv - Carpenter Brut.mp3"),
	Music.ARENA: preload("res://Assets/Music/Le perv - Carpenter Brut.mp3"),
	Music.STREETS: preload("res://Assets/Music/Le perv - Carpenter Brut.mp3"),
	Music.BACK_STREETS: preload("res://Assets/Music/Le perv - Carpenter Brut.mp3"),
}


func _ready() -> void:
	# Музыка должна продолжать играть во время паузы (для удобной настройки громкости).
	music_stream_player.process_mode = Node.PROCESS_MODE_ALWAYS
	# Автолоад обрабатывается и в паузе — иначе твин приглушения замирал бы.
	process_mode = Node.PROCESS_MODE_ALWAYS
	if autoplayer_music != null:
		music_stream_player.stream = autoplayer_music
		music_stream_player.play()


func play(music: Music) -> void:
	if music_stream_player.is_node_ready():
		music_stream_player.stream = MUSIC_MAP[music]
		music_stream_player.play()
	else:
		autoplayer_music = MUSIC_MAP[music]


## Включает/выключает приглушение музыки (меню паузы). Приглушение плавное (duck_fade_duration).
func set_ducked(active: bool) -> void:
	if is_ducked == active:
		is_ducked = active
		return
	is_ducked = active
	if _duck_tween:
		_duck_tween.kill()
	if active:
		# Запоминаем базовую громкость, чтобы потом точно восстановить
		_restore_volume_db = AudioServer.get_bus_volume_db(MUSIC_BUS_IDX)
		_duck_tween = create_tween()
		_duck_tween.tween_method(_apply_duck_volume, _duck_volume, 1.0, duck_fade_duration)
	else:
		_duck_tween = create_tween()
		_duck_tween.tween_method(_apply_duck_volume, _duck_volume, 0.0, duck_fade_duration)


## Включает/выключает замедленное воспроизведение музыки (сцена смерти игрока).
## Восстановление (active=false) возвращает pitch_scale к 1.0.
func set_slowmo(active: bool) -> void:
	if _slowmo_tween:
		_slowmo_tween.kill()
	_slowmo_tween = create_tween()
	_slowmo_tween.set_ignore_time_scale(true)
	_slowmo_tween.tween_property(
		music_stream_player, "pitch_scale", slowmo_pitch if active else 1.0, slowmo_fade_duration)


## Вызывается из OptionsManager, когда пользователь крутит слайдер громкости музыки
## прямо во время паузы — чтобы приглушение применялось относительно нового уровня.
func on_options_music_volume_changed() -> void:
	if is_ducked:
		_restore_volume_db = AudioServer.get_bus_volume_db(MUSIC_BUS_IDX)
		_apply_duck_volume(_duck_volume)


func _apply_duck_volume(value: float) -> void:
	_duck_volume = value
	AudioServer.set_bus_volume_db(MUSIC_BUS_IDX, _restore_volume_db + value * duck_offset_db)