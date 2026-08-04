extends Node2D

@onready var debug_nodes: Node2D = $"."
@onready var label: Label = $Label
@onready var player: Player = $".."


func _ready() -> void:
	label.text = str("Status: ", player.state)


func _process(_delta: float) -> void:
	label.text = str("Status: ", player.state)
	
