extends Control


@onready var block_bar: ProgressBar = $BlockBar
@onready var hpbar: ProgressBar = $HPBar
@onready var character: Character = get_parent()

var _last_block_health := -1.0
var _last_health := -1

func _ready():
	block_bar.max_value = character.max_block_health
	hpbar.max_value = character.max_health


# Присваиваем значения только когда они изменились,
# чтобы не гонять обновление ProgressBar впустую каждый кадр.
func _process(_delta):
	if character.block_health != _last_block_health:
		_last_block_health = character.block_health
		block_bar.value = _last_block_health
	if character.current_health != _last_health:
		_last_health = character.current_health
		hpbar.value = _last_health
