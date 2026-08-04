extends Node2D

@onready var label: Label = $Label
@onready var panel: Panel = $Label/Panel

var velocity := Vector2.ZERO

@export var jump_force := -320.0
@export var horizontal_force := 80.0
@export var gravity := 900.0

var duration := 1.2
var elapsed_time := 0.0

var random_word = ["БАМ!", "ХРЯСЬ!"]
var random_panel_color = ["#fb6100", "#04a0ff"]

var text_to_display: String = ""

func _ready():
	label.text = text_to_display
	rotation_degrees = randf_range(-15.0, 15.0)
	# стартовый импульс
	velocity.y = jump_force
	# немного разлёта по X
	velocity.x = randf_range(-horizontal_force, horizontal_force)

func _process(delta):
	# гравитация
	velocity.y += gravity * delta
	# движение
	position += velocity * delta
	# плавное затухание
	elapsed_time += delta
	var alpha = 1.0 - (elapsed_time / duration)
	label.modulate.a = alpha
	# лёгкое вращение пока летит
	rotation += velocity.x * 0.0005

	if elapsed_time >= duration:
		queue_free()
