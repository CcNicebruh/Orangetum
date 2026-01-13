extends Node

@onready var easy_btn = $VBoxContainer/Easy
@onready var norm_btn = $VBoxContainer/Normal
@onready var hard_btn = $VBoxContainer/Hard

@onready var exit_btn = $Exit

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	easy_btn.pressed.connect(_on_easy_pressed)
	norm_btn.pressed.connect(_on_norm_pressed)
	hard_btn.pressed.connect(_on_hard_pressed)
	
	exit_btn.pressed.connect(_on_exit_pressed)
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	_on_esc_pressed()
	
	
func _on_easy_pressed():
	if has_node("/root/GameSettings"):
		GameSettings.current_difficulty = GameSettings.Difficulty.EASY
	get_tree().change_scene_to_file("res://menu/game.tscn")
	
func _on_norm_pressed():
	if has_node("/root/GameSettings"):
		GameSettings.current_difficulty = GameSettings.Difficulty.NORMAL
	get_tree().change_scene_to_file("res://menu/game.tscn")
	
func _on_hard_pressed():
	if has_node("/root/GameSettings"):
		GameSettings.current_difficulty = GameSettings.Difficulty.HARD
	get_tree().change_scene_to_file("res://menu/game.tscn")
	
	
func _on_exit_pressed():
	print("Exited.")
	get_tree().change_scene_to_file("res://menu/home_menu.tscn")
	
func _on_esc_pressed():
	if Input.is_action_pressed("Return"):
		print("Pressed exit.")
		get_tree().change_scene_to_file("res://menu/home_menu.tscn")
