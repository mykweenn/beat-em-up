extends CanvasLayer

@onready var label: RichTextLabel = $MarginContainer/RichTextLabel

var _player: Character = null


func _ready() -> void:
	visible = false
	layer = 3


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("toggle_debug"):
		visible = !visible
	if not visible:
		return
	_update_debug_text()


func _update_debug_text() -> void:
	_player = _find_player()
	var text := ""

	if _player != null:
		text += _format_character(_player, "PLAYER")
		text += "\n"

	var enemies := _find_enemies()
	if enemies.is_empty():
		text += "[color=gray]No enemies[/color]\n"
	else:
		for i in range(enemies.size()):
			if i > 0:
				text += "\n"
			text += _format_character(enemies[i], "ENEMY #%d" % (i + 1))

	label.text = text


func _format_character(c: Character, header: String) -> String:
	var color := "green" if c == _player else "red"
	var type_name: String = Character.Type.keys()[c.type]
	var state_name: String = Character.State.keys()[c.state]
	var h := "%d/%d" % [c.current_health, c.max_health]
	var pos := "(%d, %d)" % [int(c.global_position.x), int(c.global_position.y)]
	var vel := "(%d, %d)" % [int(c.velocity.x), int(c.velocity.y)]
	var blk := "%d/%d" % [int(c.block_health), int(c.max_block_health)]

	var s := "[color=%s]%s[/color] [color=gray](%s)[/color]\n" % [color, header, type_name]
	s += "  State: [b]%s[/b] | HP: %s\n" % [state_name, h]
	s += "  Pos: %s | Vel: %s | H: %.0f\n" % [pos, vel, c.height]
	s += "  Block: %s | Broken: %s\n" % [blk, c.block_broken]
	s += "  Heading: %s | Knife: %s | Gun: %s" % [
		"R" if c.heading.x > 0 else "L",
		c.has_knife, c.has_gun
	]

	if c.has_gun:
		s += " | Ammo: %d" % c.ammo_left

	s += "\n"
	s += "  Combo: %d | Charge: %.2f | Stunlock: %d\n" % [
		c.attack_combo_index, c.charge_timer, c.combo_hurt_count
	]

	if c == _player:
		s += "  Mounting: %s | Anim: %s" % [c.is_mounting, c.animation_player.current_animation]
		if c.is_mounting and c.finisher_target != null and is_instance_valid(c.finisher_target):
			s += " | Target alive: %s" % (c.finisher_target.current_health > 0)
		s += "\n"
	elif c is BasicEnemy:
		s += "  AI: block_timer=%.2f | door=%d" % [c.enemy_block_timer, c.assigned_door_index]
		if c.player_slot != null:
			s += " | slot=occupied"
		s += "\n"
		s += "  Player down: %s | Give space: %s" % [c._is_player_down(), c._should_give_player_space()]
		s += "\n"

	return s


func _find_player() -> Character:
	var nodes := get_tree().get_nodes_in_group("player")
	for n in nodes:
		if n is Character:
			return n
	return null


func _find_enemies() -> Array[Character]:
	var result: Array[Character] = []
	for n in get_tree().get_nodes_in_group("enemy"):
		if n is Character:
			result.append(n)
	return result
