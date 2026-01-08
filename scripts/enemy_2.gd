extends CharacterBody2D

# --- Laser Variables ---
@export var fire_time: float = 1.2        # how long the laser stays on
@export var cooldown_time: float = 1.5    # time between shots
@export var rotation_speed: float = 5.0   # how fast the laser turns toward the player

@onready var laser := $BulletSpawn/LaserBeam2D
@onready var bullet_spawn := $BulletSpawn

# --- Health System ---
@export var max_health: float = 250.0
var health: float = 0.0
@export var death_animation_scene: PackedScene
var running := true

# --- Player Reference ---
var player: Node2D

# ============================
# --- ADDED FOR SPAWNER ---
# ============================
signal enemy_died  # <-- Added: lets spawner know when this enemy dies

func _ready() -> void:
	# Initialize health
	health = max_health

	# Find the player
	var players = get_tree().get_nodes_in_group("player_body")
	if players.size() > 0:
		player = players[0]

	# Make sure laser starts off
	laser.is_casting = false

	# Start laser pointed toward player
	if player:
		bullet_spawn.rotation = (player.global_position - global_position).angle()

	# Start firing loop
	_start_firing_loop()

func _exit_tree() -> void:
	running = false

func _physics_process(delta: float) -> void:
	# Rotate smoothly toward player while laser is firing
	if player and laser.is_casting:
		aim_at_player(delta)

# --- Laser Firing Loop ---
func _start_firing_loop() -> void:
	await get_tree().process_frame

	while running:
		# Start laser
		laser.is_casting = true
		await get_tree().create_timer(fire_time).timeout

		# Stop laser
		laser.is_casting = false
		await get_tree().create_timer(cooldown_time).timeout

# --- Rotation Toward Player ---
func aim_at_player(delta: float) -> void:
	if not player:
		return

	var target_dir = (player.global_position - global_position).angle()
	bullet_spawn.rotation = lerp_angle(bullet_spawn.rotation, target_dir, rotation_speed * delta)

# ============================================================
#                     Health / Damage System
# ============================================================

func take_damage(amount: float) -> void:
	if health <= 0:
		return  # already dead

	health -= amount
	health = max(health, 0)
	print("Enemy health:", health)

	if health <= 0:
		die()

func die() -> void:
	running = false  # stop firing loop

	# --- ADDED: emit signal for spawner ---
	emit_signal("enemy_died")  # <-- This tells the spawner this enemy died

	# Play death animation if assigned
	if death_animation_scene:
		var anim = death_animation_scene.instantiate()
		anim.global_position = global_position
		get_tree().get_root().call_deferred("add_child", anim)

	queue_free()

# --- Reset function for spawner ---
func reset_enemy() -> void:
	health = max_health
	running = true
	laser.is_casting = false
