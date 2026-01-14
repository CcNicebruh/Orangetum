extends CharacterBody2D

@export var speed: float = 80.0
@export var health: int = 30
@export var damage: int = 10
@export var exp_drop: int = 1
@export var enemy_color: Color = Color(1, 0.3, 0.3)

var player: Node2D = null
var sprite: Sprite2D = null

func _ready():
	add_to_group("enemy")
	player = get_tree().get_first_node_in_group("player")
	
	# สร้าง sprite ถ้ายังไม่มี
	sprite = get_node_or_null("Sprite2D")
	if not sprite:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		
		# สร้างรูป enemy เป็นสี่เหลี่ยม
		var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
		img.fill(enemy_color)
		sprite.texture = ImageTexture.create_from_image(img)
		add_child(sprite)
	
	# เพิ่ม collision ถ้ายังไม่มี (แยกออกจาก logic sprite)
	var collision = get_node_or_null("CollisionShape2D")
	if not collision:
		collision = CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		var shape = RectangleShape2D.new()
		shape.size = Vector2(32, 32)
		collision.shape = shape
		add_child(collision)
	elif collision.shape == null:
		# ถ้ามี node แต่ไม่มี shape
		var shape = RectangleShape2D.new()
		shape.size = Vector2(32, 32)
		collision.shape = shape

func _physics_process(delta):
	if player and is_instance_valid(player):
		var direction = (player.global_position - global_position).normalized()
		velocity = direction * speed
		
		if sprite:
			sprite.flip_h = velocity.x < 0
		
		move_and_slide()

var is_dead: bool = false

func take_damage(amount: int):
	if is_dead:
		return
	health -= amount
	flash_damage()
	if health <= 0:
		die()

func flash_damage():
	if sprite:
		sprite.modulate = Color(1, 1, 1)
		await get_tree().create_timer(0.1).timeout
		if sprite and is_instance_valid(sprite):
			sprite.modulate = enemy_color

func die():
	if is_dead:
		return
	is_dead = true
	drop_exp()
	call_deferred("queue_free") # Safely remove from tree

func drop_exp():
	var exp_orb = Area2D.new()
	exp_orb.add_to_group("exp")
	
	var orb_sprite = Sprite2D.new()
	var img = Image.create(20, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 1, 1, 1))
	orb_sprite.texture = ImageTexture.create_from_image(img)
	
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 10
	collision.shape = shape
	
	exp_orb.add_child(orb_sprite)
	exp_orb.add_child(collision)
	exp_orb.global_position = global_position
	exp_orb.set_meta("exp_value", exp_drop) # ใช้ set_meta แทน
	
	get_parent().call_deferred("add_child", exp_orb)
