extends Node

# Game Settings - Autoload singleton

enum Difficulty {
	EASY,
	NORMAL,
	HARD
}

var current_difficulty: Difficulty = Difficulty.EASY

# Difficulty multipliers
func get_enemy_health_multiplier() -> float:
	match current_difficulty:
		Difficulty.EASY:
			return 0.7
		Difficulty.NORMAL:
			return 1.0
		Difficulty.HARD:
			return 1.5
	return 1.0

func get_enemy_speed_multiplier() -> float:
	match current_difficulty:
		Difficulty.EASY:
			return 0.8
		Difficulty.NORMAL:
			return 1.0
		Difficulty.HARD:
			return 1.3
	return 1.0

func get_enemy_count_multiplier() -> float:
	match current_difficulty:
		Difficulty.EASY:
			return 0.7
		Difficulty.NORMAL:
			return 1.0
		Difficulty.HARD:
			return 1.5
	return 1.0

func get_spawn_rate_multiplier() -> float:
	match current_difficulty:
		Difficulty.EASY:
			return 1.3 # Slower spawning
		Difficulty.NORMAL:
			return 1.0
		Difficulty.HARD:
			return 0.7 # Faster spawning
	return 1.0

func get_difficulty_name() -> String:
	match current_difficulty:
		Difficulty.EASY:
			return "ง่าย"
		Difficulty.NORMAL:
			return "ปานกลาง"
		Difficulty.HARD:
			return "ยาก"
	return "Unknown"
