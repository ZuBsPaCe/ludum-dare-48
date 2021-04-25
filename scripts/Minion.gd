extends KinematicBody2D

class_name Minion

const TileType = preload("res://scripts/TileType.gd").TileType

enum MinionTask {
	IDLE,
	ROAMING,

	RALLYING,

	GO_DIGGING,
	DIGGING,

	MOVE,

	ATTACKING,
	FIGHTING
}

onready var _animation_minion := $Sprites/AnimationMinion
onready var _animation_pickaxe := $Sprites/AnimationPickaxe

var speed := 32.0

var tile : Tile
var coord := Coord.new()
var check_coord := Coord.new()

var task = MinionTask.IDLE
var task_cooldown := Cooldown.new()
var next_task = null

var striking := false
var strike_hit := false
var strike_cooldown := Cooldown.new(1.0)
var strike_hit_cooldown := Cooldown.new(0.25)

var target_pos := Vector2()
var target_vec := Vector2()

var path : PoolVector2Array
var path_index := 0

var dig_tile : Tile

var faction := 0


func _ready() -> void:
	coord.set_vector(position)
	tile = State.map.get_tile(coord.x, coord.y)
	tile.minions.append(self)

	_set_next_task(MinionTask.IDLE)

func _process(delta: float) -> void:
	task_cooldown.step(delta)
	strike_cooldown.step(delta)
	strike_hit_cooldown.step(delta)

func _physics_process(delta: float) -> void:
	check_coord.set_vector(position)
	if check_coord.x != coord.x || check_coord.y != coord.y:
		tile.minions.erase(self)
		coord.set_vector(position)
		tile = State.map.get_tile(coord.x, coord.y)
		tile.minions.append(self)

	if striking:
		if !strike_hit:
			if strike_hit_cooldown.running:
				return
			strike_hit = true
			if task == MinionTask.DIGGING:
				dig_tile.health -= 1
				if dig_tile.health == 0:
					dig_tile.dig_highlight.queue_free()
					dig_tile.dig_highlight = null
					State.map.set_tile_type(dig_tile.x, dig_tile.y, TileType.GROUND)
					State.tilemap32.set_cell(dig_tile.x, dig_tile.y, 0)
					State.map.dig_tiles.erase(dig_tile)
					var coord := Coord.new(dig_tile.x, dig_tile.y)
					move_near(coord.to_random_pos())
					dig_tile = null
				elif dig_tile.health < 0:
					var coord := Coord.new(dig_tile.x, dig_tile.y)
					move_near(coord.to_random_pos())
					dig_tile = null

		if strike_cooldown.running:
			return
		striking = false

	if next_task != null:
		match next_task:
			MinionTask.IDLE:
				task = MinionTask.IDLE
				task_cooldown.restart(randf() * 4.0)
				var rand := randi() % 3
				if rand == 0:
					_animation_minion.play("Idle")
				elif rand == 1:
					_animation_minion.play("IdleLeft")
				else:
					_animation_minion.play("IdleRight")

				if target_vec.x >= 0.0:
					_animation_pickaxe.play("IdleRight")
				else:
					_animation_pickaxe.play("IdleLeft")

			MinionTask.ROAMING:
				_set_target(Helper.get_walkable_pos(coord))
				task = MinionTask.ROAMING

			MinionTask.GO_DIGGING:
				_start_path()
				task = MinionTask.GO_DIGGING

			MinionTask.DIGGING:
				task = MinionTask.DIGGING

			MinionTask.MOVE:
				_start_path()
				task = MinionTask.MOVE
		next_task = null

	match task:
		MinionTask.IDLE:
			if task_cooldown.done:
				_set_next_task(MinionTask.ROAMING)

		MinionTask.ROAMING:
			_move()

			if task_cooldown.done:
				_set_next_task(MinionTask.IDLE)

		MinionTask.GO_DIGGING:
			_move()

			if task_cooldown.done:
				if !_advance_path():
					_set_next_task(MinionTask.DIGGING)

		MinionTask.DIGGING:
			if dig_tile:
				_strike()
			else:
				_set_next_task(MinionTask.IDLE)

		MinionTask.MOVE:
			_move()

			if task_cooldown.done:
				_set_next_task(MinionTask.IDLE)

func _set_next_task(new_task):
	next_task = new_task

func _move() -> void:
	move_and_slide(target_vec)
	if target_vec.x >= 0.0:
		_animation_minion.play("WalkRight")
		_animation_pickaxe.play("WalkRight")
	else:
		_animation_minion.play("WalkLeft")
		_animation_pickaxe.play("WalkLeft")

func _strike() -> void:
	strike_cooldown.restart()
	strike_hit_cooldown.restart()

	striking = true
	strike_hit = false

	if target_vec.x >= 0.0:
		_animation_minion.play("StrikeRight")
		_animation_pickaxe.play("StrikeRight")
	else:
		_animation_minion.play("StrikeLeft")
		_animation_pickaxe.play("StrikeLeft")

func _set_target(new_target_pos : Vector2) -> void:
	target_pos = new_target_pos
	var diff_vec := target_pos - position

	target_vec = diff_vec.normalized() * speed
	var time := diff_vec.length() / speed

	task_cooldown.restart(time)

func _start_path() -> void:
	if path.size() == 0:
		task_cooldown.set_done()
	else:
		path_index = -1
		_advance_path()

func _advance_path() -> bool:
	path_index += 1
	if path_index >= path.size():
		return false

	var pos : Vector2 = path[path_index]
	var remainder_x = fmod(abs(pos.x), 32.0)
	var remainder_y = fmod(abs(pos.y), 32.0)

	if remainder_x < 0.1:
		pos.x = floor(pos.x) + 0.1
	elif remainder_x > 0.9:
		pos.x = floor(pos.x) + 0.9

	if remainder_y < 0.1:
		pos.y = floor(pos.y) + 0.1
	elif remainder_y > 0.9:
		pos.y = floor(pos.y) + 0.9

	_set_target(pos)
	return true


func set_faction(faction : int) -> void:
	self.faction = faction
	if faction == 1:
		modulate = Color.crimson


func can_start_digging() -> bool:
	return (
		task != MinionTask.GO_DIGGING &&
		task != MinionTask.DIGGING &&
		task != MinionTask.ATTACKING &&
		task != MinionTask.FIGHTING)

func dig(path : PoolVector2Array, dig_tile : Tile):
	self.path = path
	self.dig_tile = dig_tile
	_set_next_task(MinionTask.GO_DIGGING)

func move_near(pos : Vector2):
	path = PoolVector2Array()
	path.append(pos)
	_set_next_task(MinionTask.MOVE)


