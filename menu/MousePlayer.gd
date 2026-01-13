extends Area2D

# Stats 
@export var health: int = Config.player_health
@export var max_health: int = Config.player_max_health
@export var move_speed: float = Config.player_move_speed
@export var pickup_range: float = Config.player_pickup_range

# Cursor
@export var cursor_texture: Texture2D
@export var cursor_scale: float = 1.0

# Experience & Level
var experience: int = 0
var level: int = 1
var exp_to_next_level: int = Config.base_exp_needed

# Manual Shooting
var manual_shoot_timer: float = 0.0
var manual_shoot_cooldown: float = Config.skills["Q"].cooldown # Default to fireball CD
var god_mode: bool = false # Cheat
var cheat_buffer: String = ""

# Gameplay Timer
var elapsed_time: float = 0.0

# Weapons
var weapons: Array = []

# Skills
var skills: Dictionary = {
	"Q": {"name": Config.skills["Q"].name, "unlocked": false, "level": 0, "max_level": Config.skills["Q"].max_level},
	"W": {"name": Config.skills["W"].name, "unlocked": false, "level": 0, "max_level": Config.skills["W"].max_level},
	"E": {"name": Config.skills["E"].name, "unlocked": false, "level": 0, "max_level": Config.skills["E"].max_level}
}
var all_skills_unlocked: bool = false

var cursor_sprite: Sprite2D
var upgrade_ui: Control = null
var pause_ui: Control = null
var game_paused: bool = false

signal level_up(new_level: int)
signal exp_gained(amount: int)
signal health_changed(current: int, maximum: int)

func _ready():
	add_to_group("player")
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	
	# Ensure game is unpaused on start/restart
	get_tree().paused = false
	
	# Allow player to process during pause (for UI interaction)
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# สร้าง cursor sprite
	cursor_sprite = Sprite2D.new()
	cursor_sprite.z_index = 100
	add_child(cursor_sprite)
	
	if cursor_texture:
		cursor_sprite.texture = cursor_texture
	else:
		create_default_cursor()
	
	cursor_sprite.scale = Vector2(cursor_scale, cursor_scale)
	
	# Collision
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 10.0
	collision.shape = shape
	add_child(collision)
	
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	level_up.connect(_on_level_up)
	
	# สร้าง UI
	create_ui()
	
	# เริ่มต้นอาวุธ (ไม่มี - จะได้จาก skill)
	# add_weapon("projectile", 1.5, 15, "Fireball")
	
	# เชื่อมต่อกับ EnemySpawner
	call_deferred("connect_to_spawner")
	
	# Auto-pause signals
	get_window().focus_exited.connect(_on_window_focus_exited)
	get_window().mouse_exited.connect(_on_window_mouse_exited)

func pause_game():
	game_paused = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func resume_game():
	game_paused = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func create_default_cursor():
	var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	for x in range(32):
		for y in range(32):
			var dx = x - 16
			var dy = y - 16
			var distance = sqrt(dx * dx + dy * dy)
			
			if distance <= 8:
				img.set_pixel(x, y, Color(0.2, 0.8, 1, 1))
			elif distance <= 10:
				img.set_pixel(x, y, Color(0, 0, 0, 1))
	
	cursor_sprite.texture = ImageTexture.create_from_image(img)

func create_ui():
	# HUD
	var hud = CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)
	
	# Main container with panel background
	var main_panel = PanelContainer.new()
	main_panel.position = Vector2(10, 10)
	
	# Style for the panel
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.15, 0.9)
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.3, 0.5, 0.8, 0.8)
	panel_style.content_margin_left = 15
	panel_style.content_margin_right = 15
	panel_style.content_margin_top = 10
	panel_style.content_margin_bottom = 10
	main_panel.add_theme_stylebox_override("panel", panel_style)
	hud.add_child(main_panel)
	
	var health_container = VBoxContainer.new()
	health_container.add_theme_constant_override("separation", 5)
	main_panel.add_child(health_container)
	
	# Health section
	var health_label = Label.new()
	health_label.name = "HealthLabel"
	health_label.text = "HP: %d/%d" % [health, max_health]
	health_label.add_theme_font_size_override("font_size", 18)
	health_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	health_container.add_child(health_label)
	
	var health_bar = ProgressBar.new()
	health_bar.name = "HealthBar"
	health_bar.custom_minimum_size = Vector2(220, 18)
	health_bar.max_value = max_health
	health_bar.value = health
	health_bar.show_percentage = false
	
	# Health bar style - red gradient
	var health_fill = StyleBoxFlat.new()
	health_fill.bg_color = Color(0.9, 0.2, 0.2)
	health_fill.corner_radius_top_left = 5
	health_fill.corner_radius_top_right = 5
	health_fill.corner_radius_bottom_left = 5
	health_fill.corner_radius_bottom_right = 5
	health_bar.add_theme_stylebox_override("fill", health_fill)
	
	var health_bg = StyleBoxFlat.new()
	health_bg.bg_color = Color(0.2, 0.1, 0.1)
	health_bg.corner_radius_top_left = 5
	health_bg.corner_radius_top_right = 5
	health_bg.corner_radius_bottom_left = 5
	health_bg.corner_radius_bottom_right = 5
	health_bar.add_theme_stylebox_override("background", health_bg)
	health_container.add_child(health_bar)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 5)
	health_container.add_child(spacer)
	
	# EXP section
	var exp_label = Label.new()
	exp_label.name = "ExpLabel"
	exp_label.text = "Level %d - EXP: %d/%d" % [level, experience, exp_to_next_level]
	exp_label.add_theme_font_size_override("font_size", 14)
	exp_label.add_theme_color_override("font_color", Color(0.3, 0.8, 1))
	health_container.add_child(exp_label)
	
	var exp_bar = ProgressBar.new()
	exp_bar.name = "ExpBar"
	exp_bar.custom_minimum_size = Vector2(220, 12)
	exp_bar.max_value = exp_to_next_level
	exp_bar.value = experience
	exp_bar.show_percentage = false
	
	# EXP bar style - cyan/blue gradient
	var exp_fill = StyleBoxFlat.new()
	exp_fill.bg_color = Color(0.2, 0.7, 0.9)
	exp_fill.corner_radius_top_left = 4
	exp_fill.corner_radius_top_right = 4
	exp_fill.corner_radius_bottom_left = 4
	exp_fill.corner_radius_bottom_right = 4
	exp_bar.add_theme_stylebox_override("fill", exp_fill)
	
	var exp_bg = StyleBoxFlat.new()
	exp_bg.bg_color = Color(0.1, 0.15, 0.2)
	exp_bg.corner_radius_top_left = 4
	exp_bg.corner_radius_top_right = 4
	exp_bg.corner_radius_bottom_left = 4
	exp_bg.corner_radius_bottom_right = 4
	exp_bar.add_theme_stylebox_override("background", exp_bg)
	health_container.add_child(exp_bar)
	
	# Spacer
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 5)
	health_container.add_child(spacer2)
	
	# Wave info
	var wave_label = Label.new()
	wave_label.name = "WaveLabel"
	wave_label.text = "รอบที่: 1/10"
	wave_label.add_theme_font_size_override("font_size", 18)
	wave_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	health_container.add_child(wave_label)
	
	# Time Label
	var time_label = Label.new()
	time_label.name = "TimeLabel"
	time_label.text = "เวลา: 00:00"
	time_label.add_theme_font_size_override("font_size", 18)
	time_label.add_theme_color_override("font_color", Color(0.8, 1, 0.8))
	health_container.add_child(time_label)
	
	# Skill UI (Bottom Center)
	create_skill_ui(hud)

func update_ui():
	var hud = get_node_or_null("HUD")
	if not hud:
		return
	
	# Find health_container inside PanelContainer
	var health_container = null
	for child in hud.get_children():
		if child is PanelContainer:
			for subchild in child.get_children():
				if subchild is VBoxContainer:
					health_container = subchild
					break
			break
	
	if not health_container:
		return
	
	var health_label = health_container.get_node_or_null("HealthLabel")
	var health_bar = health_container.get_node_or_null("HealthBar")
	var exp_label = health_container.get_node_or_null("ExpLabel")
	var exp_bar = health_container.get_node_or_null("ExpBar")
	
	if health_label:
		health_label.text = "HP: %d/%d" % [health, max_health]
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health
	if exp_label:
		exp_label.text = "Level %d - EXP: %d/%d" % [level, experience, exp_to_next_level]
	if exp_bar:
		exp_bar.max_value = exp_to_next_level
		exp_bar.value = experience

func update_wave_ui(current_wave: int, total_waves: int):
	var hud = get_node_or_null("HUD")
	if not hud:
		return
	
	# Find health_container inside PanelContainer where WaveLabel resides
	var health_container = null
	for child in hud.get_children():
		if child is PanelContainer:
			for subchild in child.get_children():
				if subchild is VBoxContainer:
					health_container = subchild
					break
			break
	
	if not health_container:
		return
		
	var wave_label = health_container.get_node_or_null("WaveLabel")
	if wave_label:
		wave_label.text = "รอบที่: %d/%d" % [current_wave, total_waves]

func get_formatted_time() -> String:
	var minutes = int(elapsed_time) / 60
	var seconds = int(elapsed_time) % 60
	return "%02d:%02d" % [minutes, seconds]

func create_skill_ui(hud: CanvasLayer):
	var skill_container = HBoxContainer.new()
	skill_container.name = "SkillContainer"
	skill_container.add_theme_constant_override("separation", 15)
	
	# ตำแหน่ง Bottom Center
	skill_container.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	skill_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	skill_container.grow_vertical = Control.GROW_DIRECTION_BEGIN
	skill_container.offset_bottom = -20 # Margin from bottom
	
	hud.add_child(skill_container)
	
	# สร้าง skill slots (Q, W, E)
	for key in ["Q", "W", "E"]:
		var skill_slot = create_skill_slot(key)
		skill_container.add_child(skill_slot)

func create_skill_slot(key: String) -> Control:
	var slot = Control.new()
	slot.name = "Skill_" + key
	var slot_size = Config.skill_slot_size
	slot.custom_minimum_size = slot_size
	
	# Background
	var bg = ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.2, 0.2, 0.2, 0.8)
	bg.size = slot_size
	slot.add_child(bg)
	
	# Border
	var border = ReferenceRect.new()
	border.border_color = Color(0.5, 0.5, 0.5, 1)
	border.border_width = 3.0
	border.size = slot_size
	slot.add_child(border)
	
	# Key label
	var key_label = Label.new()
	key_label.name = "KeyLabel"
	key_label.text = key
	key_label.add_theme_font_size_override("font_size", 24)
	key_label.position = Vector2(10, 5)
	slot.add_child(key_label)
	
	# Skill name
	var skill_label = Label.new()
	skill_label.name = "SkillLabel"
	skill_label.text = "Locked"
	skill_label.add_theme_font_size_override("font_size", 14)
	skill_label.position = Vector2(10, 35)
	skill_label.modulate = Color(0.6, 0.6, 0.6)
	slot.add_child(skill_label)
	
	# Level indicator
	var level_label = Label.new()
	level_label.name = "LevelLabel"
	level_label.text = ""
	level_label.add_theme_font_size_override("font_size", 16)
	level_label.position = Vector2(10, 70)
	level_label.modulate = Color(1, 1, 0)
	slot.add_child(level_label)
	
	# Cooldown Overlay
	var cd_overlay = ColorRect.new()
	cd_overlay.name = "CDOverlay"
	cd_overlay.color = Config.skill_cd_overlay_color
	cd_overlay.size = slot_size
	cd_overlay.visible = false
	slot.add_child(cd_overlay)
	
	# Cooldown Label
	var cd_label = Label.new()
	cd_label.name = "CDLabel"
	cd_label.text = "0.0"
	cd_label.add_theme_font_size_override("font_size", 30)
	cd_label.add_theme_color_override("font_color", Color(1, 0.8, 0.8))
	cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cd_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cd_label.size = slot_size
	cd_label.visible = false
	slot.add_child(cd_label)
	
	return slot

func update_skill_ui():
	var hud = get_node_or_null("HUD")
	if not hud:
		return
	
	var skill_container = hud.get_node_or_null("SkillContainer")
	if not skill_container:
		return
	
	for key in ["Q", "W", "E"]:
		var slot = skill_container.get_node_or_null("Skill_" + key)
		if not slot:
			continue
		
		var skill = skills[key]
		var skill_label = slot.get_node_or_null("SkillLabel")
		var level_label = slot.get_node_or_null("LevelLabel")
		var bg = slot.get_node_or_null("Background")
		var border = slot.get_node_or_null("Border")
		
		if skill.unlocked:
			# Unlocked
			if skill_label:
				skill_label.text = skill.name
				skill_label.modulate = Color(1, 1, 1)
			if level_label:
				level_label.text = "Lv.%d/%d" % [skill.level, skill.max_level]
			if bg:
				bg.color = Color(0.3, 0.5, 0.7, 0.9)
			if border and border is ReferenceRect:
				border.border_color = Color(0, 1, 1)
		else:
			# Locked
			if skill_label:
				skill_label.text = "ล็อค"
				skill_label.modulate = Color(0.6, 0.6, 0.6)
			if level_label:
				level_label.text = ""
			if bg:
				bg.color = Color(0.2, 0.2, 0.2, 0.8)
			if border and border is ReferenceRect:
				border.border_color = Color(0.5, 0.5, 0.5)

func connect_to_spawner():
	# เชื่อมต่อ signal กับ EnemySpawner
	var spawner = get_tree().get_first_node_in_group("enemy_spawner")
	if spawner:
		if not spawner.wave_started.is_connected(_on_wave_started):
			spawner.wave_started.connect(_on_wave_started)

func update_skill_cooldowns():
	var hud = get_node_or_null("HUD")
	if not hud: return
	var container = hud.get_node_or_null("SkillContainer")
	if not container: return
	
	for weapon in weapons:
		var key = ""
		if weapon.trigger_key == "Skill1": key = "Q"
		elif weapon.trigger_key == "Skill2": key = "W"
		elif weapon.trigger_key == "Skill3": key = "E"
		
		if key != "":
			var slot = container.get_node_or_null("Skill_" + key)
			if slot:
				var overlay = slot.get_node_or_null("CDOverlay")
				var label = slot.get_node_or_null("CDLabel")
				if overlay and label:
					if weapon.timer > 0:
						overlay.visible = true
						label.visible = true
						label.text = "%.1f" % weapon.timer
					else:
						overlay.visible = false
						label.visible = false

func _on_wave_started(wave_number: int):
	# อัปเดต Wave UI เมื่อเวฟเริ่ม
	var spawner = get_tree().get_first_node_in_group("enemy_spawner")
	if spawner:
		update_wave_ui(wave_number, spawner.total_waves)

func _process(delta):
	# Check for pause toggle (ESC key)
	if Input.is_action_just_pressed("ui_cancel"):
		toggle_pause_menu()
	
	if not game_paused:
		elapsed_time += delta
		update_skill_cooldowns()
		
		# Update Time UI periodically (every frame is fine for local string op)
		var hud = get_node_or_null("HUD")
		if hud:
			# Traverse to find TimeLabel (using same logic as update_wave_ui)
			var health_container = null
			for child in hud.get_children():
				if child is PanelContainer:
					for subchild in child.get_children():
						if subchild is VBoxContainer:
							health_container = subchild
							break
					break
			if health_container:
				var time_label = health_container.get_node_or_null("TimeLabel")
				if time_label:
					time_label.text = "เวลา: " + get_formatted_time()
		
		global_position = get_global_mouse_position()
		pull_nearby_exp()
		
		# Manual shooting
		manual_shoot_timer -= get_process_delta_time()
		if Input.is_action_pressed("attack") and manual_shoot_timer <= 0:
			manual_shoot()

func _on_window_focus_exited():
	if not game_paused:
		toggle_pause_menu()

func _on_window_mouse_exited():
	if not game_paused:
		toggle_pause_menu()

func toggle_pause_menu():
	if pause_ui:
		# Resume game
		pause_ui.queue_free()
		pause_ui = null
		resume_game()
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	else:
		# Show pause menu
		show_pause_menu()

func show_pause_menu():
	pause_game()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	pause_ui = Control.new()
	pause_ui.name = "PauseUI"
	pause_ui.z_index = 250
	get_node("HUD").add_child(pause_ui)
	
	# Dark overlay
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.8)
	bg.size = get_viewport().get_visible_rect().size
	pause_ui.add_child(bg)
	
	# Pause panel
	var panel = PanelContainer.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.12, 0.18, 0.95)
	panel_style.corner_radius_top_left = 20
	panel_style.corner_radius_top_right = 20
	panel_style.corner_radius_bottom_left = 20
	panel_style.corner_radius_bottom_right = 20
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_width_top = 3
	panel_style.border_width_bottom = 3
	panel_style.border_color = Color(0.4, 0.5, 0.7)
	panel_style.content_margin_left = 40
	panel_style.content_margin_right = 40
	panel_style.content_margin_top = 30
	panel_style.content_margin_bottom = 30
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.position = Vector2(get_viewport().get_visible_rect().size.x / 2 - 150, get_viewport().get_visible_rect().size.y / 2 - 150)
	pause_ui.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "⏸️ หยุดชั่วคราว"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Resume button
	var resume_btn = create_menu_button("▶️ เล่นต่อ", Color(0.2, 0.5, 0.3))
	resume_btn.pressed.connect(func():
		toggle_pause_menu()
	)
	vbox.add_child(resume_btn)
	
	# Restart button
	var restart_btn = create_menu_button("🔄 เริ่มใหม่", Color(0.4, 0.4, 0.2))
	restart_btn.pressed.connect(func():
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		get_tree().paused = false
		get_tree().reload_current_scene()
	)
	vbox.add_child(restart_btn)
	
	# Quit button
	var quit_btn = create_menu_button("🚪 กลับเมนูหลัก", Color(0.5, 0.2, 0.2))
	quit_btn.pressed.connect(func():
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		get_tree().paused = false
		get_tree().change_scene_to_file("res://menu/home_menu.tscn")
	)
	vbox.add_child(quit_btn)

func create_menu_button(text: String, color: Color) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(220, 50)
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = color
	btn_style.corner_radius_top_left = 10
	btn_style.corner_radius_top_right = 10
	btn_style.corner_radius_bottom_left = 10
	btn_style.corner_radius_bottom_right = 10
	button.add_theme_stylebox_override("normal", btn_style)
	
	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = color.lightened(0.2)
	btn_hover.corner_radius_top_left = 10
	btn_hover.corner_radius_top_right = 10
	btn_hover.corner_radius_bottom_left = 10
	btn_hover.corner_radius_bottom_right = 10
	btn_hover.border_width_left = 2
	btn_hover.border_width_right = 2
	btn_hover.border_width_top = 2
	btn_hover.border_width_bottom = 2
	btn_hover.border_color = Color(1, 1, 1, 0.5)
	button.add_theme_stylebox_override("hover", btn_hover)
	
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color(1, 1, 1))
	
	return button

func add_weapon(type: String, cooldown: float, damage: int, weapon_name: String, trigger_key: String = ""):
	# ตรวจสอบว่ามีอาวุธนี้แล้วหรือไม่
	for weapon in weapons:
		if weapon.weapon_name == weapon_name:
			weapon.level += 1
			weapon.damage = int(weapon.damage * 1.3)
			weapon.cooldown = max(0.3, weapon.cooldown * 0.9)
			print("%s upgraded to level %d!" % [weapon_name, weapon.level])
			return
	
	var weapon = {
		"type": type,
		"cooldown": cooldown,
		"damage": damage,
		"timer": 0.0,
		"level": 1,
		"weapon_name": weapon_name,
		"trigger_key": trigger_key
	}
	weapons.append(weapon)
	print("New weapon: %s" % weapon_name)

func _physics_process(delta):
	if game_paused:
		return
	
	# อัปเดตกระสุนทั้งหมด
	update_projectiles(delta)
	
	# ยิงอาวุธ
	for weapon in weapons:
		weapon.timer -= delta
		
		# Check trigger
		if weapon.timer <= 0:
			if weapon.trigger_key != "":
				# Active Skill: Fire only when pressed
				if Input.is_action_just_pressed(weapon.trigger_key):
					fire_weapon(weapon)
					weapon.timer = weapon.cooldown
			else:
				# Auto-fire
				fire_weapon(weapon)
				weapon.timer = weapon.cooldown

func update_projectiles(delta):
	var projectiles = get_tree().get_nodes_in_group("projectile")
	for proj in projectiles:
		var speed = proj.get_meta("speed")
		var direction = Vector2.ZERO
		
		# Homing movement / Update direction
		if proj.has_meta("target"):
			var target = proj.get_meta("target")
			if target and is_instance_valid(target):
				direction = (target.global_position - proj.global_position).normalized()
				proj.set_meta("direction", direction) # Update stored direction
			elif proj.has_meta("direction"):
				direction = proj.get_meta("direction") # Continue in last known direction
		
		# Non-homing movement (Straight line)
		elif proj.has_meta("direction"):
			direction = proj.get_meta("direction")
			
		if direction != Vector2.ZERO:
			proj.global_position += direction * speed * delta
			proj.rotation = direction.angle()

func _on_projectile_hit(body: Node2D, projectile: Area2D):
	if not is_instance_valid(projectile):
		return
		
	if body.is_in_group("enemy") and body.has_method("take_damage"):
		body.take_damage(projectile.get_meta("damage"))
		projectile.queue_free()

func fire_weapon(weapon: Dictionary):
	match weapon.type:
		"projectile":
			var q_cfg = Config.skills["Q"]
			var w_cfg = Config.skills["W"]
			var tex = q_cfg.texture_path
			var s_val = q_cfg.scale
			if weapon.weapon_name == w_cfg.name:
				tex = w_cfg.texture_path
				s_val = w_cfg.scale
			var scale_mult = Vector2(s_val, s_val)
			shoot_projectile(weapon.damage, tex, Vector2.ZERO, scale_mult)
		"laser":
			shoot_laser(weapon.damage)
		"shield":
			activate_shield(weapon)
		"orbiting":
			create_orbit(weapon.damage)

func shoot_projectile(damage: int, texture_path: String, force_direction: Vector2 = Vector2.ZERO, custom_scale: Vector2 = Vector2(0.8, 0.8)):
	var nearest_enemy = find_nearest_enemy()
	
	if nearest_enemy == null and force_direction == Vector2.ZERO:
		# If no enemy and no forced direction (auto-shoot), don't shoot
		return
	
	var projectile = Area2D.new()
	projectile.name = "Projectile"
	
	# สร้าง sprite
	var sprite = Sprite2D.new()
	var texture = load(texture_path)
	if texture:
		sprite.texture = texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST # Pixel art style
		sprite.scale = custom_scale
	else:
		var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color.YELLOW)
		sprite.texture = ImageTexture.create_from_image(img)
	projectile.add_child(sprite)
	
	# สร้าง collision
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 8
	collision.shape = shape
	projectile.add_child(collision)
	
	# ตั้งค่าตำแหน่ง
	projectile.global_position = global_position
	
	# เพิ่ม properties ลงใน projectile
	if nearest_enemy:
		projectile.set_meta("target", nearest_enemy)
		projectile.set_meta("direction", (nearest_enemy.global_position - global_position).normalized())
	elif force_direction != Vector2.ZERO:
		projectile.set_meta("direction", force_direction)
		
	projectile.set_meta("damage", damage)
	projectile.set_meta("speed", 500.0)
	projectile.set_meta("lifetime", 5.0)
	projectile.add_to_group("projectile")
	
	get_parent().add_child(projectile)
	
	# เชื่อมต่อ signal สำหรับชน
	projectile.body_entered.connect(_on_projectile_hit.bind(projectile))
	
	# ลบกระสุนหลังหมดอายุ
	get_tree().create_timer(projectile.get_meta("lifetime")).timeout.connect(projectile.queue_free)

func shoot_laser(damage: int):
	var enemies = get_tree().get_nodes_in_group("enemy")
	if enemies.is_empty():
		return
	
	var nearest = find_nearest_enemy()
	if nearest and nearest.has_method("take_damage"):
		nearest.take_damage(damage)
		create_laser_visual(nearest.global_position)

func create_laser_visual(target_pos: Vector2):
	var line = Line2D.new()
	line.add_point(global_position)
	line.add_point(target_pos)
	line.width = 3
	line.default_color = Color(0, 1, 1)
	get_parent().add_child(line)
	
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(line):
		line.queue_free()

func activate_shield(weapon: Dictionary):
	var shield_name = "ActiveShield"
	var existing = get_node_or_null(shield_name)
	if existing:
		existing.queue_free()
	
	var shield = Area2D.new()
	shield.name = shield_name
	
	# Visual (Blue spinning energy)
	var sprite = Sprite2D.new()
	var s_cfg = Config.skills["E"]
	var tex = load(s_cfg.texture_path)
	if not tex:
		# Fallback: Try loading from file system directly
		var img = Image.load_from_file(s_cfg.texture_path)
		if img:
			tex = ImageTexture.create_from_image(img)
			
	if tex:
		sprite.texture = tex
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	else:
		# Fallback color
		var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
		img.fill(Color.BLUE)
		sprite.texture = ImageTexture.create_from_image(img)
		
	sprite.modulate = Color(1, 1, 1, 0.9) # White transparent (Native color)
	
	var radius = s_cfg.visual_radius
	if sprite.texture:
		var s_size = sprite.texture.get_size()
		# Match diameter
		var s_scale = (radius * 2.0) / max(s_size.x, s_size.y)
		sprite.scale = Vector2(s_scale, s_scale)
	else:
		sprite.scale = Vector2(3, 3)

	shield.z_index = 10 # Ensure on top
	shield.add_child(sprite)
	
	# Collision
	var shape = CircleShape2D.new()
	shape.radius = radius
	var coll = CollisionShape2D.new()
	coll.shape = shape
	shield.add_child(coll)
	
	add_child(shield)
	
	# Duration logic: 0.5s per level (0.5, 1.0, 1.5...)
	var duration = s_cfg.base_duration * float(weapon.level)
	
	# Animation (Spin)
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(sprite, "rotation", TAU, 1.0).as_relative()
	
	# Timer to destroy
	get_tree().create_timer(duration).timeout.connect(shield.queue_free)
	
	# Damage logic (Damage over time or on entry)
	# On entry
	shield.body_entered.connect(_on_shield_hit.bind(weapon.damage))
	
	print("Shield Activate! Level: %d, Duration: %.1f s" % [weapon.level, duration])

func create_orbit(_damage: int):
	pass

func find_nearest_enemy() -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemy")
	var nearest = null
	var min_distance = INF
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var distance = global_position.distance_to(enemy.global_position)
		if distance < min_distance:
			min_distance = distance
			nearest = enemy
	
	return nearest

func pull_nearby_exp():
	var exps = get_tree().get_nodes_in_group("exp")
	for exp_orb in exps:
		if not is_instance_valid(exp_orb):
			continue
		var distance = global_position.distance_to(exp_orb.global_position)
		if distance < pickup_range:
			var direction = (global_position - exp_orb.global_position).normalized()
			exp_orb.global_position += direction * 300 * get_process_delta_time()

func manual_shoot():
	manual_shoot_timer = manual_shoot_cooldown
	
	var nearest = find_nearest_enemy()
	if nearest:
		shoot_projectile(20, "res://img/maled_malakor.png", Vector2.ZERO, Vector2(0.8, 0.8)) # Normal small size
	else:
		# Shoot in random direction if no enemy
		var rand_dir = Vector2.RIGHT.rotated(randf() * TAU)
		shoot_projectile(20, "res://img/maled_malakor.png", rand_dir, Vector2(0.8, 0.8)) # Normal small size

func gain_exp(amount: int):
	experience += amount
	print("Gained %d EXP. Total: %d/%d" % [amount, experience, exp_to_next_level])
	exp_gained.emit(amount)
	update_ui() # อัปเดต UI ทันทีที่ได้ EXP
	
	if experience >= exp_to_next_level:
		level_up_player()

func level_up_player():
	level += 1
	experience -= exp_to_next_level
	exp_to_next_level = int(exp_to_next_level * 1.5)
	level_up.emit(level)
	update_ui()

func _on_level_up(_new_level: int):
	pause_game()
	show_upgrade_menu()

func show_upgrade_menu():
	if upgrade_ui:
		upgrade_ui.queue_free()
	
	upgrade_ui = Control.new()
	upgrade_ui.name = "UpgradeUI"
	upgrade_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	upgrade_ui.z_index = 200
	get_node("HUD").add_child(upgrade_ui)
	
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.size = get_viewport().get_visible_rect().size
	upgrade_ui.add_child(bg)
	
	# Container
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	upgrade_ui.add_child(center)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "⚡ เลเวลอัพ! ⚡"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var subtitle = Label.new()
	subtitle.text = "เลือกรางวัล:"
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)
	
	# Upgrade options
	var options = get_upgrade_options()
	for i in range(options.size()):
		var button = Button.new()
		button.text = options[i].name + "\n" + options[i].description
		button.custom_minimum_size = Vector2(400, 90)
		
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
		
		var btn_pressed = StyleBoxFlat.new()
		btn_pressed.bg_color = Color(0.1, 0.3, 0.5, 0.95)
		btn_pressed.corner_radius_top_left = 12
		btn_pressed.corner_radius_top_right = 12
		btn_pressed.corner_radius_bottom_left = 12
		btn_pressed.corner_radius_bottom_right = 12
		button.add_theme_stylebox_override("pressed", btn_pressed)
		
		button.add_theme_font_size_override("font_size", 18)
		button.add_theme_color_override("font_color", Color(1, 1, 1))
		
		var option = options[i]
		button.pressed.connect(apply_upgrade.bind(option))
		vbox.add_child(button)

func get_upgrade_options() -> Array:
	var options = []
	
	# เช็คว่ามี skill ที่ยังไม่ unlock หรือไม่
	var locked_skills = []
	for key in ["Q", "W", "E"]:
		if not skills[key].unlocked:
			locked_skills.append(key)
	
	# เช็คว่ามี skill ที่ unlock แล้วแต่ยังไม่ max level
	var upgradeable_skills = []
	for key in ["Q", "W", "E"]:
		if skills[key].unlocked and skills[key].level < skills[key].max_level:
			upgradeable_skills.append(key)
	
	# ถ้ายังมี skill ที่ไม่ unlock ให้เสนอ unlock
	if locked_skills.size() > 0:
		for key in locked_skills:
			options.append({
				"name": "🔓 ปลดล็อค: " + skills[key].name,
				"description": "ปลดล็อคสกิล " + key,
				"type": "unlock_skill",
				"skill_key": key
			})
	
	# ถ้า unlock ครบแล้ว ให้เสนอ upgrade skill
	if locked_skills.size() == 0:
		all_skills_unlocked = true
		for key in upgradeable_skills:
			options.append({
				"name": "⬆️ " + skills[key].name + " Lv.%d→%d" % [skills[key].level, skills[key].level + 1],
				"description": "อัพเกรดสกิล " + key,
				"type": "upgrade_skill",
				"skill_key": key
			})
	
	# เพิ่ม option อื่นๆ
	options.append({
		"name": "❤️ ฟื้นฟู",
		"description": "ฟื้นฟูเลือด 30 หน่วย",
		"type": "heal"
	})
	
	options.append({
		"name": "📈 เลือดสูงสุด+",
		"description": "เพิ่มเลือดสูงสุด 20",
		"type": "stat_boost",
		"stat": "max_health"
	})
	
	options.append({
		"name": "🧲 แม่เหล็ก+",
		"description": "เพิ่มระยะเก็บของ",
		"type": "stat_boost",
		"stat": "pickup_range"
	})
	
	options.shuffle()
	return options.slice(0, 3)

func apply_upgrade(option: Dictionary):
	match option.type:
		"unlock_skill":
			unlock_skill(option.skill_key)
		"upgrade_skill":
			upgrade_skill(option.skill_key)
		"weapon_upgrade":
			add_weapon("projectile", 1.5, 15, option.weapon)
		"new_weapon":
			add_weapon(option.weapon_type, 2.0, 25, option.weapon_name)
		"heal":
			health = min(health + Config.heal_amount, max_health)
		"stat_boost":
			match option.stat:
				"max_health":
					max_health += Config.stat_boost_max_health
					health += Config.stat_boost_max_health
				"pickup_range":
					pickup_range += Config.stat_boost_pickup_range
	
	update_ui()
	update_skill_ui()
	resume_game()
	if upgrade_ui:
		upgrade_ui.queue_free()
		upgrade_ui = null

func unlock_skill(key: String):
	skills[key].unlocked = true
	skills[key].level = 1
	
	print("Unlocked skill: %s" % skills[key].name)
	
	# เพิ่มอาวุธตาม skill
	var s_cfg = Config.skills[key]
	add_weapon(s_cfg.type, s_cfg.cooldown, s_cfg.damage, s_cfg.name, s_cfg.trigger)

func upgrade_skill(key: String):
	if skills[key].level < skills[key].max_level:
		skills[key].level += 1
		print("Upgraded %s to level %d" % [skills[key].name, skills[key].level])
		
		# เพิ่มพลังให้อาวุธที่เกี่ยวข้อง
		var s_cfg = Config.skills[key]
		if key == "E":
			max_health += Config.stat_boost_max_health
			health += Config.stat_boost_max_health
		else:
			add_weapon(s_cfg.type, s_cfg.cooldown, s_cfg.damage, s_cfg.name)

func take_damage(amount: int):
	if god_mode:
		return
	health -= amount
	print("Player took %d damage. HP: %d/%d" % [amount, health, max_health])
	health_changed.emit(health, max_health)
	update_ui() # อัปเดต UI ทันทีที่โดนดาเมจ
	flash_damage()
	
	if health <= 0:
		die()

func flash_damage():
	if cursor_sprite:
		cursor_sprite.modulate = Color(1, 0.3, 0.3)
		await get_tree().create_timer(0.1).timeout
		if cursor_sprite and is_instance_valid(cursor_sprite):
			cursor_sprite.modulate = Color(1, 1, 1)

func die():
	print("Game Over!")
	pause_game()
	
	# แสดง cursor ปกติของระบบกลับมา
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	show_game_over()

func show_game_over():
	var game_over_ui = Control.new()
	game_over_ui.name = "GameOverUI"
	game_over_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_over_ui.z_index = 300
	get_node("HUD").add_child(game_over_ui)
	
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0, 0, 0.9)
	bg.size = get_viewport().get_visible_rect().size
	game_over_ui.add_child(bg)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_over_ui.add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 30)
	center.add_child(vbox)
	
	var label = Label.new()
	label.text = "💀 จบเกม 💀"
	label.add_theme_font_size_override("font_size", 60)
	label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)
	
	var score_label = Label.new()
	var diff_name = "Unknown"
	if has_node("/root/GameSettings"):
		diff_name = GameSettings.get_difficulty_name()
	score_label.text = "เลเวลที่ทำได้: %d\nเวลา: %s\nความยาก: %s" % [level, get_formatted_time(), diff_name]
	score_label.add_theme_font_size_override("font_size", 30)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(score_label)
	
	# Restart button
	var restart_btn = create_menu_button("🔄 Restart Game", Color(0.4, 0.4, 0.2))
	restart_btn.custom_minimum_size = Vector2(300, 60)
	restart_btn.pressed.connect(func():
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		get_tree().paused = false # Ensure unpause before reload
		get_tree().reload_current_scene()
	)
	vbox.add_child(restart_btn)
	
	# Quit button
	var quit_btn = create_menu_button("🚪 Quit to Menu", Color(0.5, 0.2, 0.2))
	quit_btn.custom_minimum_size = Vector2(300, 60)
	quit_btn.pressed.connect(func():
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		get_tree().paused = false
		get_tree().change_scene_to_file("res://menu/home_menu.tscn")
	)
	vbox.add_child(quit_btn)

func _on_body_entered(body):
	if body.is_in_group("enemy"):
		take_damage(10)

func _on_area_entered(area):
	if area.is_in_group("exp"):
		var exp_value = area.get_meta("exp_value", 1) # ใช้ get_meta แทน
		gain_exp(exp_value)
		area.queue_free()

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		# F-Key Cheats
		match event.keycode:
			KEY_F1:
				toggle_god_mode()
			KEY_F2:
				cheat_level_up()
			KEY_F3:
				cheat_kill_all()
			KEY_F4:
				cheat_heal()
		
		# GTA Style Typing Cheats
		var key_str = OS.get_keycode_string(event.keycode).to_upper()
		if key_str.length() == 1 and key_str >= "A" and key_str <= "Z":
			cheat_buffer += key_str
			if cheat_buffer.length() > 20:
				cheat_buffer = cheat_buffer.substr(cheat_buffer.length() - 20)
			check_cheats()

func check_cheats():
	var codes = Config.cheat_codes
	if cheat_buffer.ends_with("HESOYAM"):
		cheat_heal()
		show_cheat_msg("CHEAT ACTIVATED: HESOYAM")
		cheat_buffer = ""
	elif cheat_buffer.ends_with("BAGUVIX"):
		toggle_god_mode()
		show_cheat_msg("CHEAT ACTIVATED: BAGUVIX")
		cheat_buffer = ""
	elif cheat_buffer.ends_with("UZUMYMW"):
		cheat_level_up()
		show_cheat_msg("CHEAT ACTIVATED: UZUMYMW")
		cheat_buffer = ""
	elif cheat_buffer.ends_with("AEZAKMI"):
		cheat_kill_all()
		show_cheat_msg("CHEAT ACTIVATED: AEZAKMI")
		cheat_buffer = ""

func toggle_god_mode():
	god_mode = not god_mode
	print("GOD MODE: ", god_mode)
	if god_mode:
		modulate = Config.cheat_indicator_color
	else:
		modulate = Color(1, 1, 1)

func cheat_heal():
	health = max_health
	health_changed.emit(health, max_health)
	update_ui()

func cheat_level_up():
	gain_exp(exp_to_next_level)

func cheat_kill_all():
	get_tree().call_group("enemy", "take_damage", 99999)

func show_cheat_msg(text: String):
	print(text)
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.position = Vector2(20, 20)
	get_node("HUD").add_child(label)
	
	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(label):
		label.queue_free()
func _on_shield_hit(body: Node2D, damage: int):
	if body.is_in_group("enemy") and body.has_method("take_damage"):
		body.take_damage(damage)
		# Knockback
		var dir = (body.global_position - global_position).normalized()
		if "global_position" in body:
			body.global_position += dir * 50
 
