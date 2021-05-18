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
onready var exclamation := $Sprites/Exclamation

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
var was_striking := false
var strike_hit := false
var strike_cooldown := Cooldown.new(1.0)
var strike_hit_cooldown := Cooldown.new(0.25)
var attack_cooldown := Cooldown.new(0.2)
var victim_lost_cooldown := Cooldown.new(8.0)
var freeze_cooldown := Cooldown.new(1.0)

var target_pos := Vector2()
var target_vec := Vector2()

var view_distance : float
var view_distance_sq : float

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

var dig_priority := false

var under_attack_cooldown := 0.0

var _path_variation_x := 0.0
var _path_variation_y := 0.0

var rally_immune := 0.0

# WeakRef to other minion
# queue_free() and is_instance_valid() does not work properly (only in release builds...)
# https://github.com/godotengine/godot/issues/32383
# https://github.com/godotengine/godot/issues/43422
var _victimref := weakref(null)
var _last_victim_pos := Vector2.ZERO
var _victim_visible := false


func _ready() -> void:
	$Sprites/Feather.visible = archer
	pickaxe.visible = !prisoner
	$Sprites/Crown.visible = king
	exclamation.visible = false


	if in_animation:
		collision_layer = 0
		collision_mask = 0
		set_process(false)
		set_physics_process(false)
		return

	_set_next_task(MinionTask.IDLE)

	_path_variation_x += randf() * 28.0 - 14.0
	_path_variation_y += randf() * 28.0 - 14.0

	strike_cooldown.set_done()

	init_tile_coord()


func setup_minion(archer = false, prisoner = false, king = false) -> void:
	assert(tile == null, "Minion setup must happen before ready()")

	faction = 0

	self.archer = archer
	self.prisoner = prisoner
	self.king = king

	view_distance = State.minion_view_distance
	view_distance_sq = view_distance * view_distance

	dig_priority = randi() % 4 == 0

	if !prisoner:
		State.minions.append(self)

	if king:
		health = State.king_health
		State.minion_kings.append(self)
		State.minion_kings_created_count += 1
		$Sprites.scale = Vector2(1.75, 1.75)
	else:
		health = State.minion_health


func setup_monster(archer = false, digger = false, king = false, swarm = false) -> void:
	assert(tile == null, "Minion setup must happen before ready()")

	self.faction = 1

	self.archer = true
	self.digger = digger
	self.king = king
	self.swarm = swarm

	view_distance = State.monster_view_distance
	view_distance_sq = view_distance * view_distance

	State.monsters.append(self)

	if king:
		health = State.king_health
		$Sprites.scale = Vector2(1.75, 1.75)
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
	freeze_cooldown.step(delta)

	if freeze_cooldown.running:
		return

	if exclamation.visible:
		if exclamation.frame == 2:
			exclamation.frame = randi() % 2

		var alpha : float = exclamation.modulate.a
		alpha = max(0.0, alpha - delta)
		exclamation.modulate.a = alpha
		if alpha == 0.0:
			exclamation.visible = false


	if under_attack_cooldown > 0.0:
		under_attack_cooldown -= delta * 0.25

	if rally_immune > 0.0:
		rally_immune -= delta
		if rally_immune < 0.0:
			rally_immune = 0.0

	was_striking = false

	if striking:
		if !strike_hit:
			if strike_hit_cooldown.running:
				if archer:
					pickaxe.visible = true
				return
			strike_hit = true
			if task == MinionTask.DIG:
				if dig_tile.health > 0:
					State.sounds.play(AudioType.DIG, position)
					dig_tile.hurt()

				if dig_tile.health <= 0:
					_move_near(dig_tile)
					dig_tile = null

			elif task == MinionTask.ATTACK || task == MinionTask.FIGHT:
				if anger > 0:
					anger -= 1

				if !archer:
					var victim = _victimref.get_ref()
					if victim != null && !victim.dead:
						if position.distance_squared_to(victim.position) < attack_hit_distance_sq:
							victim.hurt()

							if victim.health == 0:
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
		was_striking = true

	if rally_immune > 0.0:
		rally_immune = max(rally_immune - delta, 0.0)

	if faction == 0:
		if tile.rally_countdown > 0.0 && tile.rally_time > 0.25 && can_start_rally():
			if tile.rally_end_tiles.size() == 0:
				#rally_immune = State.rally_immune
				pass
			else:
				# rally_end_tiles are sorted by priority from END_PORTAL to large to low cooldown.
				# 2 iterations. First one with larger ones. Second one with lower ones.
				var path_found := false
				var first_tile : Tile = tile.rally_end_tiles[0]

				if first_tile.tile_type == TileType.END_PORTAL:
					if State.level < 10 || State.end_portals[0].active:
						Helper.get_tile_neighbours_4(State.tile_circle, first_tile.x, first_tile.y)
						var index := randi() % State.tile_circle.size()
						var rally_end_tile = null
						for i in State.tile_circle.size():
							rally_end_tile = State.tile_circle[index]
							if rally_end_tile.tile_type == TileType.OPEN:
								var path = State.map.astar.get_id_path(tile.id, rally_end_tile.id)
								if path.size() > 0 && path.size() < 25:
									_rally(path)
									path_found = true
									break
							index = posmod(index + 1, State.tile_circle.size())

				if !path_found:
					var iteration_range := 5
					var first_range := int(min(iteration_range, tile.rally_end_tiles.size()))
					var second_range := tile.rally_end_tiles.size() - first_range

					for rally_iteration in 2:
						var start : int
						var offset : int
						var current_range : int

						if rally_iteration == 0:
							start = 0
							offset = randi() % first_range
							current_range = first_range
						else:
							if second_range == 0:
								break
							start = iteration_range
							offset = randi() % second_range
							current_range = second_range

						var rally_end_tile : Tile

						for i in iteration_range:
							rally_end_tile = tile.rally_end_tiles[start + offset]
							if rally_end_tile.tile_type == TileType.OPEN:
								var path = State.map.astar.get_id_path(tile.id, rally_end_tile.id)
								if path.size() > 0 && path.size() < 25:
									_rally(path)
									path_found = true
									break

							offset = posmod(offset + 1, current_range)

						if path_found:
							break

				if !path_found:
					# Don't check every frame. But check again soon, because new tiles could be dug until then.
					rally_immune = State.rally_immune_short

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
					if tile.rally_end_tiles.size() == 0:
						# 4.0 is a hack. But necessary because of odd dig/rally ping-pong behaviour...
						rally_immune = tile.rally_countdown + 4.0
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
	if rally_immune > 0:
		return false

	if task == MinionTask.RALLY || task == MinionTask.DIG || prisoner:
		return false

	if task == MinionTask.FIGHT || task == MinionTask.ATTACK:
		return anger < 2

	return true

func can_start_attack() -> bool:
	if prisoner:
		return false

	if task == MinionTask.ATTACK || task == MinionTask.FIGHT:
		return false

	if task == MinionTask.DIG || task == MinionTask.RALLY:
		# Adjust can_start_digging() if you adjust this.
		return anger >= 2

	if task == MinionTask.GO_DIG && dig_priority:
		return anger >= 2

	return true

#func can_end_level() -> bool:
#	return (
#		(task != MinionTask.ATTACK &&
#		task != MinionTask.FIGHT) ||
#		prisoner)

func can_start_digging() -> bool:
	if prisoner:
		return false

	if task == MinionTask.RALLY:
		return false

	if task == MinionTask.GO_DIG ||	task == MinionTask.DIG:
		return false

	if dig_priority && anger < 2:
		# Adjust can_start_attack() if you adjust this.
		return true

	if task == MinionTask.ATTACK ||	task == MinionTask.FIGHT:
		return false

	return true

func is_digging() -> bool:
	return (
		task == MinionTask.GO_DIG ||
		task == MinionTask.DIG)

func dig(path : PoolIntArray, dig_tile : Tile):
	self.path = path
	self.dig_tile = dig_tile
	_set_next_task(MinionTask.GO_DIG)

func can_start_swarm() -> bool:
	return (
		task == MinionTask.IDLE ||
		task == MinionTask.ROAM)

func swarm(swarm_tile : Tile):
	self.swarm_tile = swarm_tile

	self.path = State.map.astar_dirty.get_id_path(tile.id, swarm_tile.id)
	if path.size() < 2:
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
	var last_victim = _victimref.get_ref()

	if task == MinionTask.ATTACK && last_victim == victim:
		return

	if last_victim != null && !last_victim.dead:
		if last_victim.under_attack_cooldown >= 1.0:
			last_victim.under_attack_cooldown -= 1.0

	if faction > 0:
		freeze_once(true)

	_victimref = weakref(victim)
	victim.under_attack_cooldown += 1.0

	if victim.faction > 0:
		victim.freeze_once(false)

	_last_victim_pos = victim.position
	_victim_visible = true
	_set_next_task(MinionTask.ATTACK)

func _attack(delta : float):
	if attack_cooldown.done:
		var victim = _victimref.get_ref()
		if victim != null && !victim.dead:
			if Helper.raycast_minion(self, victim):
				_victim_visible = true
				_last_victim_pos = victim.position
				victim_lost_cooldown.restart()
				_set_target(_last_victim_pos)
			else:
				# Victim fleeing
				_victim_visible = false
		else:
			if _victim_visible:
				# Saw the victim die
				_victimref = weakref(null)
				_set_next_task(MinionTask.IDLE)
				return

			# Victim died, but we did not see it

		attack_cooldown.restart()

	var victim = _victimref.get_ref()

	if (strike_cooldown.done && victim != null && !victim.dead &&
		(!archer && position.distance_squared_to(victim.position) < attack_start_distance_sq ||
		 archer && _victim_visible)):
		_strike()
	elif victim_lost_cooldown.done:
		_victimref = weakref(null)
		_set_next_task(MinionTask.IDLE)
		if randi() % 2 == 0:
			show_exclamation(false)
	elif task_cooldown.running:
		if was_striking:
			# Continue walk animation
			_set_target(_last_victim_pos)

		_move(delta)
	else:
		# At last known pos. Victim gone...
		_victimref = weakref(null)
		_set_next_task(MinionTask.IDLE)
		if randi() % 2 == 0:
			show_exclamation(false)

func hurt(damage : int = 1):
	if health <= 0:
		return

	health = max(0, health - damage)

	State.sounds.play(AudioType.FIGHT, position)

	show_blood_effect()
	show_blood_drop_effect(State.entity_container)

	if health == 0:
		die()
	else:
		anger += 1

func show_blood_effect() -> void:
	var blood : Sprite = blood_scene.instance()
	blood.position = position + Vector2(randf() * 10.0 - 5.0, randf() * 10.0 - 5.0)# + Vector2(0, 8)
	#blood.position = position
	#blood.rotation = PI / 4 * (randi() % 4)
	blood.flip_h = (randi() % 2) == 1
	blood.flip_v = (randi() % 2) == 1
	blood.frame = randi() % 3
	State.decal_container.add_child(blood)

func show_blood_drop_effect(container : Node2D) -> void:
	var blood_drop_particles = blood_drop_particles_scene.instance()
	blood_drop_particles.position = position + Vector2(randf() * 10.0 - 5.0, randf() * 10.0 - 5.0) + Vector2(0, 8)
	container.add_child(blood_drop_particles)

func die():
	assert(!dead)
	#print_debug("Minion %s died on %s. Faction: %s" % [get_instance_id(), coord, faction])

	State.sounds.play(AudioType.DIE, position)

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

		State.stat_killed += 1

	set_process(false)
	set_physics_process(false)

	dead = true
	queue_free()

func flee():
	State.sounds.play(AudioType.FLED, position)
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


func freeze_once(attack : bool) -> void:
	if !freeze_cooldown.started && (task == MinionTask.IDLE || task == MinionTask.ROAM || task == MinionTask.GO_DIG || task == MinionTask.DIG):
		freeze_cooldown.restart(0.75 + randf() * 1.0)

		if randi() % 3 == 0:
			show_exclamation(attack)

		animation_minion.play("Idle")

func show_exclamation(attack : bool) -> void:
	if attack:
		exclamation.frame = randi() % 2
	else:
		exclamation.frame = 2
	exclamation.visible = true

func _move_near(near_tile : Tile):
	path = PoolIntArray()
	path.append(tile.id)
	path.append(near_tile.id)
	_set_next_task(MinionTask.MOVE)

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
