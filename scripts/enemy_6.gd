extends CharacterBody2D

# --------------------
# Health
# --------------------
@export var max_health: int = 550
var health: int

# --------------------
# Movement (Y follow)
# --------------------
@export var vertical_speed: float = 200.0
@export var y_tolerance: float = 5.0

# --------------------
# Shooting
# --------------------
@export var missile_scene: PackedScene
@export var fire_rate_missile: float = 0.5

@export var bullet_scene: PackedScene
@export var fire_rate_bullet: float = 1.5
@export var cone_shots: int = 8
@export var cone_angle: float = 15.0
@export var bullet_speed: float = 600.0

@export var laser_scene: PackedScene
@export var laser_burst_count: int = 6
@export var laser_burst_delay: float = 0.1
@export var laser_fire_rate: float = 3.0

@onready var bullet_spawn: Node2D = $BulletSpawn
@onready var laser_spawn: Node2D = $BulletSpawn2
@onready var raycasts: Array = [$raycast1, $raycast2, $raycast3]

var fire_timer_missile: float = 0.0
var fire_timer_bullet: float = 0.0
var fire_timer_laser: float = 0.0
var laser_burst_in_progress: bool = false

# --------------------
# Death
# --------------------
@export var death_animation_scene: PackedScene
signal enemy_died
var alive: bool = true

# --------------------
# Ready
# --------------------
func _ready():
    health = max_health
    for r in raycasts:
        r.enabled = true

    if has_node("Exhaust") and $Exhaust is AnimatedSprite2D:
        $Exhaust.play()

    fire_timer_laser = laser_fire_rate

# --------------------
# Process
# --------------------
func _process(delta):
    if not alive: return
    follow_player_y(delta)
    handle_firing(delta)
    handle_laser(delta)

# --------------------
# Player Tracking
# --------------------
func get_player() -> Node2D:
    var players = get_tree().get_nodes_in_group("player")
    return players[0] if players.size() > 0 else null

func follow_player_y(_delta):
    var player = get_player()
    velocity.y = sign(player.global_position.y - global_position.y) * vertical_speed \
        if player and abs(player.global_position.y - global_position.y) > y_tolerance else 0
    move_and_slide()

# --------------------
# Firing Logic
# --------------------
func handle_firing(delta):
    var player = get_player()
    if not player: return

    # --- Missile ---
    fire_timer_missile -= delta
    if missile_scene and fire_timer_missile <= 0.0:
        for r in raycasts:
            if r.is_colliding() and r.get_collider().is_in_group("player"):
                fire_missile(r.get_collider(), r)
                fire_timer_missile = fire_rate_missile
                break

    # --- Cone bullets ---
    fire_timer_bullet -= delta
    if bullet_scene and fire_timer_bullet <= 0.0:
        fire_cone(player)
        fire_timer_bullet = fire_rate_bullet

# --------------------
# Missiles
# --------------------
func fire_missile(target: Node2D, spawn_node: Node2D):
    if not (missile_scene and target and spawn_node): return
    var missile = missile_scene.instantiate()
    missile.global_position = spawn_node.global_position
    missile.global_rotation = spawn_node.global_rotation
    if missile.has_method("set_target"): missile.set_target(target)
    get_tree().current_scene.add_child(missile)

# --------------------
# Cone bullets
# --------------------
func fire_cone(target: Node2D):
    if not (bullet_scene and target): return
    var to_target = (target.global_position - bullet_spawn.global_position).normalized()
    var base_angle = to_target.angle()
    var half_angle_rad = deg_to_rad(cone_angle / 2)

    for i in range(cone_shots):
        var t = i / float(cone_shots - 1) if cone_shots > 1 else 0.0
        var angle_offset = lerp(-half_angle_rad, half_angle_rad, t)
        var bullet = bullet_scene.instantiate()
        bullet.global_position = bullet_spawn.global_position
        bullet.global_rotation = base_angle + angle_offset
        if bullet.has_method("set_velocity"):
            bullet.set_velocity(Vector2.LEFT.rotated(base_angle + angle_offset) * bullet_speed)
        elif "velocity" in bullet:
            bullet.velocity = Vector2.LEFT.rotated(base_angle + angle_offset) * bullet_speed
        get_tree().current_scene.add_child(bullet)

# --------------------
# Eye Laser Burst (player-aimed)
# --------------------
func handle_laser(delta):
    fire_timer_laser -= delta
    if laser_scene and fire_timer_laser <= 0.0 and not laser_burst_in_progress:
        fire_timer_laser = laser_fire_rate
        laser_burst_in_progress = true
        call_deferred("_laser_burst_task")

func _laser_burst_task() -> void:
    var player = get_player()
    if not player:
        laser_burst_in_progress = false
        return
    for i in range(laser_burst_count):
        shoot_laser_at_player(player)
        await get_tree().create_timer(laser_burst_delay).timeout
    laser_burst_in_progress = false

func shoot_laser_at_player(player: Node2D):
    if not (laser_scene and is_instance_valid(laser_spawn)): return
    var laser = laser_scene.instantiate()
    laser.global_position = laser_spawn.global_position
    var angle = (player.global_position - laser_spawn.global_position).angle()
    laser.global_rotation = angle
    if "velocity" in laser:
        laser.velocity = Vector2.RIGHT.rotated(angle) * 3000
    get_tree().current_scene.add_child(laser)

# --------------------
# Damage & Death
# --------------------
func take_damage(amount: int):
    if not alive: return
    health -= amount
    if health <= 0: die()

func die():
    if not alive: return
    alive = false
    emit_signal("enemy_died")
    if death_animation_scene:
        var anim = death_animation_scene.instantiate()
        anim.global_position = global_position
        get_tree().current_scene.call_deferred("add_child", anim)
    queue_free()
