extends CharacterBody2D

# --- Health system ---
@export var max_health: int = 150
var health: int
var running = true
@export var death_animation_scene: PackedScene

# --- Shooting system ---
@export var normal_bullet_scene: PackedScene   # bullet for cone
@export var homing_bullet_scene: PackedScene   # homing bullets

@export var fire_rate: float = 0.5             # time between bursts (shots per second)
@export var bullets_per_shot: int = 5          # bullets per cone
@export var cone_angle: float = 5.0           # total angle of cone in degrees
@export var burst_count: int = 3               # number of shots in a burst
@export var burst_delay: float = 0.1           # delay between bullets in burst (seconds)
@export var bullet_spawn_offset: float = 1.0  # distance bullets spawn from enemy

var fire_timer: float = 0.0
var burst_timer: float = 0.0
var burst_shots_remaining: int = 0

signal enemy_died

func _ready():
    health = max_health

func _physics_process(delta):
    # Shooting timer
    fire_timer -= delta
    if fire_timer <= 0.0:
        # Start a burst
        burst_shots_remaining = burst_count
        burst_timer = 0.0
        fire_timer = 1.0 / fire_rate

    # Handle burst shots
    if burst_shots_remaining > 0:
        burst_timer -= delta
        if burst_timer <= 0.0:
            shoot_cone()
            burst_shots_remaining -= 1
            burst_timer = burst_delay

func shoot_cone():
    if normal_bullet_scene and $BulletSpawn1:
        var start_angle = -deg_to_rad(cone_angle) / 2
        var step = deg_to_rad(cone_angle) / max(bullets_per_shot - 1, 1)

        for i in bullets_per_shot:
            var bullet = normal_bullet_scene.instantiate()
            # Offset bullet to avoid collision with enemy
            bullet.global_position = $BulletSpawn1.global_position + Vector2(bullet_spawn_offset, 0).rotated(global_rotation)
            
            # Rotate velocity for cone spread
            var angle_offset = start_angle + step * i
            bullet.velocity = Vector2.LEFT.rotated(global_rotation + angle_offset) * bullet.speed
            get_tree().current_scene.add_child(bullet)

    # Homing bullets
    for spawn in [$BulletSpawn2, $BulletSpawn3]:
        if homing_bullet_scene and spawn:
            var homing_bullet = homing_bullet_scene.instantiate()
            homing_bullet.global_position = spawn.global_position + Vector2(bullet_spawn_offset, 0).rotated(global_rotation)
            # homing bullet handles its own targeting
            get_tree().current_scene.add_child(homing_bullet)

# --- Damage Handling ---
func take_damage(amount: int):
    health -= amount
    if health <= 0:
        die()

func die():
    running = false
    emit_signal("enemy_died")
    if death_animation_scene:
        var anim = death_animation_scene.instantiate()
        anim.global_position = global_position
        get_tree().current_scene.call_deferred("add_child", anim)
    queue_free()
