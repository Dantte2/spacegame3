extends CharacterBody2D

# ==========================
# --- Movement ---
# ==========================
@export var speed: float = 750
@export var homing_delay: float = 0.5

# ==========================
# --- Targeting ---
# ==========================
var target: Node2D = null
var homing_enabled := false

# ==========================
# --- Initial barrel direction ---
# ==========================
var initial_direction: Vector2 = Vector2.LEFT  # to be set by spawner

# ==========================
# --- Ready ---
# ==========================
func _ready():
	# Fly initially in barrel direction
	velocity = initial_direction.normalized() * speed
	rotation = velocity.angle()

	# Find player if target not set
	if target == null:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			target = players[0]

	# Enable homing after delay
	_enable_homing_after_delay()

	# Optional: destroy after lifetime
	_destroy_after_lifetime()

func _enable_homing_after_delay() -> void:
	await get_tree().create_timer(homing_delay).timeout
	homing_enabled = true

func _destroy_after_lifetime() -> void:
	await get_tree().create_timer(5.0).timeout
	queue_free()

# ==========================
# --- Physics ---
# ==========================
func _physics_process(delta):
	# Homing adjustment
	if homing_enabled and target and target.is_inside_tree():
		var to_target = (target.global_position - global_position).normalized()
		var angle_to_target = velocity.angle_to(to_target)

		var max_turn = 0.5 * delta  # can expose as export
		angle_to_target = clamp(angle_to_target, -max_turn, max_turn)

		if abs(angle_to_target) > 0.001:
			velocity = velocity.rotated(angle_to_target)

	# Maintain constant speed
	velocity = velocity.normalized() * speed

	# Move
	var collision = move_and_collide(velocity * delta)
	if collision:
		_handle_hit(collision.get_collider())

	# Rotate sprite to match velocity
	rotation = velocity.angle()

# ==========================
# --- Collision ---
# ==========================
func _handle_hit(target_node):
	var player = target_node
	while player and not player.has_method("take_damage"):
		player = player.get_parent()
	if not player:
		return

	if player.shield > 0:
		player.apply_shield_damage(1, global_position)
	else:
		player.take_damage(1)

	queue_free()
