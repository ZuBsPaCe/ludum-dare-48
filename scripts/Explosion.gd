extends Node2D

onready var _cloud_particles := $CloudParticles

func _ready() -> void:
	$Sprite.rotation = randf() * 2 * PI
	_cloud_particles.emitting = true

func _process(delta: float) -> void:
	if !_cloud_particles.emitting:
		queue_free()
