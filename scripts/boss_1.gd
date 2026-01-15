extends CharacterBody2D

# --------------------
# Exported variables
# --------------------
@export var missile_scene: PackedScene
@export var fire_rate_missiles: float = 5.0  # seconds between volleys

@export var laser_scene: PackedScene
@export var laser_warning_time: float = 0.5  # time before laser becomes active
@export var laser_duration: float = 2.0
@export var laser_count: int = 3              # number of vertical lasers per attack
@export var laser_x_min: float = 100
@export var laser_x_max: float = 1200

# --------------------
# Nodes
# --------------------
@onready var missile_spawns = [$missile/missilespawn1, $missile/missilespawn2, $missile/missilespawn3]
@onready var muzzle_flash: AnimatedSprite2D = $missile/missilemuzzle
@onready var exhaust: AnimatedSprite2D = $exhaust

# --------------------
# Internal timers
# --------------------
var fire_timer: float = 0.0

# --------------------
# Ready
# --------------------
func _ready():
    # Existing stuff
    if muzzle_flash:
        muzzle_flash.visible = false
    fire_timer = fire_rate_missiles
    randomize()  # for laser X positions

    # Exhaust
    if exhaust:
        exhaust.visible = true
        exhaust.play("default")  # Just call play with the animation name

# --------------------
# Process
# --------------------
func _process(delta: float) -> void:
    fire_timer -= delta
    if fire_timer <= 0.0:
        var player = get_player()
        if player:
            fire_missiles(player)
        fire_timer = fire_rate_missiles

# --------------------
# Player lookup
# --------------------
func get_player() -> Node2D:
    var players = get_tree().get_nodes_in_group("player")
    return players[0] if players.size() > 0 else null

# --------------------
# Fire missiles
# --------------------
# --------------------
# Fire missiles in sequence
# --------------------
# --------------------
# Fire missiles in sequence with muzzle and rotation
# --------------------
func fire_missiles(target: Node2D) -> void:
    if not target:
        return

    # Start coroutine to fire missiles one by one
    _fire_missiles_sequence(target)

# Coroutine for sequential missile firing
func _fire_missiles_sequence(target: Node2D) -> void:
    for spawn in missile_spawns:
        # --- Play muzzle flash ---
        if muzzle_flash:
            muzzle_flash.global_position = spawn.global_position  # move muzzle to spawn
            muzzle_flash.visible = true
            muzzle_flash.play()  # one-shot animation

        # --- Spawn missile ---
        var missile = missile_scene.instantiate()
        missile.global_position = spawn.global_position

        # Rotate missile so it points upward (Y negative)
        missile.global_rotation = -PI/2  # -90 degrees

        # Assign target if method exists
        if missile.has_method("set_target"):
            missile.set_target(target)
        get_tree().current_scene.add_child(missile)

        # Small delay before next missile
        await get_tree().create_timer(0.2).timeout

    # --- After all missiles, spawn lasers ---
    call_deferred("_spawn_lasers_after_delay")

# --------------------
# Spawn vertical lasers after missiles
# --------------------
func _spawn_lasers_after_delay() -> void:
    # Wait a short delay so missiles act as telegraph
    await get_tree().create_timer(0.5).timeout

    for i in range(laser_count):
        if not laser_scene:
            continue

        var laser = laser_scene.instantiate()
        # Random horizontal position within bounds
        laser.position.x = randf_range(laser_x_min, laser_x_max)
        # Start at top of screen
        laser.position.y = 0
        get_tree().current_scene.add_child(laser)

        # Call laser telegraph method if present
        if laser.has_method("start_telegraph"):
            laser.start_telegraph(laser_warning_time, laser_duration)
