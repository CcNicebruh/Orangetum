extends CharacterBody2D

@export var speed: float = 80.0
@export var health: int = 30
@export var damage: int = 10
@export var exp_drop: int = 1
@export var enemy_color: Color = Color(1, 0.3, 0.3)

var player: Node2D = null
var sprite: Sprite2D = null
var is_dead: bool = false

func _ready():
	add_to_group("enemy")
	player = get_tree().get_first_node_in_group("player")
	
	sprite = get_node_or_null("Sprite2D")
	if not sprite:
		sprite = Sprite2D.new(); add_child(sprite)
		var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
		img.fill(enemy_color)
		sprite.texture = ImageTexture.create_from_image(img)
	
	var col = get_node_or_null("CollisionShape2D")
	if not col:
		col = CollisionShape2D.new(); col.name = "CollisionShape2D"; add_child(col)
	if col.shape == null:
		col.shape = RectangleShape2D.new(); col.shape.size = Vector2(32, 32)

func _physics_process(_delta):
	if is_instance_valid(player):
		velocity = (player.global_position - global_position).normalized() * speed
		if sprite: sprite.flip_h = velocity.x < 0
		move_and_slide()

func take_damage(amount):
	if is_dead: return
	health -= amount
	flash_damage()
	if health <= 0: die()

func flash_damage():
	if sprite:
		sprite.modulate = Color.WHITE
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(sprite): sprite.modulate = Color.WHITE # Reset to white/normal

func die():
	if is_dead: return
	is_dead = true
	drop_exp()
	call_deferred("queue_free")

func drop_exp():
	var orb = Area2D.new(); orb.add_to_group("exp"); orb.global_position = global_position; orb.set_meta("exp_value", exp_drop)
	var s = Sprite2D.new(); orb.add_child(s)
	var img = Image.create(20, 20, false, Image.FORMAT_RGBA8); img.fill(Color.CYAN); s.texture = ImageTexture.create_from_image(img)
	var c = CollisionShape2D.new(); c.shape = CircleShape2D.new(); c.shape.radius = 10; orb.add_child(c)
	get_parent().call_deferred("add_child", orb)
