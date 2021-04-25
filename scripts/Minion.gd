extends KinematicBody2D

class_name Minion

const TileType = preload("res://scripts/TileType.gd").TileType

# Collider radius is 4 -> double it + margin
const attack_start_distance_sq := 10 * 10
const attack_hit_distance_sq := 12 * 12

enum MinionTask {
	IDLE,
	ROAM,

	RALLY,

	GO_DIG,
	DIG,

	MOVE,

	ATTACK,
	FIGHT
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
var attack_cooldown := Cooldown.new(0.2)
var victim_lost_cooldown := Cooldown.new(8.0)

var target_pos := Vector2()
var target_vec := Vector2()

var path : PoolVector2Array
var path_index := 0

var dig_tile : Tile

var faction := 0

var health := 1

var _path_variation_x := 0.0
var _path_variation_y := 0.0

var _rally_immune := 0.0

var _victim : Minion
var _last_victim_pos := Vector2.ZERO


func _ready() -> void:
	_set_next_task(MinionTask.IDLE)

	_path_variation_x += randf() * 28.0 - 14.0
	_path_variation_y += randf() * 28.0 - 14.0


func setup(faction : int) -> void:
	self.faction = faction
	if faction == 0:
		State.minions.append(self)

		health = State.minion_health

	elif faction == 1:
		State.monsters.append(self)

		health = State.monster_health

		modulate = Color.crimson

		collision_layer = 1 << 2
		collision_mask = 0
		set_collision_mask_bit(0, true)
		set_collision_mask_bit(1, true)


func _process(delta: float) -> void:
	task_cooldown.step(delta)
	strike_cooldown.step(delta)
	strike_hit_cooldown.step(delta)
	attack_cooldown.step(delta)
	victim_lost_cooldown.step(delta)

	if _rally_immune > 0.0:
		_rally_immune -= delta
		if _rally_immune < 0.0:
			_rally_immune = 0.0

func _physics_process(delta: float) -> void:
	check_coord.set_vector(position)
	if check_coord.x != coord.x || check_coord.y != coord.y:
		if tile:
			if faction == 0:
				tile.minions.erase(self)
			else:
				tile.monsters.erase(self)
		coord.set_vector(position)
		tile = State.map.get_tile(coord.x, coord.y)
		if faction == 0:
			tile.minions.append(self)
		else:
			tile.monsters.append(self)

	if striking:
		if !strike_hit:
			if strike_hit_cooldown.running:
				return
			strike_hit = true
			if task == MinionTask.DIG:
				dig_tile.health -= 1
				if dig_tile.health == 0:
					if dig_tile.dig_highlight != null:
						dig_tile.dig_highlight.queue_free()
						dig_tile.dig_highlight = null
					State.map.set_tile_type(dig_tile.x, dig_tile.y, TileType.GROUND)
					State.tilemap32.set_cell(dig_tile.x, dig_tile.y, 0)
					State.map.dig_tiles.erase(dig_tile)
					_move_near(dig_tile.x, dig_tile.y)
					dig_tile = null
				elif dig_tile.health < 0:
					_move_near(dig_tile.x, dig_tile.y)
					dig_tile = null
			elif task == MinionTask.ATTACK || task == MinionTask.FIGHT:
				if _victim:
					if position.distance_squared_to(_victim.position) < attack_hit_distance_sq:
						_victim.health -= 1
						if _victim.health == 0:
							_victim.die()
							_set_next_task(MinionTask.ROAM)
						else:
							_set_next_task(MinionTask.FIGHT)

		if strike_cooldown.running:
			return
		striking = false

	if _rally_immune > 0.0:
		_rally_immune = max(_rally_immune - delta, 0.0)

	if faction == 0:
		if can_interupt():
			if tile.rally > _rally_immune:
				var tiles = Helper.get_tile_circle(tile.x, tile.y, 2, true)
				var max_rally = tile.rally
				var max_tile = tile
				for tile in tiles:
					if tile.rally > max_rally:
						max_rally = tile.rally
						max_tile = tile
				if max_tile != tile:
					_rally_near(max_tile.x, max_tile.y)
				else:
					# Reached highest rally point
					_rally_immune = tile.rally

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

			MinionTask.ROAM:
				_set_target(Helper.get_walkable_pos(coord))
				task = MinionTask.ROAM

			MinionTask.GO_DIG:
				_start_path()
				task = MinionTask.GO_DIG

			MinionTask.DIG:
				task = MinionTask.DIG

			MinionTask.MOVE:
				_start_path()
				task = MinionTask.MOVE

			MinionTask.RALLY:
				_start_path()
				task = MinionTask.RALLY
				_rally_immune = 0.0

			MinionTask.ATTACK:
				task = MinionTask.ATTACK
				_set_target(_last_victim_pos)
				attack_cooldown.restart()
				victim_lost_cooldown.restart()

			MinionTask.FIGHT:
				task = MinionTask.FIGHT
				_set_target(_last_victim_pos)
				attack_cooldown.restart()
				victim_lost_cooldown.restart()

		next_task = null

	match task:
		MinionTask.IDLE:
			if task_cooldown.done:
				_set_next_task(MinionTask.ROAM)

		MinionTask.ROAM:
			_move()

			if task_cooldown.done:
				_set_next_task(MinionTask.IDLE)

		MinionTask.GO_DIG:
			_move()

			if task_cooldown.done:
				if !_advance_path():
					_set_next_task(MinionTask.DIG)

		MinionTask.DIG:
			if dig_tile.health > 0:
				_strike()
			else:
				_move_near(dig_tile.x, dig_tile.y)
				dig_tile = null

		MinionTask.MOVE:
			_move()

			if task_cooldown.done:
				_set_next_task(MinionTask.IDLE)

		MinionTask.RALLY:
			_move()

			if task_cooldown.done:
				_set_next_task(MinionTask.IDLE)

		MinionTask.ATTACK:
			# ATTACK can be interrupted. After first successful
			# Strike it switches to FIGHT which can't be interrupted anymore
			_attack()

		MinionTask.FIGHT:
			_attack()



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

	var coord_x = int(pos.x / 32.0)
	var coord_y = int(pos.y / 32.0)

	_set_target(_vary_pos_from_coord(coord_x, coord_y))
	return true

func can_interupt() -> bool:
	return (
		task != MinionTask.RALLY &&
		task != MinionTask.DIG &&
		task != MinionTask.FIGHT)

func can_start_digging() -> bool:
	return (
		task != MinionTask.GO_DIG &&
		task != MinionTask.DIG &&
		task != MinionTask.ATTACK &&
		task != MinionTask.FIGHT)

func dig(path : PoolVector2Array, dig_tile : Tile):
	self.path = path
	self.dig_tile = dig_tile
	_set_next_task(MinionTask.GO_DIG)

func attack(victim : Minion):
	if task == MinionTask.ATTACK && _victim == victim:
		return

	_victim = victim
	_last_victim_pos = victim.position
	_set_next_task(MinionTask.ATTACK)

func _attack():
	if attack_cooldown.done:
		if _victim:
			if Helper.raycast_minion(self, _victim):
				_last_victim_pos = _victim.position
				victim_lost_cooldown.restart()
				_set_target(_last_victim_pos)

		attack_cooldown.restart()

	if strike_cooldown.done && _victim && position.distance_squared_to(_victim.position) < attack_start_distance_sq:
		_strike()
	else:
		if task_cooldown.running:
			_move()

	if victim_lost_cooldown.done:
		_victim = null
		_set_next_task(MinionTask.IDLE)

func die():
	if faction == 0:
		State.minions.erase(self)
		tile.minions.erase(self)
	else:
		State.monsters.erase(self)
		tile.monsters.erase(self)

	set_process(false)
	set_physics_process(false)

	queue_free()

func _move_near(coord_x : int, coord_y : int):
	path = PoolVector2Array()
	path.append(_vary_pos_from_coord(coord_x, coord_y))
	_set_next_task(MinionTask.MOVE)

func _rally_near(coord_x : int, coord_y : int):
	path = PoolVector2Array()
	path.append(_vary_pos_from_coord(coord_x, coord_y))
	_set_next_task(MinionTask.RALLY)

func _vary_pos_from_coord(coord_x : int, coord_y : int) -> Vector2:
	var pos_x := coord_x * 32.0 + 16.0
	var pos_y := coord_y * 32.0 + 16.0

	_path_variation_x += randf() * 4.0 - 2.0
	_path_variation_y += randf() * 4.0 - 2.0

	if _path_variation_x > 15.0:
		_path_variation_x = 14.0
	elif _path_variation_x < -15.0:
		_path_variation_x = -14.0

	if _path_variation_y > 15.0:
		_path_variation_y = 14.0
	elif _path_variation_y < -15.0:
		_path_variation_y = -14.0

	return Vector2(
		pos_x + _path_variation_x,
		pos_y + _path_variation_y)
