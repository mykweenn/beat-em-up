extends Stage

@onready var lizzard_background_runner: AnimatedSprite2D = $Fixtures/LizzardBackgroundRunner

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	lizzard_background_runner.position.x += 10
