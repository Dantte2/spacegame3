extends Node2D

@onready var spawner = get_parent()

# ==========================
# --- Enemy Unlock Times ---
# ==========================
# Each index corresponds to an enemy (0 = Enemy1, 1 = Enemy2, etc.)
@export var enemy_unlock_times: Array[float] = [0, 5, 10, 15, 10, 0]  # seconds

func _ready():
    # Start a coroutine for each enemy
    for i in enemy_unlock_times.size():
        start_unlock_enemy(i, enemy_unlock_times[i])

# Separate function to unlock enemy after delay
func start_unlock_enemy(enemy_index: int, delay_time: float) -> void:
    await get_tree().create_timer(delay_time).timeout
    spawner.enemy_enabled[enemy_index] = true
