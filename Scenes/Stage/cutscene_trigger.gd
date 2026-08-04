extends Node2D

@onready var player_detection_area: Area2D = $PlayerDetectionArea

@export var animation_player: AnimationPlayer
@export var animation_name := "intro"
@export var one_shot := true
var if_activated := false


func _ready() -> void:
	player_detection_area.body_entered.connect(on_player_enter.bind())
	print("are you working?")


func _process(_delta: float) -> void:
	pass
	# if if_activated:
	# 	print("if activated = true")


func on_player_enter(_player: Player) -> void:
	if not if_activated:
		if_activated = true
		GameManager.cutscene_started.emit()
		animation_player.play(animation_name)
		print("working")