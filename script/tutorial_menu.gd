extends Node

@onready var exit_btn = $Exit

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	exit_btn.pressed.connect(_on_exit_pressed)
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	_on_esc_pressed()
	
func _on_exit_pressed():
	print("Exited.")
	get_tree().change_scene_to_file("res://menu/home_menu.tscn")
	
func _on_esc_pressed():
	if Input.is_action_pressed("Return"):
		print("Pressed exit.")
		get_tree().change_scene_to_file("res://menu/home_menu.tscn")
