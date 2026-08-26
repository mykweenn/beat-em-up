extends Node2D

@onready var spray: CPUParticles2D = $Spray
@onready var splash: CPUParticles2D = $Splash
@onready var puddle: Sprite2D = $Puddle

const BLOOD_LIFETIME := 0.5
const SPLASH_DELAY := 0.05
const PUDDLE_WAIT := 10.0
const PUDDLE_FADE := 2.0

var _direction := Vector2.RIGHT
var _hit_type := DamageReceiver.HitType.NORMAL

func setup(dir: Vector2, hit_type: DamageReceiver.HitType) -> void:
	_direction = dir
	_hit_type = hit_type

func _ready() -> void:
	var side: float = -sign(_direction.x) if _direction.x != 0 else 1.0
	spray.direction = Vector2(side, -0.5)
	splash.direction = Vector2(side, -1.0)
	if _hit_type == DamageReceiver.HitType.POWER or _hit_type == DamageReceiver.HitType.LAUNCH:
		spray.amount = 40
		splash.amount = 25
		puddle.scale *= 1.5
	puddle.rotation = randf_range(0, TAU)
	puddle.position += Vector2(randf_range(-20.0, 20.0), randf_range(-10.0, 10.0))
	spray.emitting = true
	await get_tree().create_timer(SPLASH_DELAY).timeout
	splash.emitting = true
	await get_tree().create_timer(BLOOD_LIFETIME).timeout
	spray.queue_free()
	splash.queue_free()
	await get_tree().create_timer(PUDDLE_WAIT).timeout
	var tween = create_tween()
	tween.tween_property(puddle, "modulate:a", 0.0, PUDDLE_FADE)
	await tween.finished
	queue_free()
