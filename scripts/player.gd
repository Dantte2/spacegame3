extends CharacterBody2D

# --- Movement ---
@export var speed: float = 1000.0
@export var auto_speed: float = 1000.0

# --- Bullet shooting variables ---
@export var bullet_scene: PackedScene
@export var muzzleflash_scene: PackedScene
@export var fire_rate := 0.05
@export var bullet_speed := 2000.0
var can_shoot := true

# --- Missile shooting variables ---
@export var missile_scene: PackedScene
@export var missile_speed := 2000.0
@export var missile_cooldown := 1.0
var can_shoot_missile := true

# --- Super attack variables ---
@export var super_scene: PackedScene
@export var super_cooldown := 1.0
var can_use_super := true

# --- References ---
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var exhaust: AnimatedSprite2D = $Exhaust
@onready var gunpoint: Node2D = $GunPoint
@onready var missile_point: Node2D = $MissilePoint
@export var tracer_scene: PackedScene

# --- Shield system ---
@export var max_shield: float = 100000.0
var shield: float = max_shield
var shieldbar: TextureProgressBar
@onready var shield_sprite: Sprite2D = $ShieldArea/ShieldSprite

func _ready():
	# Initialize shield bar safely in any scene
	call_deferred("_init_ui")

func _init_ui():
	var current_scene = get_tree().current_scene
	if current_scene == null:
		push_error("❌ Current scene is null!")
		return

	shieldbar = current_scene.get_node_or_null("UI/ShieldBar")  # adjust path if needed
	if shieldbar == null:
		push_error("❌ ShieldBar not found in current scene!")
		return

	shieldbar.max_value = max_shield
	shieldbar.value = shield

func _physics_process(_delta):
	var input_vector = Vector2.ZERO

	# --- Player input ---
	if Input.is_action_pressed("ui_up"):
		input_vector.y -= 1
	if Input.is_action_pressed("ui_down"):
		input_vector.y += 1
	if Input.is_action_pressed("ui_left"):
		input_vector.x -= 1
	if Input.is_action_pressed("ui_right"):
		input_vector.x += 1

	if input_vector.length() > 0:
		input_vector = input_vector.normalized() * speed

	#Optional automatic forward movement
	#input_vector.x += auto_speed

	velocity = input_vector
	move_and_slide()

	# --- Sprite animation ---
	if velocity.y < 0:
		sprite.animation = "up"
	elif velocity.y > 0:
		sprite.animation = "down"
	else:
		sprite.animation = "normal"
	sprite.play()

	# --- Exhaust effects ---
	var speed_ratio = clamp(velocity.length() / speed, 0.0, 1.0)
	exhaust.animation = "move" if speed_ratio > 0 else "normal"
	exhaust.material.set("shader_parameter/glow_strength", lerp(1.0, 2.5, speed_ratio))
	exhaust.material.set("shader_parameter/pulse_amount", speed_ratio * 0.5)
	exhaust.material.set("shader_parameter/time", Time.get_ticks_msec() / 1000.0)
	exhaust.material.set("shader_parameter/heat_intensity", lerp(0.02, 0.08, speed_ratio))
	exhaust.scale.x = lerp(1.0, 1.8, speed_ratio)
	exhaust.scale.y = lerp(1.0, 0.8, speed_ratio)

	# --- Gun & missile offsets ---
	var offset = 0
	if velocity.y < 0:
		offset = -3
	elif velocity.y > 0:
		offset = 4

	gunpoint.position.y = offset
	missile_point.position.y = offset

	# --- Shooting ---
	if Input.is_action_pressed("shoot") and can_shoot:
		shoot_bullet()
		can_shoot = false
		await get_tree().create_timer(fire_rate).timeout
		can_shoot = true

	if Input.is_action_pressed("fire_missile") and can_shoot_missile:
		shoot_missile()
		can_shoot_missile = false
		await get_tree().create_timer(missile_cooldown).timeout
		can_shoot_missile = true

	if Input.is_action_pressed("fire_super") and can_use_super:
		spawn_super()
		can_use_super = false
		await get_tree().create_timer(super_cooldown).timeout
		can_use_super = true

# ============================================================
#                  Shield System (updated)
# ============================================================
func apply_shield_damage(amount: float, hit_pos: Vector2):
	if shield > 0:
		# Subtract shield
		shield -= amount
		shield = max(shield, 0)
		update_shieldbar()

		# Show hit glow on shield shader
		show_shield_hit(hit_pos)

		# --- Shield break handling ---
		if shield <= 0:
			print("Shield broken!")

			var shield_sprite = $ShieldArea/ShieldSprite

			# Disable collision
			$ShieldArea.set_deferred("collision_layer", 0)
			$ShieldArea.set_deferred("collision_mask", 0)
			$ShieldArea.set_deferred("monitoring", true)

			if shield_sprite and shield_sprite.material:
				# Make sprite visible for fragment animation
				shield_sprite.show()

				var mat = shield_sprite.material
				mat.set_shader_parameter("break_strength", 0.0)
				mat.set_shader_parameter("time", Time.get_ticks_msec() / 1000.0)

				# Animate break_strength from 0 -> 1 over 0.5 seconds
				var tween = create_tween()
				tween.tween_property(mat, "shader_parameter/break_strength", 1.0, 0.5)
				tween.tween_callback(Callable(shield_sprite, "hide"))  # hide sprite after animation
	else:
		# Shield gone, damage player health
		take_damage(amount)

func update_shieldbar():
	if shieldbar:
		shieldbar.value = shield

func show_shield_hit(hit_global_pos: Vector2):
	var shield_node = $ShieldArea/ShieldSprite
	if not shield_node or not shield_node.material:
		return

	var mat = shield_node.material

	# Compute UV of hit
	var local = shield_node.to_local(hit_global_pos)
	var uv = (local / shield_node.texture.get_size()) + Vector2(0.5, 0.5)
	mat.set_shader_parameter("hit_uv", uv)
	mat.set_shader_parameter("hit_strength", 1.0)

	# Animate hit_strength manually (burst-safe)
	animate_shield_hit(mat)


# Make this an async function so it can use `await`
func animate_shield_hit(mat: ShaderMaterial) -> void:
	var duration = 0.2
	var timer = 0.0
	while timer < duration:
		await get_tree().process_frame
		timer += get_process_delta_time()
		var t = timer / duration
		mat.set_shader_parameter("hit_strength", 1.0 * (1.0 - t))
	mat.set_shader_parameter("hit_strength", 0.0)

# ============================================================
#                  Health system
# ============================================================
var health: int = 100  # add this if not already present

func take_damage(amount: int):
	health -= amount
	print("Player health:", health)
	if health <= 0:
		die()

func die():
	print("Player died")
	queue_free()

# ============================================================
#                  Shooting Functions
# ============================================================
func shoot_bullet():
	if not bullet_scene:
		return

	var bullet = bullet_scene.instantiate()
	var spread_angle = deg_to_rad(2)
	var random_rot = randf_range(-spread_angle, spread_angle)

	var forward_offset = Vector2(20, 0).rotated(gunpoint.global_rotation)
	bullet.global_position = gunpoint.global_position + forward_offset
	bullet.global_rotation = gunpoint.global_rotation + random_rot
	bullet.velocity = Vector2(bullet_speed, 0).rotated(bullet.global_rotation)

	bullet.z_as_relative = false
	bullet.z_index = 100
	get_tree().current_scene.add_child(bullet)

	if tracer_scene:
		var tracer = tracer_scene.instantiate()
		tracer.global_position = bullet.global_position
		tracer.global_rotation = bullet.global_rotation
		tracer.z_as_relative = false
		tracer.z_index = 110
		get_tree().current_scene.add_child(tracer)

	if muzzleflash_scene:
		var flash = muzzleflash_scene.instantiate()
		gunpoint.add_child(flash)
		flash.position = Vector2.ZERO
		flash.z_as_relative = false
		flash.z_index = 120

func shoot_missile():
	var directions = [1, 1.2, -1, -1.2, 1.3, -1.3]
	directions.shuffle()

	var enemies = []
	for e in get_tree().get_nodes_in_group("enemy"):
		if e and is_instance_valid(e) and e.is_inside_tree():
			enemies.append(e)

	for dir in directions:
		var missile = missile_scene.instantiate()
		var vertical_offset = randi_range(10, 40) * dir
		missile.global_position = missile_point.global_position + Vector2(0, vertical_offset)
		missile.rotation = rotation
		missile.velocity = Vector2(missile_speed, 0).rotated(rotation)
		missile.direction_multiplier = dir

		if enemies.size() > 0:
			var target_enemy = enemies[randi() % enemies.size()]
			if target_enemy and is_instance_valid(target_enemy) and target_enemy.is_inside_tree():
				missile.set_target(target_enemy)

		get_tree().current_scene.add_child(missile)
		if missile.has_node("Exhaust"):
			missile.get_node("Exhaust").play("exhaust")
		await get_tree().create_timer(0.1).timeout

func spawn_super():
	if not super_scene:
		return

	var super_attack = super_scene.instantiate()
	super_attack.global_position = missile_point.global_position
	get_tree().current_scene.add_child(super_attack)
