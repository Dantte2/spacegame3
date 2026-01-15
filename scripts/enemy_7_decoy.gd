extends Node2D

@export var fade_time := 4.5
@onready var sprite: Sprite2D = $Sprite2D

func _ready():
    # Start already semi-transparent
    sprite.modulate = Color(0.392, 1.0, 0.333, 0.404)
    
    var tween = create_tween()
    tween.tween_property(sprite, "modulate:a", 0.0, fade_time)
    tween.tween_callback(Callable(self, "queue_free"))
