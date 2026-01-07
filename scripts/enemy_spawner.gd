extends Node2D

# ==========================
# --- Spawner Toggle ---
# ==========================
@export var spawner_enabled: bool = true   # Set to false to completely disable all spawning

# ==========================
# --- Enemy Groups ---
# ==========================
@export var enemy1_group: Array[PackedScene] = []        # Enemies that spawn in waves randomly in the area
@export var stationary_enemies: Array[PackedScene] = [] # Enemies that spawn in corners (e.g., turrets)
@export var moving_enemies: Array[PackedScene] = []     # Enemies that move individually

# ==========================
# --- Portal Settings ---
# ==========================
@export var portal_animation: String = "spawn"
@export var spawn_delay: float = 0.5       # Time portal is visible before spawning enemy
@export var portal_despawn: float = 0.5    # Time portal fades out after enemy spawns
@export var fly_out_distance: float = 80   # How far enemies move on spawn
@export var fly_out_direction: Vector2 = Vector2(-1, 0)
@export var fly_out_duration: float = 0.3

# ==========================
# --- Enemy1 Wave Settings ---
# ==========================
@export var wave_delay_min: float = 10.0
@export var wave_delay_max: float = 15.0
@export var spawn_interval_min: float = 0.2
@export var spawn_interval_max: float = 0.5

# ==========================
# --- Stationary Enemy Settings ---
# ==========================
@export var big_turret_spawn_chance: float = 15.0        # Percent chance to spawn special turret
@export var stationary_wave_delay_min: float = 10.0      # Min delay between stationary enemy waves
@export var stationary_wave_delay_max: float = 12.0      # Max delay between stationary enemy waves

# ==========================
# --- Nodes ---
# ==========================
@onready var template_portal: AnimatedSprite2D = $Portal
@onready var spawn_shape: CollisionShape2D = $SpawnArea/CollisionShape2D

# ==========================
# --- Ready Function ---
# ==========================
func _ready() -> void:
    randomize()
    template_portal.visible = false

    # Start spawning loops for each enemy group
    call_deferred("_start_enemy1_waves")
    call_deferred("_spawn_stationary_enemy_waves")
    call_deferred("_spawn_moving_enemies")

# ==========================
# --- Enemy1 Wave Loop ---
# ==========================
func _start_enemy1_waves() -> void:
    while enemy1_group.size() > 0 and spawner_enabled:
        var enemy_scene = enemy1_group[randi() % enemy1_group.size()]

        # Spawn 2–4 enemies per wave with a small delay between each
        for i in range(randi_range(2, 4)):
            if not spawner_enabled:
                return
            call_deferred("_spawn_enemy_with_portal", enemy_scene)
            await get_tree().create_timer(randf_range(0.1, 0.3)).timeout

        # Wait for next wave
        await get_tree().create_timer(randf_range(wave_delay_min, wave_delay_max)).timeout

# ==========================
# --- Stationary Enemy Waves ---
# ==========================
func _spawn_stationary_enemy_waves() -> void:
    if stationary_enemies.size() == 0:
        return

    var rect = spawn_shape.shape as RectangleShape2D
    var corner_area_size = Vector2(50, 50)  # Random spawn area around corners

    while spawner_enabled:
        # Spawn enemies in top-right and bottom-right corners
        var top_right = spawn_shape.global_position + Vector2(rect.extents.x - corner_area_size.x / 2, -rect.extents.y + corner_area_size.y / 2)
        var bottom_right = spawn_shape.global_position + Vector2(rect.extents.x - corner_area_size.x / 2, rect.extents.y - corner_area_size.y / 2)

        await _spawn_stationary_enemy_at_corner(top_right, corner_area_size)
        await _spawn_stationary_enemy_at_corner(bottom_right, corner_area_size)

        # Wait configurable time before next stationary wave
        await get_tree().create_timer(randf_range(stationary_wave_delay_min, stationary_wave_delay_max)).timeout

# ---------------- Stationary Enemy Spawn Helper ----------------
func _spawn_stationary_enemy_at_corner(center: Vector2, area_size: Vector2) -> void:
    if not spawner_enabled:
        return
    var pos = center + Vector2(randf_range(-area_size.x/2, area_size.x/2), randf_range(-area_size.y/2, area_size.y/2))

    # Choose special turret or normal stationary enemy
    var enemy_scene = preload("res://Scenes/enemy_2.tscn") if randi_range(0, 99) < big_turret_spawn_chance else stationary_enemies[randi() % stationary_enemies.size()]

    await _spawn_enemy_with_portal_at_position(enemy_scene, pos)

# ==========================
# --- Moving Enemies ---
# ==========================
func _spawn_moving_enemies() -> void:
    for enemy_scene in moving_enemies:
        if not spawner_enabled:
            return
        await get_tree().create_timer(randf_range(spawn_interval_min, spawn_interval_max)).timeout
        await _spawn_enemy_with_portal(enemy_scene)

# ==========================
# --- Random Spawn Position ---
# ==========================
func _get_random_spawn_position() -> Vector2:
    var rect = spawn_shape.shape as RectangleShape2D
    return spawn_shape.global_position + Vector2(randf_range(-rect.extents.x, rect.extents.x), randf_range(-rect.extents.y, rect.extents.y))

# ==========================
# --- Spawn Enemy with Portal ---
# ==========================
func _spawn_enemy_with_portal(enemy_scene: PackedScene) -> void:
    if not spawner_enabled:
        return
    await _spawn_enemy_with_portal_at_position(enemy_scene, _get_random_spawn_position())

func _spawn_enemy_with_portal_at_position(enemy_scene: PackedScene, pos: Vector2) -> void:
    if not spawner_enabled:
        return

    var container = Node2D.new()
    add_child(container)
    container.global_position = pos

    # Duplicate portal and animate fade-in
    var portal = template_portal.duplicate() as AnimatedSprite2D
    container.add_child(portal)
    portal.position = Vector2.ZERO
    portal.visible = true
    portal.modulate.a = 0.0
    portal.animation = portal_animation
    portal.play()
    await portal.create_tween().tween_property(portal, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).finished

    # Wait before spawning enemy
    await get_tree().create_timer(spawn_delay).timeout

    # Spawn the enemy at portal position
    var enemy = enemy_scene.instantiate()
    enemy.global_position = portal.global_position
    get_tree().current_scene.add_child(enemy)

    # Optional fly-out effect
    if fly_out_distance > 0:
        var target_pos = enemy.global_position + fly_out_direction.normalized() * fly_out_distance
        await enemy.create_tween().tween_property(enemy, "global_position", target_pos, fly_out_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).finished

    # Fade out portal and remove container
    await portal.create_tween().tween_property(portal, "modulate:a", 0.0, portal_despawn).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).finished
    container.queue_free()
