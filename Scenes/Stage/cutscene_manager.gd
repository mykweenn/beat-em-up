extends Node2D

func say_phrase(speaker_group: String, text: String):
	# 1. Ищем персонажа на сцене по его группе (например, "Player" или "Enemy")
	var speaker = get_tree().get_first_node_in_group(speaker_group)
	
	if speaker:
		# 2. Проверяем, есть ли у него точка над головой и само окно
		if speaker.has_node("DialogPoint") and speaker.has_node("DialogWindow"):
			var marker = speaker.get_node("DialogPoint")
			var dialog_window = speaker.get_node("DialogWindow")
			
			# 3. Делаем окно видимым и запускаем в нем текст, передавая маркер
			dialog_window.show()
			dialog_window.start_dialogue([text], marker)
		else:
			print("Ошибка: У узла ", speaker.name, " нет DialogPoint или DialogWindow!")
	else:
		print("Ошибка: Персонаж из группы ", speaker_group, " не найден на уровне!")
