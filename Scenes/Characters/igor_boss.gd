class_name IgorBoss
extends Character

const GROUND_FRICTION := 50

@export var distance_from_player : int
@export var duration_between_attacks : int
@export var duration_vulnurable : int
@export var player : Player

@export var hint_scene: PackedScene = preload("res://Scenes/UI/hint_popup.tscn")


var assigned_door_index := -1
var knockback_force := Vector2.ZERO
var time_last_attack := Time.get_ticks_msec()
var time_start_vulnurable := Time.get_ticks_msec()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	knockback_force = knockback_force.move_toward(Vector2.ZERO, delta * GROUND_FRICTION)


func get_target_destination() -> Vector2:
	var target := Vector2.ZERO
	if position.x < player.position.x:
		target = player.position + Vector2.LEFT * distance_from_player
	else:
		target = player.position + Vector2.RIGHT * distance_from_player
	return target


func is_player_within_range() -> bool:
	var target := get_target_destination()
	return (target - position).length() < 10


func handle_grounded() -> void:
	if state == State.GROUNDED and current_health > 0:
		state = State.RECOVER
		time_start_vulnurable = Time.get_ticks_msec()
	elif state == State.RECOVER and Time.get_ticks_msec() - time_start_vulnurable > duration_vulnurable:
		state = State.IDLE
		time_last_attack = Time.get_ticks_msec()


func handle_input() -> void: 
	if player != null and can_move():
		if can_attack() and projectile_aim.is_colliding():
			state = State.FLY
			velocity = heading * flight_speed
		else:
			if is_player_within_range():
				velocity = Vector2.ZERO
				state = State.IDLE
			else:
				var target_destination := get_target_destination()
				var direction := (target_destination - position).normalized()
				velocity = (direction + knockback_force) * speed
				state = State.WALK


func on_action_complete():
	if state == State.HURT:
		state = State.RECOVER
		return 
	super.on_action_complete()


func set_heading() -> void:
	if player == null or not can_move():
		return 
	heading = Vector2.LEFT if position.x > player.position.x else Vector2.RIGHT


func can_get_hurt() -> bool:
	return true


func can_attack() -> bool:
	if Time.get_ticks_msec() - time_last_attack < duration_between_attacks:
		return false
	return super.can_attack()


func is_vulnuruble() -> bool:
	return state == State.RECOVER


func on_receive_damage(amount: int, direction: Vector2, _hit_type: DamageReceiver.HitType, attacker: Character = null) -> void:
	if !is_vulnuruble():
		knockback_force = direction * knockback_intensity
		var hint = hint_scene.instantiate()
		get_parent().add_child(hint)
		hint.show_hint("Бей его сзади!")
		# HitstopManager.freeze(0.1, 0.1)
		return
	ComboManager.register_hit.emit()
	current_health = clamp(current_health - amount, 0, max_health)
	if current_health <= 0:
		EntityManager.spawn_spark.emit(position)
		state = State.FALL
		height_speed = knockback_intensity
		velocity = direction * knockdown_intensity
		SoundPlayer.play(SoundManager.Sound.GRUNT)
		HitstopManager.freeze(0.3, 0.3)
		EntityManager.death_enemy.emit(self)
		HitstopManager.boss_death_freeze(global_position, 2.0)
	else:
		EntityManager.spawn_3d_spark.emit(position)
		velocity = Vector2.ZERO
		state = State.HURT
		SoundPlayer.play(SoundManager.Sound.HIT2)
		HitstopManager.freeze(0.05, 0.05)


func on_emit_damage(receiver: DamageReceiver):
	receiver.damage_received.emit(damage, heading, DamageReceiver.HitType.LAUNCH)
	time_last_attack = Time.get_ticks_msec()
	state = State.IDLE


func is_attacking() -> bool:
	return state == State.FLY
