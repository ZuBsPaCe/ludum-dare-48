extends Node2D

class_name Sounds

const AudioType = preload("res://scripts/AudioType.gd").AudioType

export(Array, AudioStreamSample) var sounds_dig := []
export(Array, AudioStreamSample) var sounds_die := []
export(Array, AudioStreamSample) var sounds_talk := []
export(Array, AudioStreamSample) var sounds_fight := []
export(Array, AudioStreamSample) var sounds_fled := []

var players := []

func _ready() -> void:
	pass

func play(audio_type, pos):
	var stream : AudioStream
	match audio_type:
		AudioType.DIG:
			stream = Helper.rand_item(sounds_dig)
		AudioType.DIE:
			stream = Helper.rand_item(sounds_die)
		AudioType.TALK:
			stream = Helper.rand_item(sounds_talk)
		AudioType.FIGHT:
			stream = Helper.rand_item(sounds_fight)
		AudioType.FLED:
			stream = Helper.rand_item(sounds_fled)
		_:
			return


	var player : AudioStreamPlayer2D

	for existing_player in players:
		if !existing_player.playing:
			player = existing_player
			break

	if player == null && players.size() >= 20:
		return

	if player == null:
		player = AudioStreamPlayer2D.new()
		add_child(player)
		players.append(player)

	player.stream = stream

	if pos == null:
		player.position = Vector2.ZERO
	else:
		player.position = pos - global_position
	player.volume_db = -20
	player.attenuation = 5.0
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


