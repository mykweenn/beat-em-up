class_name ComboIndicator
extends Label

signal combo_reset(points: int)

@export var duration_combo_timeout : int
@onready var combo_label: ComboIndicator = $"."

var current_combo := 0
var time_since_register_hit := Time.get_ticks_msec()


func _init() -> void:
	ComboManager.register_hit.connect(on_register_hit.bind())
	
func _ready() -> void:
	refresh()


var original_scale := Vector2.ONE

func play_combo_feedback() -> void:
	#var intensity = clamp(current_combo * 0.05, 1.0, 2.0)
	combo_label.scale = Vector2(1.4, 1.4)
	#combo_label.scale = Vector2.ONE * intensity
	var tween := create_tween()
	tween.set_parallel()

	tween.tween_property(combo_label, "scale", original_scale, 0.12)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)

	tween.tween_property(
		combo_label,
		"position:x",
		combo_label.position.x + randf_range(-6, 6),
		0.05
	)

	tween.tween_property(
		combo_label,
		"position:x",
		combo_label.position.x,
		0.05
	).set_delay(0.05)


func on_register_hit() -> void:
	current_combo += 1
	play_combo_feedback()
	time_since_register_hit = Time.get_ticks_msec()
	refresh()


func _process(_delta: float) -> void:
	if current_combo > 0 and (Time.get_ticks_msec() - time_since_register_hit > duration_combo_timeout):
		combo_reset.emit(current_combo)
		current_combo = 0
		refresh()


func refresh() -> void:
	text = "x" + str(current_combo)
	visible = current_combo > 0
