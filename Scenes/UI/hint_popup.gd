extends Control

@export var hint_scene: PackedScene = preload("res://Scenes/UI/hint_popup.tscn")

@onready var label: Label = %HintLabel
@onready var character_picture: TextureRect = %CharacterPicture
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func show_hint(new_text: String, display_time: float = 3.0) -> void:
	print("ПОДСКАЗКА ЗАПУЩЕНА:", new_text)
	
	# Ждём, пока узел полностью загрузится в дерево сцены и сработают все @onready переменные
	if not is_node_ready():
		await ready
		
	# Теперь label гарантированно НЕ null — безопасно записываем текст
	label.text = new_text

	# Запускаем анимацию появления (укажите точное имя вашей анимации появления)
	animation_player.play("appear") 
	
	# Ждём, пока игрок читает текст
	await get_tree().create_timer(display_time).timeout
	
	# Запускаем анимацию исчезновения (укажите точное имя вашей анимации исчезновения)
	animation_player.play("disappear")
	await animation_player.animation_finished

	# Безопасно удаляем подсказку из памяти
	queue_free()
