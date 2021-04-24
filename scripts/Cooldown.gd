extends Reference

class_name Cooldown

var total : float
var timer : float
var running : bool

func _init(total = 0.0) -> void:
	self.total = total
	self.timer = 0
	self.running = false

func step(delta: float) -> void:
	if !running:
		return

	timer -= delta
	if timer <= 0:
		timer = 0
		running = false

func start() -> void:
	running = true

func restart(new_total : float = -1) -> void:
	if new_total >= 0:
		total = new_total

	running = true
	timer = total

func stop() -> void:
	running = false
