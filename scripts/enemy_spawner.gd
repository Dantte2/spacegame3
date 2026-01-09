extends Node2D

# ==========================
# --- Spawner Toggle ---
# ==========================
@export var spawner_enabled := true

# ==========================
# --- Enemy Scenes ---
# ==========================
@export var enemy_scenes: Array[PackedScene] = [] # Assign Enemy1–Enemy6 here

# ==========================
# --- Max on Screen Per Enemy ---
# ==========================
@export var max_on_screen: Array[int] = [4, 2, 1, 2, 1, 0]

# ==========================
# --- Total Spawn Limits Per Enemy (-1 = unlimited) ---
# ==========================
@export var max_total_spawns: Array[int] = [-1, -1, -1, -1, -1, -1] 

# ==========================
# --- Spawn Intervals Per Enemy ---
# ==========================
@export var spawn_intervals: Array[float] = [0.05, 1.0, 1.5, 0.4, 1.5, 1.0]

# ==========================
# --- Configurable Timing ---
# ==========================
@export var enemy1_loop_delay := 0.01        # tiny loop delay to check for open slots
@export var enemy1_stagger_min := 0.05       # minimum random stagger between Enemy1 spawns
@export var enemy1_stagger_max := 0.15       # maximum random stagger between Enemy1 spawns

# ==========================
# --- Spawn Points ---
# ==========================
@export var top_spawn_points: Array[Vector2] = []
@export var right_corners: Array[Vector2] = []
@export var back_line_points: Array[Vector2] = []
@export var front_line_points: Array[Vector2] = []

# ==========================
# --- Portal Settings ---
# ==========================
@export var portal_animation := "spawn"
@export var spawn_delay := 0.2
@export var portal_despawn := 0.4
@export var fly_out_distance := 80.0
@export var fly_out_direction := Vector2(-1,0)
@export var fly_out_duration := 0.3

# ==========================
# --- Nodes ---
# ==========================
@onready var template_portal: AnimatedSprite2D = $Portal

# ==========================
# --- Runtime Variables ---
# ==========================
var active_on_screen: Array[int] = []
var total_spawned: Array[int] = [] # NEW: tracks total spawned per enemy

# ==========================
# --- Ready ---
# ==========================
func _ready():
    template_portal.visible = false
    active_on_screen.resize(enemy_scenes.size())
    total_spawned.resize(enemy_scenes.size())
    for i in active_on_screen.size():
        active_on_screen[i] = 0
    for i in total_spawned.size():
        total_spawned[i] = 0

    # Start per-enemy spawners
    for i in enemy_scenes.size():
        if enemy_scenes[i]:
            call_deferred("_spawn_enemy_loop", i)

# ==========================
# --- Enemy Spawn Loop ---
# ==========================
func _spawn_enemy_loop(enemy_index: int) -> void:
    if enemy_index >= enemy_scenes.size():
        return
    var enemy_scene = enemy_scenes[enemy_index]

    # Choose spawn points per enemy type
    var spawn_points: Array[Vector2] = []
    match enemy_index:
        0:
            spawn_points = top_spawn_points
        1, 4:
            spawn_points = right_corners
        2:
            spawn_points = back_line_points
        3:
            spawn_points = front_line_points
        _:
            spawn_points = top_spawn_points

    if spawn_points.size() == 0:
        push_warning("Spawner: spawn_points empty for enemy " + str(enemy_index))
        return

    while spawner_enabled:
        # Check total spawn limit
        if max_total_spawns[enemy_index] >= 0 and total_spawned[enemy_index] >= max_total_spawns[enemy_index]:
            return # Enemy has reached its total spawn limit

        if enemy_index == 0:
            # --- Dynamic staggered spawn for Enemy1 ---
            var open_slots = max_on_screen[0] - active_on_screen[0]
            if open_slots > 0:
                for i in open_slots:
                    var pos = spawn_points.pick_random()
                    # Spawn without awaiting full portal animation to fill slots fast
                    _spawn_enemy_with_portal(enemy_scene, pos)
                    active_on_screen[0] += 1
                    total_spawned[0] += 1
                    # Optional tiny random stagger for “alive” feel
                    await wait(randf_range(enemy1_stagger_min, enemy1_stagger_max))
            # Loop delay to check for new slots
            await wait(enemy1_loop_delay)
        else:
            # --- Normal spawn for other enemies ---
            if active_on_screen[enemy_index] < max_on_screen[enemy_index]:
                var pos: Vector2 = spawn_points.pick_random()
                await _spawn_enemy_with_portal(enemy_scene, pos)
                active_on_screen[enemy_index] += 1
                total_spawned[enemy_index] += 1 # Track total spawned
            await wait(spawn_intervals[enemy_index])

# ==========================
# --- Spawn Enemy With Portal ---
# ==========================
func _spawn_enemy_with_portal(enemy_scene: PackedScene, pos: Vector2) -> void:
    var container = Node2D.new()
    add_child(container)
    container.global_position = pos

    var portal = template_portal.duplicate() as AnimatedSprite2D
    container.add_child(portal)
    portal.visible = true
    portal.modulate.a = 0.0
    portal.animation = portal_animation
    portal.play()

    await portal.create_tween().tween_property(portal, "modulate:a", 1.0, 0.25).finished
    await wait(spawn_delay)

    var enemy = enemy_scene.instantiate() as Node2D
    enemy.global_position = pos
    get_tree().current_scene.add_child(enemy)

    if enemy.has_signal("enemy_died"):
        enemy.enemy_died.connect(func():
            var idx = enemy_scenes.find(enemy_scene)
            if idx != -1:
                active_on_screen[idx] = max(active_on_screen[idx] - 1, 0)
        )

    if fly_out_distance > 0:
        var target = enemy.global_position + fly_out_direction.normalized() * fly_out_distance
        await enemy.create_tween().tween_property(enemy, "global_position", target, fly_out_duration).finished

    await portal.create_tween().tween_property(portal, "modulate:a", 0.0, portal_despawn).finished
    container.queue_free()

# ==========================
# --- Utility Wait ---
# ==========================
func wait(t: float) -> void:
    await get_tree().create_timer(t).timeout
