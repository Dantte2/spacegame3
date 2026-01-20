extends Area2D

# ====================
# EXPORTS
# ====================
@export var speed: float = 1000.0
@export var damage_to_shield: int = 100
@export var damage_to_health: int = 1

# NEW: color control (orange default)
@export var bullet_color: Color = Color(1.0, 0.55, 0.15, 1.0)

# ====================
# INTERNAL
# ====================
var velocity: Vector2 = Vector2.ZERO

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

# ====================
# READY
# ====================
func _ready() -> void:
    randomize()

    # Rotate bullet to match direction
    if velocity != Vector2.ZERO:
        rotation = velocity.angle()

    # Sprite setup
    if sprite:
        var total_frames := sprite.sprite_frames.get_frame_count(sprite.animation)
        sprite.frame = randi() % total_frames
        sprite.play()
        sprite.modulate = bullet_color

    collision_layer = 2
    collision_mask = 1

    area_entered.connect(_on_area_entered)
    body_entered.connect(_on_body_entered)

# ====================
# PHYSICS
# ====================
func _physics_process(delta: float) -> void:
    position += velocity * speed * delta

    if velocity != Vector2.ZERO:
        rotation = velocity.angle()

# ====================
# API
# ====================
func set_velocity(dir: Vector2) -> void:
    velocity = dir.normalized()

# ====================
# COLLISION
# ====================
func _on_area_entered(area: Area2D) -> void:
    _handle_hit(area)

func _on_body_entered(body: Node) -> void:
    _handle_hit(body)

func _handle_hit(target: Node) -> void:
    var player := target
    while player and not player.has_method("take_damage"):
        player = player.get_parent()

    if not player:
        return

    if player.shield > 0:
        player.apply_shield_damage(damage_to_shield, global_position)
    else:
        player.take_damage(damage_to_health)

    queue_free()
