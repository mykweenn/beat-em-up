extends Node

signal cutscene_started
signal cutscene_finished


func play_cutscene(cutscene_name: String):
	GameManager.set_state(GameManager.GameState.CUTSCENE)
	
	cutscene_started.emit()
	
	# cutscene logic
	
	cutscene_finished.emit()
	
	GameManager.set_state(GameManager.GameState.GAMEPLAY)
