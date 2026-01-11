extends Area2D

@export var speed: float = 600.0
@export var damage_to_shield: int = 1
@export var damage_to_health: int = 1

var velocity: Vector2 = Vector2.ZERO

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	if sprite:
		sprite.play()
		

	# Collision layers
	collision_layer = 2  # bullet
	collision_mask = 1   # collides with player only

	connect("area_entered", Callable(self, "_on_area_entered"))
	connect("body_entered", Callable(self, "_on_body_entered"))

func _physics_process(delta):
	position += velocity * delta

func _on_area_entered(area):
	_handle_hit(area)

func _on_body_entered(body):
	_handle_hit(body)

func _handle_hit(target):
	# find player script in parent chain
	var player = target
	while player and not player.has_method("take_damage"):
		player = player.get_parent()
	if not player:
		return

	if player.shield > 0:
		player.apply_shield_damage(damage_to_shield, global_position)
	else:
		player.take_damage(damage_to_health)

	queue_free()
