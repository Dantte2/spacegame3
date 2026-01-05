extends CharacterBody2D

# --- Health system ---
@export var max_health: int = 100
var health: int

# Optional death effect (explosion, animation, etc.)
@export var death_animation_scene: PackedScene

func _ready():
	health = max_health
	$Exhaust.play()

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
