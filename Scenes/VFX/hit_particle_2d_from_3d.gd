extends Node2D

@onready var hit_particle_3d: GPUParticles3D = $HitParticleConverter3DTo2D/SubViewport/HitParticle3D

func _ready() -> void:
	hit_particle_3d.emitting = true


func play_hit_particles() -> void:
	hit_particle_3d.finished.connect(_on_particles_finished, CONNECT_ONE_SHOT)
	hit_particle_3d.emitting = true

func _on_particles_finished() -> void:
	queue_free()


func _on_hit_particle_3d_finished() -> void:
	queue_free()
