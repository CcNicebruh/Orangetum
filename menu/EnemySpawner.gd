extends Node2D

@export var enemy_scene: PackedScene
@export var total_waves: int = 10

var current_wave: int = 1
var enemies_per_wave: int = 10
var enemies_spawned_this_wave: int = 0
var spawn_timer: float = 0.0
var spawn_interval: float = 1.0
var enemy_count: int = 0
var wave_active: bool = false
var wave_break_time: float = 5.0
var wave_break_timer: float = 0.0
var player: Node2D = null
var spawn_distance: float = 600.0

signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal all_waves_completed()

func _ready():
	add_to_group("enemy_spawner") # เพิ่มเข้า group
	player = get_tree().get_first_node_in_group("player")
	
	if enemy_scene == null:
		print("⚠️ Warning: ยังไม่ได้ใส่ Enemy Scene!")
	else:
		start_wave()

func _process(delta):
	if not player or enemy_scene == null:
		return
	
	if wave_active:
		#Spawn ศัตรูในเวฟ
		spawn_timer += delta
		if spawn_timer >= spawn_interval and enemies_spawned_this_wave < enemies_per_wave:
			spawn_enemy()
			spawn_timer = 0.0
		
		#เช็คว่าเวฟจบหรือยัง
		if enemies_spawned_this_wave >= enemies_per_wave and enemy_count <= 0:
			complete_wave()
	else:
		#พักระหว่างเวฟ
		wave_break_timer -= delta
		if wave_break_timer <= 0:
			start_wave()

func start_wave():
	if current_wave > total_waves:
		all_waves_completed.emit()
		show_victory()
		return
	
	wave_active = true
	enemies_spawned_this_wave = 0
	
	#เพิ่มความยากทุกเวฟ
	var base_enemies = 10 + (current_wave - 1) * 5
	var base_interval = max(0.3, 1.0 - (current_wave - 1) * 0.05)
	
	# Apply difficulty multipliers
	if has_node("/root/GameSettings"):
		enemies_per_wave = int(base_enemies * GameSettings.get_enemy_count_multiplier())
		spawn_interval = base_interval * GameSettings.get_spawn_rate_multiplier()
	else:
		enemies_per_wave = base_enemies
		spawn_interval = base_interval
	
	wave_started.emit(current_wave)
	print("🌊 Wave %d Started! Enemies: %d" % [current_wave, enemies_per_wave])
	
	#แสดงข้อความ Wave Start
	show_wave_announcement()

func spawn_enemy():
	var enemy = enemy_scene.instantiate()
	
	#สุ่มตำแหน่งรอบๆ player
	var angle = randf() * TAU
	var spawn_pos = player.global_position + Vector2(cos(angle), sin(angle)) * spawn_distance
	enemy.global_position = spawn_pos
	
	#เพิ่ม HP และ Speed ตามเวฟ + difficulty
	var base_health = 30 + (current_wave - 1) * 10
	var base_speed = 80 + (current_wave - 1) * 10
	
	if has_node("/root/GameSettings"):
		if "health" in enemy:
			enemy.health = int(base_health * GameSettings.get_enemy_health_multiplier())
		if "speed" in enemy:
			enemy.speed = int(base_speed * GameSettings.get_enemy_speed_multiplier())
	else:
		if "health" in enemy:
			enemy.health = base_health
		if "speed" in enemy:
			enemy.speed = base_speed
	
	get_parent().add_child(enemy)
	enemy_count += 1
	enemies_spawned_this_wave += 1
	
	enemy.tree_exited.connect(_on_enemy_died)
	
	print("Spawned enemy %d/%d for Wave %d" % [enemies_spawned_this_wave, enemies_per_wave, current_wave])

func complete_wave():
	wave_active = false
	wave_completed.emit(current_wave)
	print("✅ Wave %d Completed!" % current_wave)
	
	current_wave += 1
	
	# แสดงข้อความ Wave Complete และเมนูเลือก skill
	show_wave_complete_with_upgrade()

func show_wave_announcement():
	if not player:
		return
	
	var label = Label.new()
	label.text = "เริ่มรอบที่ %d" % current_wave
	label.add_theme_font_size_override("font_size", 60)
	label.modulate = Color(1, 1, 0, 1)
	label.z_index = 150
	label.position = Vector2(
		get_viewport().get_visible_rect().size.x / 2 - 100,
		get_viewport().get_visible_rect().size.y / 2 - 30
	)
	
	var hud = player.get_node_or_null("HUD")
	if hud:
		hud.add_child(label)
		
		#หายไปหลัง 2 วินาที
		await get_tree().create_timer(2.0).timeout
		if is_instance_valid(label):
			label.queue_free()

func show_wave_complete():
	# Old function - kept for compatibility
	pass

func show_wave_complete_with_upgrade():
	if not player:
		wave_break_timer = wave_break_time
		return
	
	# Pause the game while selecting upgrade
	player.pause_game()
	
	var hud = player.get_node_or_null("HUD")
	if not hud:
		player.resume_game()
		wave_break_timer = wave_break_time
		return
	
	# Create upgrade UI container
	var upgrade_ui = Control.new()
	upgrade_ui.name = "WaveUpgradeUI"
	upgrade_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	upgrade_ui.z_index = 200
	hud.add_child(upgrade_ui)
	
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.size = get_viewport().get_visible_rect().size
	upgrade_ui.add_child(bg)
	
	# Center Container for layout
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	upgrade_ui.add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)
	
	# Title with glow effect
	var title = Label.new()
	title.text = "🎉 จบรอบที่ %d! 🎉\nเลือกอัพเกรด:" % (current_wave - 1)
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Get upgrade options from player
	var options = player.get_upgrade_options()
	for i in range(options.size()):
		var button = Button.new()
		button.text = options[i].name + "\n" + options[i].description
		button.custom_minimum_size = Vector2(350, 90)
		
		# Button styling
		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color(0.15, 0.25, 0.4, 0.95)
		btn_style.corner_radius_top_left = 12
		btn_style.corner_radius_top_right = 12
		btn_style.corner_radius_bottom_left = 12
		btn_style.corner_radius_bottom_right = 12
		btn_style.border_width_left = 2
		btn_style.border_width_right = 2
		btn_style.border_width_top = 2
		btn_style.border_width_bottom = 2
		btn_style.border_color = Color(0.4, 0.6, 0.9)
		button.add_theme_stylebox_override("normal", btn_style)
		
		# Hover style
		var btn_hover = StyleBoxFlat.new()
		btn_hover.bg_color = Color(0.25, 0.4, 0.6, 0.95)
		btn_hover.corner_radius_top_left = 12
		btn_hover.corner_radius_top_right = 12
		btn_hover.corner_radius_bottom_left = 12
		btn_hover.corner_radius_bottom_right = 12
		btn_hover.border_width_left = 3
		btn_hover.border_width_right = 3
		btn_hover.border_width_top = 3
		btn_hover.border_width_bottom = 3
		btn_hover.border_color = Color(0.5, 0.8, 1)
		button.add_theme_stylebox_override("hover", btn_hover)
		
		# Pressed style
		var btn_pressed = StyleBoxFlat.new()
		btn_pressed.bg_color = Color(0.1, 0.3, 0.5, 0.95)
		btn_pressed.corner_radius_top_left = 12
		btn_pressed.corner_radius_top_right = 12
		btn_pressed.corner_radius_bottom_left = 12
		btn_pressed.corner_radius_bottom_right = 12
		button.add_theme_stylebox_override("pressed", btn_pressed)
		
		button.add_theme_font_size_override("font_size", 16)
		button.add_theme_color_override("font_color", Color(1, 1, 1))
		
		var option = options[i]
		button.pressed.connect(func():
			player.apply_upgrade(option)
			upgrade_ui.queue_free()
			player.resume_game()
			wave_break_timer = 0.5 # Short delay before next wave
		)
		vbox.add_child(button)

func show_victory():
	if not player:
		return
	
	var victory_ui = Control.new()
	victory_ui.z_index = 300
	
	var hud = player.get_node_or_null("HUD")
	if hud:
		hud.add_child(victory_ui)
	
	var bg = ColorRect.new()
	bg.color = Color(0, 0.3, 0, 0.9)
	bg.size = get_viewport().get_visible_rect().size
	victory_ui.add_child(bg)
	
	var label = Label.new()
	var diff_name = "Unknown"
	if has_node("/root/GameSettings"):
		diff_name = GameSettings.get_difficulty_name()
	var time_str = "00:00"
	if player.has_method("get_formatted_time"):
		time_str = player.get_formatted_time()
	label.text = "🎉 ชนะแล้ว! 🎉\nคุณผ่านครบ 10 รอบแล้ว!\nเลเวลสุดท้าย: %d\nเวลา: %s\nความยาก: %s" % [player.level, time_str, diff_name]
	label.add_theme_font_size_override("font_size", 50)
	label.position = Vector2(get_viewport().get_visible_rect().size.x / 2 - 250, 150)
	victory_ui.add_child(label)
	
	var restart_btn = Button.new()
	restart_btn.text = "เล่นอีกครั้ง"
	restart_btn.custom_minimum_size = Vector2(200, 60)
	restart_btn.position = Vector2(get_viewport().get_visible_rect().size.x / 2 - 100, 350)
	restart_btn.pressed.connect(func():
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		get_tree().reload_current_scene()
	)
	victory_ui.add_child(restart_btn)

func _on_enemy_died():
	enemy_count = max(0, enemy_count - 1)
	print("Enemy died. Remaining: %d/%d" % [enemy_count, enemies_per_wave])
