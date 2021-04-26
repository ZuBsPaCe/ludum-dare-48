extends Node2D

onready var minion := $Minion

var mouths := []
var eyes := []

var talking := false
var mouth_cooldown := Cooldown.new(0.15)
var eyes_cooldown := Cooldown.new(0.9)

signal stop_intro

func _ready() -> void:
	mouths.append($Sprites/MouthBase)
	mouths.append($Sprites/Mouth1)
	mouths.append($Sprites/Mouth2)
	mouths.append($Sprites/Mouth3)
	mouths.append($Sprites/Mouth4)

	eyes.append($Sprites/Eyes1)
	eyes.append($Sprites/Eyes2)
	eyes.append($Sprites/Eyes3)

	reset_eyes()
	reset_mouths()

	visible = false
	set_process(false)

func _process(delta: float) -> void:
	mouth_cooldown.step(delta)
	eyes_cooldown.step(delta)

	if talking && mouth_cooldown.done:
		mouth_cooldown.restart()
		reset_mouths()
		mouths[0].visible = false
		mouths[randi() % (mouths.size() - 1) + 1].visible = true

	if talking && eyes_cooldown.done:
		eyes_cooldown.restart()
		reset_eyes()
		eyes[0].visible = false
		eyes[randi() % eyes.size()].visible = true

	if $AnimationPlayer.current_animation_position > 0.2:
		if Input.is_action_just_pressed("command"):
			switch_scene()

func start():
	set_process(true)
	$AnimationPlayer.play("Default")

func minion_walk_left():
	minion.animation_minion.play("WalkLeft")
	minion.animation_pickaxe.play("WalkLeft")

func minion_idle_left():
	minion.animation_minion.play("IdleLeft")
	minion.animation_pickaxe.play("IdleLeft")

func switch_scene():
	set_process(false)
	visible = false
	$CanvasLayer/VBoxContainer.visible = false
	$AnimationPlayer.stop()
	emit_signal("stop_intro")


func start_talking():
	talking = true
	mouth_cooldown.restart()
	eyes_cooldown.restart()

func stop_talking():
	talking = false
	reset_mouths()
	reset_eyes()

func reset_mouths():
	for i in range(1, mouths.size()):
		mouths[i].visible = false
	mouths[0].visible = true


func reset_eyes():
	for i in range(1, eyes.size()):
		eyes[i].visible = false
	eyes[0].visible = true
