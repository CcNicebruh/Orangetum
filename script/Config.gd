extends Node

# --- Player Stats ---
var player_health = 100
var player_max_health = 100
var player_move_speed = 200.0
var player_pickup_range = 150.0

# --- Skills Configuration ---
var skills = {
	"Q": {
		"name": "มะละกอ",
		"type": "projectile",
		"cooldown": 0.1,
		"damage": 15,
		"texture_path": "res://img/malakor.png",
		"scale": 1.5,
		"normal_scale": 0.8,
		"trigger": "Skill1",
		"max_level": 5
	},
	"W": {
		"name": "มะเขีอเทศ",
		"type": "projectile",
		"cooldown": 0.1,
		"damage": 25,
		"texture_path": "res://img/ma_kier_ted.png",
		"scale": 0.8,
		"trigger": "Skill2",
		"max_level": 5
	},
	"E": {
		"name": "น้ำปลาร้าตราแม่ประนอม",
		"type": "shield",
		"cooldown": 15.0,
		"damage": 10,
		"base_duration": 0.5,
		"texture_path": "res://img/mae_pra_nom.png",
		"visual_radius": 90.0,
		"trigger": "Skill3",
		"max_level": 5
	}
}

# --- Upgrades & Leveling ---
var base_exp_needed = 10
var heal_amount = 30
var stat_boost_max_health = 20
var stat_boost_pickup_range = 50

# --- Visuals & UI ---
var cheat_indicator_color = Color(1, 1, 0.5)
var skill_slot_size = Vector2(100, 100)
var skill_cd_overlay_color = Color(0, 0, 0, 0.7)

# --- Cheat Codes ---
var cheat_codes = {
	"HESOYAM": "health",
	"BAGUVIX": "god_mode",
	"UZUMYMW": "level_up",
	"AEZAKMI": "kill_all"
}
