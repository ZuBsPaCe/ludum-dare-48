extends KinematicBody2D

class_name Minion

enum MinionTask {
	IDLE,
	ROAMING
}

var speed := 16.0

var tile : Tile
var coord := Coord.new()
var check_coord := Coord.new()

var task = MinionTask.IDLE
var task_cooldown := Cooldown.new()

var target_pos := Vector2()
var target_vec := Vector2()

func _ready() -> void:
	coord.set_vector(position)
	tile = State.map.get_tile(coord.x, coord.y)
	tile.minions.append(self)

	set_task(MinionTask.IDLE)

func _physics_process(delta: float) -> void:
	task_cooldown.step(delta)

	check_coord.set_vector(position)
	if check_coord.x != coord.x || check_coord.y != coord.y:
		tile.minions.erase(self)
		coord.set_vector(position)
		tile = State.map.get_tile(coord.x, coord.y)
		tile.minions.append(self)

	match task:
		MinionTask.IDLE:
			if !task_cooldown.running:
				set_task(MinionTask.ROAMING)

		MinionTask.ROAMING:
			move_and_slide(target_vec)

			if !task_cooldown.running:
				set_task(MinionTask.IDLE)

func set_task(new_task):
	match new_task:
		MinionTask.IDLE:
			task = MinionTask.IDLE
			task_cooldown.restart(randf() * 4.0)

		MinionTask.ROAMING:
			target_pos = Helper.get_walkable_pos(coord)
			target_vec = (target_pos - position).normalized() * speed

			var time := (target_pos - position).length() / speed

			task = MinionTask.ROAMING
			task_cooldown.restart(time)

