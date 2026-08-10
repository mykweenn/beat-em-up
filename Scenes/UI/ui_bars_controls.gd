extends Control


@onready var block_bar: ProgressBar = $BlockBar
@onready var hpbar: ProgressBar = $HPBar

func _ready():
	block_bar.max_value = get_parent().max_block_health
	hpbar.max_value = get_parent().max_health


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	block_bar.value = get_parent().block_health
	hpbar.value = get_parent().current_health