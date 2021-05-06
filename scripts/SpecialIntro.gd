extends Node2D

export var merchant := false

const AudioType = preload("res://scripts/AudioType.gd").AudioType

var minion_icon = preload("res://sprites/MinionIcon.png")
var archer_icon = preload("res://sprites/ArcherIcon.png")
var bomb_icon = preload("res://sprites/BombIcon.png")




onready var minion := $Minion

var mouths := []
var eyes := []


var talking := false
var mouth_cooldown := Cooldown.new(0.15)
var eyes_cooldown := Cooldown.new(0.9)
var talk_cooldown := Cooldown.new(0.3)

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

	if !merchant:
		$CanvasLayer/VBoxContainer.visible = false

	visible = false
	set_process(false)

func _process(delta: float) -> void:
	mouth_cooldown.step(delta)
	eyes_cooldown.step(delta)
	talk_cooldown.step(delta)

	if talking && mouth_cooldown.done:
		mouth_cooldown.restart()
		reset_mouths()
		mouths[0].visible = false
		mouths[randi() % (mouths.size() - 1) + 1].visible = true

	if talking && talk_cooldown.done:
		talk_cooldown.restart()
		Sounds.play(AudioType.TALK)

	if talking && eyes_cooldown.done:
		eyes_cooldown.restart()
		reset_eyes()
		eyes[0].visible = false
		eyes[randi() % eyes.size()].visible = true

	if !merchant && $AnimationPlayer.current_animation_position > 0.2:
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

	if !merchant:
		$CanvasLayer/VBoxContainer.visible = false
	else:
		$CanvasLayer/Label.visible = false
		$CanvasLayer/Button1.visible = false
		$CanvasLayer/Button2.visible = false
		$CanvasLayer/Button3.visible = false

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

func initialize_offer():
	var button1 = $CanvasLayer/Button1
	var button2 = $CanvasLayer/Button2
	var button3 = $CanvasLayer/Button3
	button1.connect("pressed", self, "button1_pressed")
	button2.connect("pressed", self, "button2_pressed")
	button3.connect("pressed", self, "button3_pressed")

	button1.set_icon(minion_icon)
	button1.set_count(10)

	button2.set_icon(archer_icon)
	button2.set_count(8)

	button3.set_icon(bomb_icon)
	button3.set_count(4)

func button1_pressed():
	State.increase_minion_count += 10
	switch_scene()

func button2_pressed():
	State.increase_archer_count += 8
	switch_scene()

func button3_pressed():
	State.increase_bomb_count += 4
	switch_scene()

func reset_mouths():
	for i in range(1, mouths.size()):
		mouths[i].visible = false
	mouths[0].visible = true


func reset_eyes():
	for i in range(1, eyes.size()):
		eyes[i].visible = false
	eyes[0].visible = true
