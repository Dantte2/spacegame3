extends CharacterBody2D

# ==========================
# --- Health System ---
# ==========================
@export var max_health: int = 150
var health: int
var running := true
@export var death_animation_scene: PackedScene

# ==========================
# --- Shooting System ---
# ==========================
@export var normal_bullet_scene: PackedScene   # standard bullets (burst)
@export var homing_bullet_scene: PackedScene   # homing bullets

# --- Normal bullets ---
@export var fire_rate: float = 0.5             # shots per second (for bursts)
@export var burst_count: int = 5               # bullets per burst
@export var burst_delay: float = 0.1           # delay between shots in burst
@export var bullet_spread: float = 5.0         # spread in degrees
@export var normal_bullet_speed: float = 1300  # per-instance bullet speed
@export var bullet_spawn_offset: float = 1.0

# --- Homing bullets ---
@export var homing_bullet_count: int = 2
@export var homing_bullet_speed: float = 750  # per-instance homing bullet speed
@export var homing_barrel_angles: Array = [15, -15]  # degrees
@export var homing_fire_rate: float = 2.0       # seconds between homing bullet shots

# ==========================
# --- Timers ---
# ==========================
var fire_timer: float = 0.0
var burst_timer: float = 0.0
var burst_shots_remaining: int = 0
var homing_timer: float = 0.0

signal enemy_died

# ==========================
# --- Ready ---
# ==========================
func _ready():
	health = max_health
	fire_timer = 0.0 / fire_rate
	homing_timer = homing_fire_rate

# ==========================
# --- Physics / Shooting ---
# ==========================
func _physics_process(delta):
	# --- Normal bullets ---
	fire_timer -= delta
	if fire_timer <= 0.0:
		burst_shots_remaining = burst_count
		burst_timer = 0.0
		fire_timer = 1.0 / fire_rate

	if burst_shots_remaining > 0:
		burst_timer -= delta
		if burst_timer <= 0.0:
			shoot_normal_bullet()
			burst_shots_remaining -= 1
			burst_timer = burst_delay

	# --- Homing bullets ---
	homing_timer -= delta
	if homing_timer <= 0.0:
		shoot_homing_bullets()
		homing_timer = homing_fire_rate

# ==========================
# --- Normal Bullet Shooting ---
# ==========================
func shoot_normal_bullet():
	if not normal_bullet_scene or not $BulletSpawn1:
		return

	var spread_radians = deg_to_rad(bullet_spread)
	var angle_offset = randf_range(-spread_radians / 2, spread_radians / 2)

	var bullet = normal_bullet_scene.instantiate()
	bullet.global_position = $BulletSpawn1.global_position + Vector2(bullet_spawn_offset, 0).rotated(global_rotation)
	bullet.velocity = Vector2.LEFT.rotated(global_rotation + angle_offset) * normal_bullet_speed
	bullet.rotation = bullet.velocity.angle()
	get_tree().current_scene.add_child(bullet)

# ==========================
# --- Homing Bullet Shooting ---
# ==========================
func shoot_homing_bullets():
	var barrel_spawns = [$BulletSpawn2, $BulletSpawn3]

	for idx in homing_bullet_count:
		if idx >= barrel_spawns.size():
			continue

		var spawn = barrel_spawns[idx]
		if spawn and homing_bullet_scene:
			var hb = homing_bullet_scene.instantiate()
			hb.global_position = spawn.global_position + Vector2(bullet_spawn_offset, 0).rotated(global_rotation)
			var angle_offset = deg_to_rad(homing_barrel_angles[idx])
			hb.initial_direction = Vector2.LEFT.rotated(global_rotation + angle_offset)
			hb.speed = homing_bullet_speed  # instance-specific speed
			get_tree().current_scene.add_child(hb)

# ==========================
# --- Damage Handling ---
# ==========================
func take_damage(amount: int):
	health -= amount
	if health <= 0:
		die()

func die():
	running = false
	emit_signal("enemy_died")
	if death_animation_scene:
		var anim = death_animation_scene.instantiate()
		anim.global_position = global_position
		get_tree().current_scene.call_deferred("add_child", anim)
	queue_free()
