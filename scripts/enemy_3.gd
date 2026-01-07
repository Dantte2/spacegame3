extends CharacterBody2D

# --- Movement ---
@export var vertical_speed := 250.0

# --- Shooting ---
@export var fire_rate := 2.0
@export var bullet_scene: PackedScene
@export var bullets_per_shot := 40
@export var bullet_speed := 700.0
@export var fire_direction := Vector2.LEFT
@export var cone_angle := 20.0

# --- Randomness ---
@export var speed_jitter := 0.2

# --- Health ---
@export var max_health := 100
var health: int

# --- Internal ---
var direction := 1
var fire_timer := 0.0

@onready var exhaust := $exhaust
@onready var bullet_spawn := $BulletSpawn
@export var death_animation_scene: PackedScene

func _ready():
    health = max_health
    # Randomize starting vertical direction: either up (-1) or down (1)
    direction = 1 if randi() % 2 == 0 else -1

func _physics_process(delta):
    # Movement
    position.y += direction * vertical_speed * delta

    # Bounce off top/bottom
    var viewport_height = get_viewport_rect().size.y
    if position.y >= viewport_height:
        position.y = viewport_height
        direction = -1
    elif position.y <= 0:
        position.y = 0
        direction = 1

    # Exhaust animation
    if not exhaust.is_playing():
        exhaust.play("boost")

    # Shooting
    fire_timer -= delta
    if fire_timer <= 0.0:
        fire_timer = fire_rate
        fire_forward_cone()


# --- Shooting logic ---
func fire_forward_cone():
    if not bullet_scene or not bullet_spawn:
        return

    var spawn_pos = bullet_spawn.global_position
    var center_dir = fire_direction.normalized()

    for i in range(bullets_per_shot):
        var angle_offset = deg_to_rad(randf_range(-cone_angle/2.0, cone_angle/2.0))
        var dir = center_dir.rotated(angle_offset)
        var final_speed = bullet_speed * randf_range(1.0 - speed_jitter, 1.0 + speed_jitter)

        var bullet = bullet_scene.instantiate()
        bullet.global_position = spawn_pos
        bullet.velocity = dir * final_speed
        bullet.rotation = dir.angle()

        get_tree().current_scene.call_deferred("add_child", bullet)


# --- Damage Handling ---
func take_damage(amount: int):
    health -= amount
    if health <= 0:
        die()


func die():
    if death_animation_scene:
        var anim = death_animation_scene.instantiate()
        anim.global_position = global_position
        get_tree().current_scene.call_deferred("add_child", anim)

    queue_free()
