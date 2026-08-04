extends Node


func display_text(text_value: String, position: Vector2, is_critical: bool = false) -> void:
	var text = Label.new()
	text.global_position = position
	text.text = str(text_value)
	text.z_index = 5
	text.label_settings = LabelSettings.new()
	
	var color = "#FFF"
	if is_critical:
		color = "#B22"
	if text_value == "БАМ!":
		color = "#FFF8"
	elif text_value == "ХРЯСЬ!":
		color = "#c8c000"
	
	text.label_settings.font_color = color
	text.label_settings.font_size = 16
	text.label_settings.outline_color = "#000"
	text.label_settings.outline_size = 1
	
	call_deferred("add_child", text)
	await get_tree().create_timer(0.1).timeout
	queue_free()
