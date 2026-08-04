class_name HealthBar
extends Control


@onready var white_border: ColorRect = $WhiteBorder
@onready var content_background: ColorRect = $ContentBackground
@onready var health_gauge: TextureRect = $HealthGauge
@onready var hp_progress_bar: ProgressBar = $HPProgressBar
@onready var timer: Timer = $Timer

@export var is_inverted : bool


func refresh(current_health: int, max_health: int) -> void:
	var rev = -1 if is_inverted else 1
	
	white_border.scale.x = (max_health + 2) * rev
	content_background.scale.x = max_health * rev
	health_gauge.scale.x = current_health * rev
	
	hp_progress_bar.value = current_health
	hp_progress_bar.scale.x = rev
	hp_progress_bar.max_value = max_health
