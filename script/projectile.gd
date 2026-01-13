extends Area2D

var target: Node2D = null
var damage: int = 10
var speed: float = 500.0
var lifetime: float = 5.0

func _ready():
	body_entered.connect(_on_body_entered)
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _process(delta):
	if target and is_instance_valid(target):
		var direction = (target.global_position - global_position).normalized()
		global_position += direction * speed * delta
		rotation = direction.angle()
	else:
		queue_free()

func _on_body_entered(body):
	if body.is_in_group("enemy"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
