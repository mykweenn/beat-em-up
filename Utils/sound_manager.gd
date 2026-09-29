class_name SoundManager
extends Node

@onready var sounds : Array[AudioStreamPlayer] = [$SFXClick, $SFXFood, $SFXGogogo, $SFXGrunt, 
$SFXGunshot, $SFXHit, $SFXHit2, $SFXHit3, 
$SFXKnife, $SFXSwoosh, $SFXParry, $SFXChargeAttack, 
$SFXCollisionHit, $SFXFinisher, $SFXPause, $SFXUnpause, $SFXStaticMenu, $SFXClick2]

@onready var sfx_static_menu: AudioStreamPlayer = $SFXStaticMenu

@export_group("Death Slowmo")
## Во сколько раз замедлять воспроизведение звуков при смерти игрока.
@export var slowmo_pitch := 0.7
## Плавность перехода к замедленному воспроизведению (сек).
@export var slowmo_fade_duration := 0.4

var _slowmo_tween : Tween = null

enum Sound {CLICK, FOOD, GOGOGO, GRUNT, GUNSHOT, HIT1, 
HIT2, HIT3, KNIFE, SWOOSH, PARRY, CHARGE_ATTACK, 
COLLISION_HIT, FINISHER, PAUSE, UNPAUSE, STATIC_MENU, CLICK_2}


func _ready() -> void:
	sfx_static_menu.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	# Шипение меню продолжает звучать и в паузе
	sfx_static_menu.process_mode = Node.PROCESS_MODE_ALWAYS


func play(sfx: Sound, tweak_pitch: bool = false) -> void:
	var added_pitch := 0.0
	if tweak_pitch:
		added_pitch = randf_range(-0.3, 0.3)
	sounds[sfx as int].pitch_scale = 1 + added_pitch
	sounds[sfx as int].play()


func play_static_menu() -> void:
	sfx_static_menu.play()


## Включает/выключает замедленное воспроизведение всех звуков (сцена смерти игрока).
## Восстановление (active=false) возвращает pitch_scale к 1.0.
func set_slowmo(active: bool) -> void:
	if _slowmo_tween:
		_slowmo_tween.kill()
	_slowmo_tween = create_tween()
	_slowmo_tween.set_ignore_time_scale(true)
	var target := slowmo_pitch if active else 1.0
	for sfx in sounds:
		_slowmo_tween.parallel().tween_property(sfx, "pitch_scale", target, slowmo_fade_duration)


func stop_static_menu() -> void:
	sfx_static_menu.stop()
