extends KinematicBody2D

class_name Minion

const TileType = preload("res://scripts/TileType.gd").TileType
const AudioType = preload("res://scripts/AudioType.gd").AudioType

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

onready var animation_minion := $Sprites/AnimationMinion
onready var animation_pickaxe := $Sprites/AnimationPickaxe
onready var pickaxe := $Sprites/Pickaxe

export var in_animation := false
export(PackedScene) var arrow_scene
export(PackedScene) var blood_scene
export(PackedScene) var beam_scene
export(PackedScene) var blood_drop_particles_scene

var speed := 48.0

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
var archer := false
var prisoner := false

var health := 1
var anger := 0
var dead := false

var _path_variation_x := 0.0
var _path_variation_y := 0.0

var rally_immune := 0.0

var _victim : Minion
var _last_victim_pos := Vector2.ZERO
var _victim_visible := false


var _digger := false


func _ready() -> void:
	$Sprites/Feather.visible = archer

	if in_animation:
		set_process(false)
		set_physics_process(false)
		return

	_set_next_task(MinionTask.IDLE)

	_path_variation_x += randf() * 28.0 - 14.0
	_path_variation_y += randf() * 28.0 - 14.0

	var init_coord := Coord.new()
	init_coord.set_vector(position)
	tile = State.map.get_tile(init_coord.x, init_coord.y)
	assert(tile.tile_type == TileType.GROUND)


func setup(faction : int, archer = false, prisoner = false) -> void:
	self.faction = faction
	if faction == 0:
		if !prisoner:
			State.minions.append(self)

		health = State.minion_health

	elif faction == 1:
		_digger = randi() % 2 == 0
		State.monsters.append(self)

		health = State.monster_health

		modulate = Color.crimson

		collision_layer = 1 << 2
		collision_mask = 0
		set_collision_mask_bit(0, true)
		set_collision_mask_bit(1, true)

	self.archer = archer

	if archer:
		$Sprites/Feather.visible = true

	self.prisoner = prisoner
	if prisoner:
		$Sprites/Pickaxe.visible = false


func _process(delta: float) -> void:
	task_cooldown.step(delta)
	strike_cooldown.step(delta)
	strike_hit_cooldown.step(delta)
	attack_cooldown.step(delta)
	victim_lost_cooldown.step(delta)

	if rally_immune > 0.0:
		rally_immune -= delta
		if rally_immune < 0.0:
			rally_immune = 0.0

func _physics_process(delta: float) -> void:
	check_coord.set_vector(position)
	if check_coord.x != coord.x || check_coord.y != coord.y:
		if faction == 0:
			tile.minions.erase(self)
		else:
			tile.monsters.erase(self)
		coord.set_vector(position)
		tile = State.map.get_tile(coord.x, coord.y)

		assert(tile.tile_type == TileType.GROUND)

		if faction == 0:
			tile.minions.append(self)
		else:
			tile.monsters.append(self)

	if striking:
		if !strike_hit:
			if strike_hit_cooldown.running:
				if archer:
					pickaxe.visible = true
				return
			strike_hit = true
			if task == MinionTask.DIG:
				dig_tile.health -= 1

				assert(dig_tile.minions.size() == 0)

				if dig_tile.health >= 0:
					Sounds.play(AudioType.DIG)

				if dig_tile.health == 0:
					if dig_tile.dig_highlight != null:
						dig_tile.dig_highlight.queue_free()
						dig_tile.dig_highlight = null
					State.map.set_tile_type(dig_tile.x, dig_tile.y, TileType.GROUND)
					State.tilemap32.set_cell(dig_tile.x, dig_tile.y, 0)
					State.map.dig_tiles.erase(dig_tile)
					_move_near(dig_tile.x, dig_tile.y)

					var prisoner_tiles := []
					var check_tiles = [dig_tile]

					while check_tiles.size() > 0:
						var check_count : int = check_tiles.size()
						for i in range(check_count):
							var check_tile : Tile = check_tiles[0]
							check_tiles.remove(0)

							var next_tiles = Helper.get_tile_circle(check_tile.x, check_tile.y, 1, false)
							for next_tile in next_tiles:
								if next_tile.inner_prison && !prisoner_tiles.has(next_tile):
									check_tiles.append(next_tile)
									prisoner_tiles.append(next_tile)

					for prisoner_tile in prisoner_tiles:
						if prisoner_tile.prisoners.size() > 0:
							for freed_prisoner in prisoner_tile.prisoners:
								if !is_instance_valid(freed_prisoner):
									# Could have died due to a bomg :(
									continue
								freed_prisoner.prisoner = false
								freed_prisoner.pickaxe.visible = true
								State.minions.append(freed_prisoner)
							prisoner_tile.prisoners.clear()

					dig_tile = null

				elif dig_tile.health < 0:
					_move_near(dig_tile.x, dig_tile.y)
					dig_tile = null

			elif task == MinionTask.ATTACK || task == MinionTask.FIGHT:
				if anger > 0:
					anger -= 1

				if !archer:
					if (is_instance_valid(_victim) && !_victim.dead):
						if position.distance_squared_to(_victim.position) < attack_hit_distance_sq:
							_victim.hurt()

							if _victim.health == 0:
								_set_next_task(MinionTask.ROAM)
							else:
								_set_next_task(MinionTask.FIGHT)
				else:
					var arrow : KinematicBody2D = arrow_scene.instance()
					arrow.setup((_last_victim_pos - position).normalized(), faction)
					arrow.position = position + arrow.dir * 16.0
					arrow.rotation = randf() * 2.0 * PI
					State.entity_container.add_child(arrow)
					pickaxe.visible = false


		if strike_cooldown.running:
			return
		striking = false

	if rally_immune > 0.0:
		rally_immune = max(rally_immune - delta, 0.0)

	if faction == 0:
		if can_start_rally():
			if rally_immune == 0.0 && tile.rally_countdown > 0.0 && tile.rally_time > 0.25:
				if tile.rally_end_tiles.size() == 0:
					#rally_immune = State.rally_immune
					pass
				else:
					var rally_end_tile : Tile = tile.rally_end_tiles[randi() % tile.rally_end_tiles.size()]

					var path = State.map.astar.get_point_path(tile.id, rally_end_tile.id)

					if path.size() == 0 || path.size() > 25:
						rally_immune = State.rally_immune
					else:
						_rally(path)

	if prisoner && next_task != null:
		if next_task != MinionTask.IDLE && next_task != MinionTask.ROAM && next_task != MinionTask.MOVE:
			next_task = null

	if next_task != null:
		if archer && !prisoner && next_task != MinionTask.ATTACK && MinionTask.FIGHT:
			pickaxe.visible = true

		match next_task:
			MinionTask.IDLE:
				task = MinionTask.IDLE
				task_cooldown.restart(randf() * 4.0)
				var rand := randi() % 3
				if rand == 0:
					animation_minion.play("Idle")
				elif rand == 1:
					animation_minion.play("IdleLeft")
				else:
					animation_minion.play("IdleRight")

				if target_vec.x >= 0.0:
					animation_pickaxe.play("IdleRight")
				else:
					animation_pickaxe.play("IdleLeft")

			MinionTask.ROAM:
				if faction == 0:
					_set_target(tile.coord.to_random_pos())
				else:
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
				#rally_immune = 0.0

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
				var can_dig := false
				if _digger:
					var near_tiles = Helper.get_tile_circle(coord.x, coord.y, 6, false)
					while near_tiles.size() > 0:
						var index = randi() % near_tiles.size()
						var check_tile = near_tiles[index]
						if check_tile.tile_type == TileType.DIRT:
							State.map.astar.set_point_disabled(check_tile.id, false)
							var path = State.map.astar.get_point_path(tile.id, check_tile.id)
							State.map.astar.set_point_disabled(check_tile.id, true)

							if path.size() > 0 && path.size() <= State.monster_view_distance:
								can_dig = true
								dig(path, check_tile)
								break
						near_tiles.remove(index)



				if !can_dig:
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
				if !_advance_path():
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
		animation_minion.play("WalkRight")
		animation_pickaxe.play("WalkRight")
	else:
		animation_minion.play("WalkLeft")
		animation_pickaxe.play("WalkLeft")

func _strike() -> void:
	strike_cooldown.restart()
	strike_hit_cooldown.restart()

	striking = true
	strike_hit = false

	if target_vec.x >= 0.0:
		animation_minion.play("StrikeRight")
		animation_pickaxe.play("StrikeRight")
	else:
		animation_minion.play("StrikeLeft")
		animation_pickaxe.play("StrikeLeft")

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
		path_index = 0
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

func can_start_rally() -> bool:
	if prisoner:
		return false

	if task == MinionTask.RALLY:
		return false

	if task == MinionTask.DIG:
		return false

	if task == MinionTask.FIGHT || task == MinionTask.ATTACK:
		return anger < 2

	return true

func can_start_attack() -> bool:
	if prisoner:
		return false

	if task == MinionTask.FIGHT:
		return false

	if task == MinionTask.DIG || task == MinionTask.RALLY:
		return anger >= 2

	return true

#func can_end_level() -> bool:
#	return (
#		(task != MinionTask.ATTACK &&
#		task != MinionTask.FIGHT) ||
#		prisoner)

func can_start_digging() -> bool:
	return (
		task != MinionTask.GO_DIG &&
		task != MinionTask.DIG &&
		task != MinionTask.ATTACK &&
		task != MinionTask.FIGHT &&
		!prisoner)

func dig(path : PoolVector2Array, dig_tile : Tile):
	self.path = path
	self.dig_tile = dig_tile
	_set_next_task(MinionTask.GO_DIG)

func attack(victim : Minion):
	if task == MinionTask.ATTACK && _victim == victim:
		return

	_victim = victim
	_last_victim_pos = victim.position
	_victim_visible = true
	_set_next_task(MinionTask.ATTACK)

func _attack():
	if attack_cooldown.done:
		if (is_instance_valid(_victim) && !_victim.dead):
			if Helper.raycast_minion(self, _victim):
				_victim_visible = true
				_last_victim_pos = _victim.position
				victim_lost_cooldown.restart()
				_set_target(_last_victim_pos)
			else:
				_victim_visible = false

		attack_cooldown.restart()

	if (strike_cooldown.done && (is_instance_valid(_victim) && !_victim.dead) &&
		(!archer && position.distance_squared_to(_victim.position) < attack_start_distance_sq ||
		 archer && _victim_visible)):
		_strike()
	elif victim_lost_cooldown.done:
		_victim = null
		_set_next_task(MinionTask.IDLE)
	elif task_cooldown.running:
		_move()
	else:
		# At last known pos. Victim gone...
		_victim = null
		_set_next_task(MinionTask.IDLE)

func hurt():
	health -= 1

	if health >= 0:
		anger += 1

		Sounds.play(AudioType.FIGHT)

		show_blood_effect(State.entity_container)
		show_blood_drop_effect(State.entity_container)

	if health == 0:
		die()

func show_blood_effect(container : Node2D) -> void:
	var blood : Sprite = blood_scene.instance()
	blood.position = position + Vector2(randf() * 10.0 - 5.0, randf() * 10.0 - 5.0) + Vector2(0, 8)
	blood.rotation = PI / 4 * (randi() % 4)
	container.add_child(blood)

func show_blood_drop_effect(container : Node2D) -> void:
	var blood_drop_particles = blood_drop_particles_scene.instance()
	blood_drop_particles.position = position + Vector2(randf() * 10.0 - 5.0, randf() * 10.0 - 5.0) + Vector2(0, 8)
	container.add_child(blood_drop_particles)

func die():
	Sounds.play(AudioType.DIE)

	if faction == 0:
		State.minions.erase(self)
		tile.minions.erase(self)
	else:
		State.monsters.erase(self)
		tile.monsters.erase(self)

	set_process(false)
	set_physics_process(false)

	dead = true
	queue_free()

func flee():
	Sounds.play(AudioType.FLED)
	var beam : Node2D = beam_scene.instance()
	beam.position = position
	State.entity_container.add_child(beam)

	if faction == 0:
		State.minions.erase(self)
		tile.minions.erase(self)
	else:
		State.monsters.erase(self)
		tile.monsters.erase(self)

	State.minions_fled += 1

	set_process(false)
	set_physics_process(false)

	dead = true
	queue_free()

func _move_near(coord_x : int, coord_y : int):
	path = PoolVector2Array()
	path.append(_vary_pos_from_coord(coord_x, coord_y))
	_set_next_task(MinionTask.MOVE)

#func _rally_near(coord_x : int, coord_y : int):
#	_last_rally_tiles.append(State.map.get_tile(coord_x, coord_y))
#	if _last_rally_tiles.size() > 5:
#		_last_rally_tiles.remove(0)
#
#	path = PoolVector2Array()
#	path.append(_vary_pos_from_coord(coord_x, coord_y))
#	_set_next_task(MinionTask.RALLY)

func _rally(path : PoolVector2Array):
	self.path = path
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
