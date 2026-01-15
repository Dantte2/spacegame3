extends Area2D

@export var speed: float = 1600.0
@export var damage_to_shield: int = 1
@export var damage_to_health: int = 1

var velocity: Vector2 = Vector2.ZERO

@onready var sprite: Node = $Sprite2D

func _ready():
    # Play sprite animation only if AnimatedSprite2D
    if sprite and sprite is AnimatedSprite2D:
        sprite.play()
    
    # Set collision layers
    collision_layer = 2  # bullet
    collision_mask = 1   # collides with player only
    
    # Connect signals
    connect("area_entered", Callable(self, "_on_area_entered"))
    connect("body_entered", Callable(self, "_on_body_entered"))

func _physics_process(delta):
    position += velocity * delta

func _on_area_entered(area):
    _handle_hit(area)

func _on_body_entered(body):
    _handle_hit(body)

func _handle_hit(target):
    # Walk up the parent chain to find a node with `take_damage()`
    var obj = target
    while obj and not obj.has_method("take_damage"):
        obj = obj.get_parent()
    if not obj:
        return

    # Apply damage
    if "shield" in obj and obj.shield > 0:
        if obj.has_method("apply_shield_damage"):
            obj.apply_shield_damage(damage_to_shield, global_position)
    else:
        obj.take_damage(damage_to_health)

    # Destroy self
    queue_free()
