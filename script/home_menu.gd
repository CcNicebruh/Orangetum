extends Node

@onready var play_btn = $VBoxContainer/Play
@onready var tuto_btn = $VBoxContainer/Tutorial


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	play_btn.pressed.connect(_on_play_pressed)
	tuto_btn.pressed.connect(_on_tuto_pressed)
	
	play_btn.grab_focus()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_play_pressed() -> void:
	print("clicked play")
	get_tree().change_scene_to_file("res://menu/diff_menu.tscn")

func _on_tuto_pressed() -> void:
	print("clicked tutorial")
	get_tree().change_scene_to_file("res://menu/tutorial.tscn")
