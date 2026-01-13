extends Area2D

# --- Stats & Variables ---
@export var health: int = Config.player_health
@export var max_health: int = Config.player_max_health
@export var move_speed: float = Config.player_move_speed
@export var pickup_range: float = Config.player_pickup_range
@export var cursor_texture: Texture2D
@export var cursor_scale: float = 1.0

var experience: int = 0
var level: int = 1
var exp_to_next_level: int = Config.base_exp_needed
var manual_shoot_timer: float = 0.0
var manual_shoot_cooldown: float = Config.skills["Q"].cooldown
var god_mode: bool = false
var cheat_buffer: String = ""
var elapsed_time: float = 0.0
var weapons: Array = []
var skills: Dictionary = {}
var cursor_sprite: Sprite2D
var upgrade_ui: Control = null
var pause_ui: Control = null
var game_paused: bool = false

signal level_up(new_level: int)
signal exp_gained(amount: int)
signal health_changed(current: int, maximum: int)

# --- Initialization ---
func _ready():
	add_to_group("player")
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Setup Skills
	for key in ["Q", "W", "E"]:
		var cfg = Config.skills[key]
		skills[key] = {"name": cfg.name, "unlocked": false, "level": 0, "max_level": cfg.max_level}
	
	setup_cursor()
	create_ui()
	call_deferred("connect_to_spawner")
	get_window().focus_exited.connect(toggle_pause_menu)
	get_window().mouse_exited.connect(toggle_pause_menu)

func setup_cursor():
	cursor_sprite = Sprite2D.new()
	cursor_sprite.z_index = 100
	add_child(cursor_sprite)
	if cursor_texture:
		cursor_sprite.texture = cursor_texture
	else:
		var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for x in 32:
			for y in 32:
				var d = Vector2(x - 16, y - 16).length()
				if d <= 8: img.set_pixel(x, y, Color(0.2, 0.8, 1))
				elif d <= 10: img.set_pixel(x, y, Color(0, 0, 0))
		cursor_sprite.texture = ImageTexture.create_from_image(img)
	cursor_sprite.scale = Vector2(cursor_scale, cursor_scale)

# --- UI Helpers & Creation ---
func add_st(node, bg, radius = 10, border = Color.TRANSPARENT, bw = 0):
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	for side in ["top_left", "top_right", "bottom_left", "bottom_right"]:
		style.set_corner_radius(side, radius)
	if bw > 0:
		style.border_width_left = bw; style.border_width_right = bw
		style.border_width_top = bw; style.border_width_bottom = bw
		style.border_color = border
	node.add_theme_stylebox_override("panel" if node is PanelContainer else "normal", style)
	if node is Button:
		var hover = style.duplicate()
		hover.bg_color = bg.lightened(0.2)
		node.add_theme_stylebox_override("hover", hover)
	return style

func add_lb(parent, text, size = 18, color = Color.WHITE):
	var lb = Label.new()
	lb.text = text
	lb.add_theme_font_size_override("font_size", size)
	lb.add_theme_color_override("font_color", color)
	parent.add_child(lb)
	return lb

func create_ui():
	var hud = CanvasLayer.new(); hud.name = "HUD"; add_child(hud)
	var main = PanelContainer.new(); main.position = Vector2(10, 10)
	add_st(main, Color(0.1, 0.1, 0.15, 0.9), 10, Color(0.3, 0.5, 0.8, 0.8), 2)
	hud.add_child(main)
	
	var vbox = VBoxContainer.new(); main.add_child(vbox)
	vbox.name = "StatsContainer"
	add_lb(vbox, "HP: 100/100", 18, Color(1, 0.3, 0.3)).name = "HealthLabel"
	var hp_bar = ProgressBar.new(); hp_bar.name = "HealthBar"; hp_bar.custom_minimum_size = Vector2(220, 18); hp_bar.show_percentage = false
	add_st(hp_bar, Color(0.9, 0.2, 0.2), 5); vbox.add_child(hp_bar)
	
	add_lb(vbox, "Level 1 - EXP: 0/10", 14, Color(0.3, 0.8, 1)).name = "ExpLabel"
	var exp_bar = ProgressBar.new(); exp_bar.name = "ExpBar"; exp_bar.custom_minimum_size = Vector2(220, 12); exp_bar.show_percentage = false
	add_st(exp_bar, Color(0.2, 0.7, 0.9), 4); vbox.add_child(exp_bar)
	
	add_lb(vbox, "Wave: 1/10", 18, Color(1, 0.9, 0.3)).name = "WaveLabel"
	add_lb(vbox, "Time: 00:00", 18, Color(0.8, 1, 0.8)).name = "TimeLabel"
	
	var skill_box = HBoxContainer.new(); skill_box.name = "SkillContainer"
	skill_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	skill_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	skill_box.offset_bottom = -20
	hud.add_child(skill_box)
	
	for key in ["Q", "W", "E"]:
		var slot = Control.new(); slot.name = "Skill_" + key; slot.custom_minimum_size = Config.skill_slot_size
		var bg = ColorRect.new(); bg.name = "Background"; bg.color = Color(0.2, 0.2, 0.2, 0.8); bg.size = slot.custom_minimum_size; slot.add_child(bg)
		add_lb(slot, key, 24).position = Vector2(10, 5)
		add_lb(slot, "Locked", 14).name = "SkillLabel"; slot.get_node("SkillLabel").position = Vector2(10, 35)
		add_lb(slot, "", 16, Color(1, 1, 0)).name = "LevelLabel"; slot.get_node("LevelLabel").position = Vector2(10, 70)
		var cd = ColorRect.new(); cd.name = "CDOverlay"; cd.color = Config.skill_cd_overlay_color; cd.size = bg.size; cd.visible = false; slot.add_child(cd)
		var cdl = add_lb(slot, "0.0", 30); cdl.name = "CDLabel"; cdl.horizontal_alignment = 1; cdl.vertical_alignment = 1; cdl.size = bg.size; cdl.visible = false
		skill_box.add_child(slot)

# --- Logic & Updates ---
func _process(delta):
	if game_paused: return
	elapsed_time += delta
	global_position = get_global_mouse_position()
	pull_nearby_exp()
	
	var vbox = get_node("HUD/PanelContainer/StatsContainer")
	vbox.get_node("TimeLabel").text = "เวลา: %02d:%02d" % [int(elapsed_time) / 60, int(elapsed_time) % 60]
	
	manual_shoot_timer -= delta
	if Input.is_action_pressed("attack") and manual_shoot_timer <= 0:
		manual_shoot()

func _physics_process(delta):
	if game_paused: return
	update_projectiles(delta)
	for w in weapons:
		w.timer -= delta
		if w.timer <= 0 and (w.trigger_key == "" or Input.is_action_pressed(w.trigger_key)):
			fire_weapon(w)
			w.timer = w.cooldown
	update_skill_cooldown_ui()

func update_ui():
	var vbox = get_node_or_null("HUD/PanelContainer/StatsContainer")
	if not vbox: return
	vbox.get_node("HealthLabel").text = "HP: %d/%d" % [health, max_health]
	vbox.get_node("HealthBar").max_value = max_health
	vbox.get_node("HealthBar").value = health
	vbox.get_node("ExpLabel").text = "Level %d - EXP: %d/%d" % [level, experience, exp_to_next_level]
	vbox.get_node("ExpBar").max_value = exp_to_next_level
	vbox.get_node("ExpBar").value = experience

func update_skill_ui():
	for key in ["Q", "W", "E"]:
		var slot = get_node_or_null("HUD/SkillContainer/Skill_" + key)
		if not slot: continue
		var s = skills[key]
		slot.get_node("SkillLabel").text = s.name if s.unlocked else "ล็อค"
		slot.get_node("LevelLabel").text = "Lv.%d/%d" % [s.level, s.max_level] if s.unlocked else ""
		slot.get_node("Background").color = Color(0.3, 0.5, 0.7, 0.9) if s.unlocked else Color(0.2, 0.2, 0.2, 0.8)

func update_skill_cooldown_ui():
	for w in weapons:
		var key = {"Skill1": "Q", "Skill2": "W", "Skill3": "E"}.get(w.trigger_key, "")
		if key:
			var slot = get_node_or_null("HUD/SkillContainer/Skill_" + key)
			if slot:
				slot.get_node("CDOverlay").visible = w.timer > 0
				slot.get_node("CDLabel").visible = w.timer > 0
				slot.get_node("CDLabel").text = "%.1f" % w.timer

# --- Combat Logic ---
func fire_weapon(w):
	match w.type:
		"projectile":
			var cfg = Config.skills[ {"มะละกอ": "Q", "มะเขีอเทศ": "W"}.get(w.weapon_name, "Q")]
			shoot_projectile(w.damage, cfg.texture_path, Vector2.ZERO, Vector2(cfg.scale, cfg.scale))
		"laser":
			var target = find_nearest_enemy()
			if target: target.take_damage(w.damage); create_laser_visual(target.global_position)
		"shield": activate_shield(w)

func shoot_projectile(damage, tex_path, force_dir = Vector2.ZERO, scale = Vector2(0.8, 0.8)):
	var target = find_nearest_enemy()
	if not target and force_dir == Vector2.ZERO: return
	
	var p = Area2D.new()
	var s = Sprite2D.new(); s.texture = load(tex_path); s.scale = scale; p.add_child(s)
	p.texture_filter = CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	var c = CollisionShape2D.new(); c.shape = CircleShape2D.new(); c.shape.radius = 8; p.add_child(c)
	p.global_position = global_position
	p.set_meta("damage", damage); p.set_meta("speed", 500.0); p.add_to_group("projectile")
	if target: p.set_meta("target", target); p.set_meta("direction", (target.global_position - global_position).normalized())
	else: p.set_meta("direction", force_dir)
	get_parent().add_child(p)
	p.body_entered.connect(func(b): if b.is_in_group("enemy"): b.take_damage(damage); p.queue_free())
	get_tree().create_timer(5.0).timeout.connect(p.queue_free)

func update_projectiles(delta):
	for p in get_tree().get_nodes_in_group("projectile"):
		var dir = p.get_meta("direction")
		if p.has_meta("target") and is_instance_valid(p.get_meta("target")):
			dir = (p.get_meta("target").global_position - p.global_position).normalized()
			p.set_meta("direction", dir)
		p.global_position += dir * p.get_meta("speed") * delta
		p.rotation = dir.angle()

func activate_shield(w):
	if has_node("ActiveShield"): get_node("ActiveShield").queue_free()
	var shield = Area2D.new(); shield.name = "ActiveShield"
	var cfg = Config.skills["E"]; var s = Sprite2D.new(); s.texture = load(cfg.texture_path); shield.add_child(s)
	s.scale = Vector2.ONE * (cfg.visual_radius * 2.0 / s.texture.get_size().x)
	var c = CollisionShape2D.new(); c.shape = CircleShape2D.new(); c.shape.radius = cfg.visual_radius; shield.add_child(c)
	add_child(shield); shield.z_index = 10
	shield.body_entered.connect(func(b): if b.is_in_group("enemy"): b.take_damage(w.damage); b.global_position += (b.global_position - global_position).normalized() * 50)
	create_tween().set_loops().tween_property(s, "rotation", TAU, 1.0).as_relative()
	get_tree().create_timer(cfg.base_duration * w.level).timeout.connect(shield.queue_free)

func manual_shoot():
	manual_shoot_timer = manual_shoot_cooldown
	var target = find_nearest_enemy()
	shoot_projectile(20, "res://img/maled_malakor.png", Vector2.ZERO if target else Vector2.RIGHT.rotated(randf() * TAU))

# --- Progression & Systems ---
func gain_exp(amt):
	experience += amt
	update_ui()
	if experience >= exp_to_next_level:
		level += 1; experience -= exp_to_next_level; exp_to_next_level *= 1.5; level_up.emit(level)

func _on_level_up(_l): pause_game(); show_upgrade_menu()

func show_upgrade_menu():
	upgrade_ui = setup_menu("⚡ เลเวลอัพ! ⚡", "เลือกรางวัล:")
	var vbox = upgrade_ui.get_node("Center/VBox")
	var options = get_upgrade_options()
	for opt in options:
		var btn = Button.new(); btn.text = opt.name + "\n" + opt.description; btn.custom_minimum_size = Vector2(400, 90)
		add_st(btn, Color(0.15, 0.25, 0.4, 0.95), 12, Color(0.4, 0.6, 0.9), 2)
		btn.pressed.connect(apply_upgrade.bind(opt))
		vbox.add_child(btn)

func get_upgrade_options():
	var opts = []
	for key in ["Q", "W", "E"]:
		var s = skills[key]
		if not s.unlocked: opts.append({"name": "🔓 ปลดล็อค: " + s.name, "type": "unlock_skill", "key": key, "description": "ปลดล็อค " + key})
		elif s.level < s.max_level: opts.append({"name": "⬆️ " + s.name + " Lv.%d→%d" % [s.level, s.level + 1], "type": "upgrade_skill", "key": key, "description": "อัพเกรด " + key})
	opts.append({"name": "❤️ ฟื้นฟู", "type": "heal", "description": "ฟื้นฟู 30 HP"})
	opts.append({"name": "📈 เลือดสูงสุด+", "type": "stat_boost", "stat": "max_health", "description": "+20 Max HP"})
	opts.shuffle(); return opts.slice(0, 3)

func apply_upgrade(opt):
	match opt.type:
		"unlock_skill":
			skills[opt.key].unlocked = true; skills[opt.key].level = 1
			var c = Config.skills[opt.key]; add_weapon(c.type, c.cooldown, c.damage, c.name, c.trigger)
		"upgrade_skill":
			skills[opt.key].level += 1
			for w in weapons: if w.weapon_name == skills[opt.key].name: w.damage *= 1.3; w.cooldown = max(0.3, w.cooldown * 0.9)
		"heal": health = min(health + 30, max_health)
		"stat_boost": max_health += 20; health += 20
	update_ui(); update_skill_ui(); resume_game(); upgrade_ui.queue_free(); upgrade_ui = null

func take_damage(amt):
	if god_mode: return
	health -= amt; update_ui(); flash_damage()
	if health <= 0: die()

func flash_damage():
	var t = create_tween(); t.tween_property(cursor_sprite, "modulate", Color(1, 0.3, 0.3), 0.1)
	t.tween_property(cursor_sprite, "modulate", Color.WHITE, 0.1)

func die():
	pause_game(); Input.set_mouse_mode(0); show_game_over()

func show_game_over():
	var ui = setup_menu("💀 จบเกม 💀", "เลเวล: %d\nเวลา: %s" % [level, "%02d:%02d" % [int(elapsed_time) / 60, int(elapsed_time) % 60]])
	var vbox = ui.get_node("Center/VBox")
	var r_btn = create_btn(vbox, "🔄 เริ่มใหม่", Color(0.4, 0.4, 0.2), func(): get_tree().paused = false; get_tree().reload_current_scene())
	var q_btn = create_btn(vbox, "🚪 กลับเมนู", Color(0.5, 0.2, 0.2), func(): get_tree().paused = false; get_tree().change_scene_to_file("res://menu/home_menu.tscn"))

func setup_menu(title_text, sub_text):
	var ui = Control.new(); ui.set_anchors_preset(Control.PRESET_FULL_RECT); ui.z_index = 250; get_node("HUD").add_child(ui)
	var bg = ColorRect.new(); bg.color = Color(0, 0, 0, 0.8); bg.size = get_viewport_rect().size; ui.add_child(bg)
	var center = CenterContainer.new(); center.name = "Center"; center.set_anchors_preset(Control.PRESET_FULL_RECT); ui.add_child(center)
	var vbox = VBoxContainer.new(); vbox.name = "VBox"; center.add_child(vbox)
	add_lb(vbox, title_text, 48, Color(1, 0.9, 0.2)).horizontal_alignment = 1
	add_lb(vbox, sub_text, 24).horizontal_alignment = 1
	return ui

func create_btn(parent, text, color, callback):
	var btn = Button.new(); btn.text = text; btn.custom_minimum_size = Vector2(220, 50)
	add_st(btn, color, 10); btn.pressed.connect(callback); parent.add_child(btn); return btn

# --- Helpers ---
func add_weapon(type, cd, dmg, name, key = ""):
	weapons.append({"type": type, "cooldown": cd, "damage": dmg, "timer": 0.0, "weapon_name": name, "trigger_key": key})

func find_nearest_enemy():
	var near = null; var d_min = INF
	for e in get_tree().get_nodes_in_group("enemy"):
		var d = global_position.distance_to(e.global_position)
		if d < d_min: d_min = d; near = e
	return near

func pull_nearby_exp():
	for e in get_tree().get_nodes_in_group("exp"):
		if global_position.distance_to(e.global_position) < pickup_range:
			e.global_position += (global_position - e.global_position).normalized() * 300 * get_process_delta_time()

func toggle_pause_menu():
	if pause_ui: pause_ui.queue_free(); pause_ui = null; resume_game()
	else:
		pause_game(); pause_ui = setup_menu("⏸️ หยุดชั่วคราว", "")
		create_btn(pause_ui.get_node("Center/VBox"), "▶️ เล่นต่อ", Color(0.2, 0.5, 0.3), toggle_pause_menu)
		create_btn(pause_ui.get_node("Center/VBox"), "🔄 เริ่มใหม่", Color(0.4, 0.4, 0.2), func(): get_tree().paused = false; get_tree().reload_current_scene())
		create_btn(pause_ui.get_node("Center/VBox"), "🚪 กลับเมนู", Color(0.5, 0.2, 0.2), func(): get_tree().paused = false; get_tree().change_scene_to_file("res://menu/home_menu.tscn"))

func pause_game(): game_paused = true; get_tree().paused = true; Input.set_mouse_mode(1)
func resume_game(): game_paused = false; get_tree().paused = false; Input.set_mouse_mode(0)

func connect_to_spawner():
	var s = get_tree().get_first_node_in_group("enemy_spawner")
	if s: s.wave_started.connect(func(w): get_node("HUD/PanelContainer/StatsContainer/WaveLabel").text = "รอบที่: %d/%d" % [w, s.total_waves])

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1: god_mode = !god_mode; modulate = Config.cheat_indicator_color if god_mode else Color.WHITE
		elif event.keycode == KEY_F2: gain_exp(exp_to_next_level)
		elif event.keycode == KEY_F3: get_tree().call_group("enemy", "take_damage", 9999)
		var k = OS.get_keycode_string(event.keycode)
		if k.length() == 1: cheat_buffer = (cheat_buffer + k).right(20); check_cheats()
	if Input.is_action_just_pressed("ui_cancel"): toggle_pause_menu()

func check_cheats():
	if cheat_buffer.ends_with("HESOYAM"): health = max_health; update_ui(); cheat_buffer = ""
	elif cheat_buffer.ends_with("BAGUVIX"): god_mode = !god_mode; modulate = Config.cheat_indicator_color if god_mode else Color.WHITE; cheat_buffer = ""

func create_laser_visual(pos):
	var l = Line2D.new(); l.points = [global_position, pos]; l.width = 3; l.default_color = Color.CYAN; get_parent().add_child(l)
	await get_tree().create_timer(0.1).timeout; l.queue_free()

func _on_body_entered(b): if b.is_in_group("enemy"): take_damage(10)
func _on_area_entered(a): if a.is_in_group("exp"): gain_exp(a.get_meta("exp_value", 1)); a.queue_free()
