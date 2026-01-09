extends Area2D

@export var speed: float = 1000.0
var velocity: Vector2 = Vector2.RIGHT  # direction bullet moves

@export var damage_to_shield: int = 100
@export var damage_to_health: int = 1

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
    randomize()

    # ROTATE BULLET TO MATCH DIRECTION
    if velocity != Vector2.ZERO:
        rotation = velocity.angle()

    # Randomize starting frame
    if sprite:
        var total_frames = sprite.sprite_frames.get_frame_count(sprite.animation)
        sprite.frame = randi() % total_frames
        sprite.play()
        sprite.modulate = Color(1.0, 0.55, 0.15, 1.0)

    collision_layer = 2
    collision_mask = 1

    connect("area_entered", Callable(self, "_on_area_entered"))
    connect("body_entered", Callable(self, "_on_body_entered"))

func _physics_process(delta):
    # Move bullet in its velocity direction
    position -= velocity.normalized() * speed * delta

    # Rotate to match velocity
    if velocity != Vector2.ZERO:
        rotation = velocity.angle()

func set_velocity(dir: Vector2):
    velocity = dir.normalized()

func _on_area_entered(area):
    _handle_hit(area)

func _on_body_entered(body):
    _handle_hit(body)

func _handle_hit(target):
    var player = target
    while player and not player.has_method("take_damage"):
        player = player.get_parent()
    if not player:
        return

    # Damage applies to shield first
    if player.shield > 0:
        player.apply_shield_damage(damage_to_shield, global_position)
    else:
        player.take_damage(damage_to_health)

    queue_free()
