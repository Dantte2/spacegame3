extends Node2D

@export var speed: float = 900.0
@export var target_y: float = -200.0  # Y position off-screen

# Reference to the sprite
@onready var sprite: Sprite2D = $Sprite2D  # adjust path if different

func _ready():
    pass  # No modulation applied

func _process(delta):
    # Move upward
    position.y -= speed * delta

    # Remove if off screen
    if position.y <= target_y:
        queue_free()
