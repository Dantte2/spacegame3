extends CharacterBody2D

@export var bullet_scene: PackedScene      # assign your Bullet scene here
@export var fire_rate: float = 0.8         # bullets per second
@export var bullets_per_shot: int = 5      # bullets fired per shot
@export var cone_angle: float = 30.0       # total cone angle in degrees

@export var circle_radius: float = 100.0    # radius of circular movement
@export var circle_speed: float = 1.0      # how fast it moves around the circle

# --- Health system ---
@export var max_health: int = 100
var health: int
@export var death_animation_scene: PackedScene
var running = true

var fire_timer: float = 0.0
var center_position: Vector2
var time_accumulator: float = 0.0

signal enemy_died

func _ready():
    health = max_health
    center_position = global_position
    $Exhaust.play()  # play exhaust animation

func _physics_process(delta):
    fire_timer -= delta
    time_accumulator += delta

    if fire_timer <= 0.0:
        shoot_bullets()
        fire_timer = 1.0 / fire_rate

    # Circular movement around the center position
    global_position.x = center_position.x + cos(time_accumulator * circle_speed) * circle_radius
    global_position.y = center_position.y + sin(time_accumulator * circle_speed) * circle_radius

func shoot_bullets():
    if not bullet_scene:
        return

    # Calculate starting angle and step between bullets
    var start_angle = -deg_to_rad(cone_angle) / 2
    var step = deg_to_rad(cone_angle) / max(bullets_per_shot - 1, 1)

    for i in bullets_per_shot:
        var bullet = bullet_scene.instantiate()
        bullet.global_position = $BulletSpawn.global_position

        # Rotate bullet velocity for cone
        var angle_offset = start_angle + step * i
        bullet.velocity = Vector2.RIGHT.rotated(global_rotation + angle_offset)

        # Add bullet to the scene
        get_tree().current_scene.add_child(bullet)

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
