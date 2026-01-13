extends Sprite2D

@export var speed: float = 50.0
@export var health: int = 100
@export var damage: int = 10
@export var patrol_distance: float = 200.0

# Movement
var direction: int = 1
var start_position: Vector2
var velocity: Vector2 = Vector2.ZERO
var gravity = 980.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	start_position = global_position
	
	texture = preload("res://img/orange2.png")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	velocity.y += gravity * delta
	
	patrol(delta)
	
	global_position += velocity * delta
	
	if direction > 0:
		flip_h = false
	else:
		flip_h = true
		
	check_collision_with_player()
		
func patrol(delta):
	velocity.x = direction * speed
	
	var distance_from_start = global_position.x - start_position.x
	if abs(distance_from_start) >= patrol_distance:
		direction *= -1

func check_collision_with_player():
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var distance = global_position.distance_to(player.global_position)
		if distance < 50:
			if player.has_method("take_damage"):
				player.take_damage(damage)
				queue_free()

func take_damage(amount: int):
	health -= amount
	flash_damage()
	
	if health <= 0:
		die()
		
func flash_damage():
	modulate = Color(1, 0.3, 0.3)
	await get_tree().create_timer(0.1).timeout
	modulate = Color(1, 1, 1)
	
func die():
	queue_free()
	
func _on_area_2d_body_entered(body):
	if body.is_in_group("player"):
		body.take_damage(damage)
