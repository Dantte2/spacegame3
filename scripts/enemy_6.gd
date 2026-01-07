extends CharacterBody2D

# --- Health system ---
@export var max_health: int = 100
var health: int

# --- Shooting ---
@export var bullet_scene: PackedScene
@export var fire_rate: float = 1.0 # seconds between shots

@onready var bullet_spawn: Node2D = $BulletSpawn
var fire_timer: float = 0.0

# Optional death effect
@export var death_animation_scene: PackedScene

func _ready():
    health = max_health
    $Exhaust.play()

func _process(delta):
    fire_timer -= delta
    if fire_timer <= 0.0:
        fire()
        fire_timer = fire_rate

func fire() -> void:
    if bullet_scene == null:
        return

    var bullet = bullet_scene.instantiate()
    bullet.global_position = bullet_spawn.global_position
    bullet.global_rotation = bullet_spawn.global_rotation
    get_tree().current_scene.add_child(bullet)

# --- Damage Handling ---
func take_damage(amount: int) -> void:
    health -= amount
    if health <= 0:
        die()

func die() -> void:
    if death_animation_scene:
        var anim = death_animation_scene.instantiate()
        anim.global_position = global_position
        get_tree().current_scene.call_deferred("add_child", anim)

    queue_free()
