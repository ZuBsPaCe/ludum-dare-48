extends Node2D

class_name Sounds

const AudioType = preload("res://scripts/AudioType.gd").AudioType

export(Array, AudioStreamSample) var sounds_dig := []
export(Array, AudioStreamSample) var sounds_dig_slow := []
export(Array, AudioStreamSample) var sounds_die := []
export(Array, AudioStreamSample) var sounds_talk := []
export(Array, AudioStreamSample) var sounds_fight := []
export(Array, AudioStreamSample) var sounds_fled := []
export(Array, AudioStreamSample) var sounds_bomb := []
export(Array, AudioStreamSample) var sounds_freed := []

var players := []
var center_players := []

var delayed_timer := []
var delayed_type := []
var delayed_pos := []

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	if delayed_timer.size() == 0:
		return

	for i in range(delayed_timer.size() - 1, -1, -1):
		var timer : float = delayed_timer[i]
		timer -= delta
		if timer <= 0.0:
			play(delayed_type[i], delayed_pos[i])
			delayed_timer.remove(i)
			delayed_type.remove(i)
			delayed_pos.remove(i)
		else:
			delayed_timer[i] = timer


func play_delayed(audio_type, pos, delay : float):
	delayed_type.append(audio_type)
	delayed_pos.append(pos)
	delayed_timer.append(delay)

func play(audio_type, pos):
	var stream : AudioStream
	var volume := 0.0

	match audio_type:
		AudioType.TEST:
			stream = Helper.rand_item(sounds_fight)
			volume = -15
		AudioType.DIG:
			stream = Helper.rand_item(sounds_dig)
			volume = -10
		AudioType.DIE:
			stream = Helper.rand_item(sounds_die)
			volume = -20
		AudioType.TALK:
			stream = Helper.rand_item(sounds_talk)
			volume = -20
		AudioType.FIGHT:
			stream = Helper.rand_item(sounds_fight)
			volume = -15
		AudioType.FLED:
			stream = Helper.rand_item(sounds_fled)
			volume = -15
		AudioType.BOMB:
			stream = Helper.rand_item(sounds_bomb)
			volume = 0
		AudioType.FREED:
			stream = Helper.rand_item(sounds_freed)
			volume = -10
		_:
			return

	if pos == null:
		_play_center(stream, volume)
	else:
		_play(stream, volume, pos)

		if audio_type == AudioType.DIG && (randi() % 4) == 0:
			stream = Helper.rand_item(sounds_dig_slow)
			_play(stream, volume, pos)



func _play(stream : AudioStreamSample, volume : float, pos : Vector2) -> void:

	var player : AudioStreamPlayer2D

	for existing_player in players:
		if !existing_player.playing:
			player = existing_player
			break

	if player == null && players.size() >= 20:
		return

	if player == null:
		player = AudioStreamPlayer2D.new()
		player.attenuation = 6.0
		player.bus = "Sounds"
		add_child(player)
		players.append(player)

	player.stream = stream
	player.position = pos - global_position
	player.volume_db = volume

	player.pitch_scale = 0.9 + randf() * 0.2

	player.play()

func _play_center(stream : AudioStreamSample, volume : float) -> void:
	var player : AudioStreamPlayer

	for existing_player in center_players:
		if !existing_player.playing:
			player = existing_player
			break

	if player == null && center_players.size() >= 20:
		return

	if player == null:
		player = AudioStreamPlayer.new()
		player.bus = "Sounds"
		add_child(player)
		center_players.append(player)

	player.stream = stream
	player.volume_db = volume

	player.play()


#
#	match audio_type:
#		AudioType.DIG:
#			dig_sounds[randi() % dig_sounds.size()].play()
#		AudioType.DIE:
#			die_sounds[randi() % die_sounds.size()].play()
#		AudioType.TALK:
#			talk_sounds[randi() % talk_sounds.size()].play()
#		AudioType.FIGHT:
#			fight_sounds[randi() % fight_sounds.size()].play()
#		AudioType.FLED:
#			fled_sounds[randi() % fled_sounds.size()].play()


