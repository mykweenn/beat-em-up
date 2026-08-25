class_name MusicManager
extends Node

enum Music {INTRO, MENU, STAGE1, STAGE2, STAGE1_ALT, ARENA, STREETS}

@onready var music_stream_player: AudioStreamPlayer = $MusicStreamPlayer

var autoplayer_music : AudioStream = null

const MUSIC_MAP : Dictionary = {
	Music.INTRO: preload("res://Assets/Music/03.mp3"),
	Music.MENU: preload("res://Assets/Music/menu.mp3"),
	Music.STAGE1: preload("res://Assets/Music/02 Dust (Carpenter Brut Remix).mp3"),
	Music.STAGE2: preload("res://Assets/Music/Kaito_Shoma_Claymore_Phonk_Metal_Группа_Ls_Beats.mp3"),
	Music.STAGE1_ALT: preload("res://Assets/Music/03.mp3"),
	Music.ARENA: preload("res://Assets/Music/03.mp3"),
	Music.STREETS: preload("res://Assets/Music/Mother Russia Bleeds OST (Fixions) - Secret Blades.mp3"),
}


func _ready() -> void:
	if autoplayer_music != null:
		music_stream_player.stream = autoplayer_music
		music_stream_player.play()


func play(music: Music) -> void:
	if music_stream_player.is_node_ready():
		music_stream_player.stream = MUSIC_MAP[music]
		music_stream_player.play()
	else:
		autoplayer_music = MUSIC_MAP[music]
