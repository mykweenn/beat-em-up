class_name SoundManager
extends Node

@onready var sounds : Array[AudioStreamPlayer] = [$SFXClick, $SFXFood, $SFXGogogo, $SFXGrunt, 
$SFXGunshot, $SFXHit, $SFXHit2, $SFXHit3, 
$SFXKnife, $SFXSwoosh, $SFXParry, $SFXChargeAttack, 
$SFXCollisionHit, $SFXFinisher, $SFXPause, $SFXUnpause, $SFXStaticMenu, $SFXClick2]

@onready var sfx_static_menu: AudioStreamPlayer = $SFXStaticMenu

enum Sound {CLICK, FOOD, GOGOGO, GRUNT, GUNSHOT, HIT1, 
HIT2, HIT3, KNIFE, SWOOSH, PARRY, CHARGE_ATTACK, 
COLLISION_HIT, FINISHER, PAUSE, UNPAUSE, STATIC_MENU, CLICK_2}


func _ready() -> void:
	sfx_static_menu.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD


func play(sfx: Sound, tweak_pitch: bool = false) -> void:
	var added_pitch := 0.0
	if tweak_pitch:
		added_pitch = randf_range(-0.3, 0.3)
	sounds[sfx as int].pitch_scale = 1 + added_pitch
	sounds[sfx as int].play()


func play_static_menu() -> void:
	sfx_static_menu.play()


func stop_static_menu() -> void:
	sfx_static_menu.stop()
