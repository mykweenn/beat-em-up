extends AnimatedSprite2D

@export var speed := 250.0

@export var min_wait := 3.0
@export var max_wait := 8.0

@export var left_spawn_x := -300
@export var right_despawn_x := 2500

@export var min_y := 420
@export var max_y := 580

var active := false

var animations := [
	"run_lizzard",
	"run_knight"
]

func _ready():
	randomize()

	visible = false

	start_random_timer()

func start_random_timer():
	var wait_time = randf_range(min_wait, max_wait)

	await get_tree().create_timer(wait_time).timeout

	spawn_runner()

func spawn_runner():
	active = true

	visible = true

	global_position = Vector2(
		left_spawn_x,
		randf_range(min_y, max_y)
	)

	# случайная анимация
	var random_anim = animations.pick_random()

	play(random_anim)

func _process(delta):
	if !active:
		return

	position.x += speed * delta

	if position.x > right_despawn_x:
		despawn_runner()

func despawn_runner():
	active = false

	stop()

	visible = false

	start_random_timer()
