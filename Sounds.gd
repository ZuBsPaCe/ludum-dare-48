extends Node2D

const AudioType = preload("res://scripts/AudioType.gd").AudioType

var sound_dig1 := AudioStreamPlayer
var sound_die := AudioStreamPlayer

var sound_talk1 := AudioStreamPlayer
var sound_talk2 := AudioStreamPlayer
var sound_talk3 := AudioStreamPlayer

var sound_fight := AudioStreamPlayer

var dig_sounds := []
var die_sounds := []
var talk_sounds := []
var fight_sounds := []
var fled_sounds := []


func _ready() -> void:
	dig_sounds.append($Dig1)
	die_sounds.append($Die)
	talk_sounds.append($Talk1)
	talk_sounds.append($Talk2)
	talk_sounds.append($Talk3)
	fight_sounds.append($Fight)
	fled_sounds.append($Fled)

func play(audio_type):
	match audio_type:
		AudioType.DIG:
			dig_sounds[randi() % dig_sounds.size()].play()
		AudioType.DIE:
			die_sounds[randi() % die_sounds.size()].play()
		AudioType.TALK:
			talk_sounds[randi() % talk_sounds.size()].play()
		AudioType.FIGHT:
			fight_sounds[randi() % fight_sounds.size()].play()
		AudioType.FLED:
			fled_sounds[randi() % fled_sounds.size()].play()


