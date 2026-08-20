extends Node2D

@onready var player_detection_area: Area2D = $PlayerDetectionArea

@export var animation_player: AnimationPlayer
@export var animation_name: String = "intro"
@export var one_shot: bool = true
var if_activated: bool = false

# Подгружаем сцену диалога, чтобы создать её
const DIALOGUE_BOX_SCENE = preload("res://Scenes/UI/dialog_window.tscn")

func _ready() -> void:
	player_detection_area.body_entered.connect(on_player_enter.bind())
	print("are you working?")

func on_player_enter(_player: Player) -> void:
	if not if_activated:
		if_activated = true
		
		# 1. Запускаем общую логику кат-сцены и анимацию камеры/окружения
		GameManager.cutscene_started.emit()
		animation_player.play(animation_name)
		print("working")
		
		# 2. Находим узлы диалога и маркера ПРЯМО внутри вошедшего игрока
		if _player.has_node("DialogWindow") and _player.has_node("DialogPoint"):
			var dialog_window = _player.get_node("DialogWindow")
			var marker = _player.get_node("DialogPoint")
			
			# 3. Передаем текст напрямую в окно диалога игрока
			dialog_window.start_dialogue(["Я тестирую диалоговое окно я тестирую диалоговое окно."], marker)

		else:
			print("Ошибка: У игрока не найден узел DialogWindow или DialogPoint!")



# Новая функция для создания окна диалога
func show_cutscene_text(player_node: Player, text_phrase: String):
	if is_instance_valid(player_node):
		# Создаем экземпляр окна диалога
		var dialogue = DIALOGUE_BOX_SCENE.instantiate()
		
		# Добавляем окно на текущий уровень (в самый корень сцены, чтобы оно не наследовало поворот игрока)
		get_parent().add_child(dialogue)
		
		# Берем маркер у вошедшего игрока
		var player_marker = player_node.get_node("DialogPoint")
		
		# Запускаем диалог
		dialogue.start_dialogue([text_phrase], player_marker)
