extends Reference

class_name Cooldown

var total : float
var timer : float
var running : bool
var done : bool
var started : bool

func _init(total = 0.0) -> void:
	self.total = total
	self.timer = total
	self.running = false
	self.done = false
	self.started = false

func step(delta: float) -> void:
	if !running:
		return

	timer -= delta
	if timer <= 0:
		timer = 0
		running = false
		done = true

#func start() -> void:
#	running = true
#	done = false

func reset() -> void:
	timer = total
	running = false
	done = false
	started = false

func restart(new_total : float = -1) -> void:
	if new_total >= 0:
		total = new_total

	timer = total
	running = true
	done = false
	started = true

func set_done() -> void:
	running = false
	done = true
