extends KinematicBody2D

var dir : Vector2
var faction : int

const speed := 64.0

func _ready() -> void:
	pass

func setup(dir : Vector2, faction : int):
	self.dir = dir
	self.faction = faction

	if faction == 0:
		collision_mask = 1 << 2 | 1
	else:
		collision_mask = 1 << 1 | 1

func _physics_process(delta: float) -> void:
	rotation -= delta * 2 * PI * 0.75
	var collision := move_and_collide(speed * delta * dir)
	if collision != null:
		if collision.collider.is_in_group("Minion"):
			collision.collider.hurt()

		queue_free()

