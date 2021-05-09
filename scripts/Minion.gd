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

	SWARM,

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

var path : PoolIntArray
var path_index := 0

var swarm_tile : Tile

var dig_tile : Tile

var faction := 0
var archer := false
var digger := false
var prisoner := false
var king := false
var swarm := false

var health := 1
var anger := 0
var dead := false

var _path_variation_x := 0.0
var _path_variation_y := 0.0

var rally_immune := 0.0

var _victim : Minion
var _last_victim_pos := Vector2.ZERO
var _victim_visible := false


func _ready() -> void:
	$Sprites/Feather.visible = archer
	$Sprites/Pickaxe.visible = !prisoner
	$Sprites/Crown.visible = king


	if in_animation:
		collision_layer = 0
		collision_mask = 0
		set_process(false)
		set_physics_process(false)
		return

	_set_next_task(MinionTask.IDLE)

	_path_variation_x += randf() * 28.0 - 14.0
	_path_variation_y += randf() * 28.0 - 14.0

	init_tile_coord()


func setup_minion(archer = false, prisoner = false, king = false) -> void:
	assert(tile == null, "Minion setup must happen before ready()")

	faction = 0

	self.archer = archer
	self.prisoner = prisoner
	self.king = king

	if !prisoner:
		State.minions.append(self)

	if king:
		health = State.king_health
		State.minion_kings.append(self)
		State.minion_kings_created_count += 1
		scale = Vector2(1.75, 1.75)
	else:
		health = State.minion_health


func setup_monster(archer = false, digger = false, king = false, swarm = false) -> void:
	assert(tile == null, "Minion setup must happen before ready()")

	self.faction = 1

	self.archer = archer
	self.digger = digger
	self.king = king
	self.swarm = swarm

	State.monsters.append(self)

	if king:
		health = State.king_health
		scale = Vector2(1.75, 1.75)
	else:
		health = State.monster_health

	modulate = Color.crimson

	collision_layer = 1 << 2
	collision_mask = 0
	set_collision_mask_bit(0, true)
	set_collision_mask_bit(1, true)

func init_tile_coord() -> void:
	coord.set_vector(position)
	tile = State.map.get_tile(coord.x, coord.y)

	if faction == 0:
		tile.minions.append(self)
	else:
		tile.monsters.append(self)

	if prisoner:
		tile.prisoners.append(self)

	assert(tile.tile_type == TileType.OPEN)

func update_tile_coord() -> void:
	check_coord.set_vector(position)
	if check_coord.x != coord.x || check_coord.y != coord.y:
		if faction == 0:
			tile.minions.erase(self)
		else:
			tile.monsters.erase(self)

#		var debug_coord := Coord.new()
#		debug_coord.set_vector(position)
#		var debug_tile = State.map.get_tile(debug_coord.x, debug_coord.y)
#		assert(debug_tile.tile_type == TileType.OPEN)

		coord.set_vector(position)
		tile = State.map.get_tile(coord.x, coord.y)

		assert(tile.tile_type == TileType.OPEN)

		if faction == 0:
			tile.minions.append(self)
		else:
			tile.monsters.append(self)

		assert(tile.tile_type == TileType.OPEN)

func _physics_process(delta: float) -> void:
	assert(!dead)

	task_cooldown.step(delta)
	strike_cooldown.step(delta)
	strike_hit_cooldown.step(delta)
	attack_cooldown.step(delta)
	victim_lost_cooldown.step(delta)

	if rally_immune > 0.0:
		rally_immune -= delta
		if rally_immune < 0.0:
			rally_immune = 0.0

	if striking:
		if !strike_hit:
			if strike_hit_cooldown.running:
				if archer:
					pickaxe.visible = true
				return
			strike_hit = true
			if task == MinionTask.DIG:
				dig_tile.health -= 1

				if dig_tile.health >= 0:
					assert(dig_tile.minions.size() == 0)
					Sounds.play(AudioType.DIG)

				if dig_tile.health == 0:
					if dig_tile.dig_highlight != null:
						dig_tile.dig_highlight.queue_free()
						dig_tile.dig_highlight = null
					State.map.set_tile_type(dig_tile.x, dig_tile.y, TileType.OPEN)
					State.tilemap32.set_cell(dig_tile.x, dig_tile.y, 0)
					State.map.dig_tiles.erase(dig_tile)
					_move_near(dig_tile)

					var prisoner_tiles := []
					var check_tiles = [dig_tile]

					while check_tiles.size() > 0:
						var check_count : int = check_tiles.size()
						for i in range(check_count):
							var check_tile : Tile = check_tiles[0]
							check_tiles.remove(0)

							Helper.get_tile_neighbours_4(State.tile_circle, check_tile.x, check_tile.y)
							for next_tile in State.tile_circle:
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

								if freed_prisoner.king:
									State.minion_king_count += 1

								State.minions.append(freed_prisoner)
							prisoner_tile.prisoners.clear()

					dig_tile = null

				elif dig_tile.health < 0:
					_move_near(dig_tile)
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
		if tile.rally_countdown > 0.0 && can_start_rally() && tile.rally_time > 0.25 && rally_immune == 0.0:
			if tile.rally_end_tiles.size() == 0:
				#rally_immune = State.rally_immune
				pass
			else:
				var rally_end_tile : Tile = tile.rally_end_tiles[randi() % tile.rally_end_tiles.size()]

				var path = State.map.astar.get_id_path(tile.id, rally_end_tile.id)

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
				if faction == 0 || swarm:
					_set_target(tile.coord.to_random_pos())

#					var debug_coord := Coord.new()
#					debug_coord.set_vector(target_pos)
#					var debug_tile = State.map.get_tile(debug_coord.x, debug_coord.y)
#					assert(debug_tile == tile)

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

			MinionTask.SWARM:
				_start_path()
				task = MinionTask.SWARM

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
			if swarm && swarm_tile != null:
				swarm(swarm_tile)
			elif task_cooldown.done:
				var can_dig := false
				if digger:
					Helper.get_tile_circle(State.tile_circle, coord.x, coord.y, 6, false)
					while State.tile_circle.size() > 0:
						var index = randi() % State.tile_circle.size()
						var check_tile = State.tile_circle[index]
						if check_tile.tile_type == TileType.DIRT:
							State.map.astar.set_point_disabled(check_tile.id, false)
							var path = State.map.astar.get_id_path(tile.id, check_tile.id)
							State.map.astar.set_point_disabled(check_tile.id, true)

							if path.size() > 0 && path.size() <= State.monster_view_distance:
								can_dig = true
								dig(path, check_tile)
								break
						State.tile_circle.remove(index)

				if !can_dig:
					_set_next_task(MinionTask.ROAM)

		MinionTask.ROAM:
			_move(delta)

			if task_cooldown.done:
				_set_next_task(MinionTask.IDLE)

		MinionTask.GO_DIG:
			_move(delta)

			if task_cooldown.done:
				if !_advance_path():
					_set_next_task(MinionTask.DIG)

		MinionTask.DIG:
			if dig_tile.health > 0:
				_strike()
			else:
				_move_near(dig_tile)
				dig_tile = null

		MinionTask.MOVE:
			_move(delta)

			if task_cooldown.done:
				_set_next_task(MinionTask.IDLE)

		MinionTask.RALLY:
			_move(delta)

			if task_cooldown.done:
				if !_advance_path():
					_set_next_task(MinionTask.IDLE)

		MinionTask.SWARM:
			_move(delta)

			if task_cooldown.done:
				if !_advance_path():
						swarm_tile = null
						_set_next_task(MinionTask.IDLE)
				else:
					var next_id := path[path_index]
					var next_tile : Tile = State.map.tiles[next_id]
					if next_tile.tile_type == TileType.DIRT:
						var path := PoolIntArray()
						path.append(tile.id)
						path.append(next_tile.id)
						dig(path, next_tile)

		MinionTask.ATTACK:
			# ATTACK can be interrupted. After first successful
			# Strike it switches to FIGHT which can't be interrupted anymore
			_attack(delta)

		MinionTask.FIGHT:
			_attack(delta)


func _set_next_task(new_task):
	next_task = new_task

func _move(delta : float) -> void:
	# ATTENTION: NEVER overstep the target position. Bad things will happen!
	# Also, we simply ignore timer values below delta. It's hard/impossible to correct
	# this without taking into account collisions with dig-tiles, because target positions
	# lie WITHIN dig tiles, blocking the path, which can suddenly disappear, dub by another minion.
	if task_cooldown.timer >= delta:
		move_and_slide(target_vec)

		update_tile_coord()

func _strike() -> void:
	strike_cooldown.restart()
	strike_hit_cooldown.restart()

	striking = true
	strike_hit = false

	animation_minion.stop(true)
	animation_pickaxe.stop(true)

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

	if target_vec.x >= 0.0:
		animation_minion.play("WalkRight")
		animation_pickaxe.play("WalkRight")
	else:
		animation_minion.play("WalkLeft")
		animation_pickaxe.play("WalkLeft")

func _start_path() -> void:
	if path.size() == 0:
		task_cooldown.set_done()
	else:
		assert(path.size() >= 0)
		assert(path[0] == tile.id)

		path_index = 0
		if !_advance_path():
			task_cooldown.set_done()

func _advance_path() -> bool:
	var next_tile_id : int
	while true:
		path_index += 1
		if path_index >= path.size():
			return false
		next_tile_id = path[path_index]
		if next_tile_id != tile.id:
			break

	var coord : Coord = State.map.tiles[next_tile_id].coord

	_set_target(_vary_pos_from_coord(coord.x, coord.y))
	return true

func can_start_rally() -> bool:
	if task == MinionTask.DIG || task == MinionTask.RALLY || prisoner:
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

func dig(path : PoolIntArray, dig_tile : Tile):
	self.path = path
	self.dig_tile = dig_tile
	_set_next_task(MinionTask.GO_DIG)

func can_start_swarm() -> bool:
	return (
		task != MinionTask.ATTACK &&
		task != MinionTask.FIGHT)

func swarm(swarm_tile : Tile):
	self.swarm_tile = swarm_tile

	self.path = State.map.astar_dirty.get_id_path(tile.id, swarm_tile.id)
	if path.size() == 0:
		return

	assert(path[0] == tile.id)

	var next_id := path[1]
	var next_tile : Tile = State.map.tiles[next_id]
	if next_tile.tile_type == TileType.DIRT:
		path.resize(2)
		dig(path, next_tile)
	else:
		_set_next_task(MinionTask.SWARM)


func attack(victim : Minion):
	if task == MinionTask.ATTACK && _victim == victim:
		return

	_victim = victim
	_last_victim_pos = victim.position
	_victim_visible = true
	_set_next_task(MinionTask.ATTACK)

func _attack(delta : float):
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
		_move(delta)
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
	assert(!dead)
	print_debug("Minion %s died on %s. Faction: %s" % [get_instance_id(), coord, faction])

	Sounds.play(AudioType.DIE)

	if faction == 0:
		assert(tile.minions.has(self))

		State.minions.erase(self)
		tile.minions.erase(self)

		if king:
			State.minion_kings_died_count += 1
			State.minion_kings.erase(self)
	else:
		assert(tile.monsters.has(self))

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

		if king:
			State.minion_kings.erase(self)
	else:
		State.monsters.erase(self)
		tile.monsters.erase(self)

	State.minions_fled += 1

	set_process(false)
	set_physics_process(false)

#	dead = true
	queue_free()

func _move_near(near_tile : Tile):
	path = PoolIntArray()
	path.append(tile.id)
	path.append(near_tile.id)
	_set_next_task(MinionTask.MOVE)

#func _rally_near(coord_x : int, coord_y : int):
#	_last_rally_tiles.append(State.map.get_tile(coord_x, coord_y))
#	if _last_rally_tiles.size() > 5:
#		_last_rally_tiles.remove(0)
#
#	path = PoolVector2Array()
#	path.append(_vary_pos_from_coord(coord_x, coord_y))
#	_set_next_task(MinionTask.RALLY)

func _rally(path : PoolIntArray):
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
