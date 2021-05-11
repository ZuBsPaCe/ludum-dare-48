extends RigidBody2D

onready var sprite := $Sprite
var lifetime := Cooldown.new()
var init_torque := true

func _ready() -> void:
	sprite.frame = randi() % 4
	lifetime.restart(30.0 + randf() * 30.0)

	apply_central_impulse(
		Vector2(
			randf() * 40.0 - 5,
			randf() * 40.0 - 5))

func _process(delta: float) -> void:
	if init_torque:
		init_torque = false

		# Does not work in ready or before ready...
		# https://bit.ly/3hl0EaO
		apply_torque_impulse(
			(randf() * 8.0 - 4.0) * 2.0 * PI)


	lifetime.step(delta)

	if lifetime.done:
		queue_free()
	elif lifetime.timer < 15:
		sprite.modulate.a = lifetime.timer / 15.0


