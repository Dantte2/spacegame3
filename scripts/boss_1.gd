extends CharacterBody2D

# ====================
# EXPORTS
# ====================
@export var missile_scene: PackedScene  # pattern a missiles
@export var laser_scene: PackedScene    # pattern a beam
@export var beam_b_scene: PackedScene   # pattern b beam
@export var bullet_scene: PackedScene   # boneshot

# --------------------
# Pattern A
# --------------------
@export var fire_rate: float = 5.0
@export var missile_count: int = 6
@export var missile_delay: float = 0.2
@export var laser_waves: int = 3
@export var lasers_per_wave: int = 5
@export var laser_warning_time: float = 0.5
@export var laser_duration: float = 2.0
@export var laser_wave_delay: float = 0.3
@export var laser_x_min: float = 100
@export var laser_x_max: float = 1200

# --------------------
# Pattern B
# --------------------
@export var pattern_b_move_speed: float = 900.0
@export var pattern_b_pause: float = 0.25
@export var pattern_b_y_min: float = 100.0
@export var pattern_b_y_max: float = 600.0
@export var pattern_b_repeat: int = 2
@export var pattern_b_cooldown: float = 2.5

# --------------------
# Cone Shot (Basic Attack)
# --------------------
@export var cone_bullet_count: int = 7
@export var cone_angle_deg: float = 40.0
@export var cone_fire_delay: float = 2.5
@export var cone_bullet_color: Color = Color(0.823, 0.585, 1.0, 1.0)

# Debug
@export var force_pattern: int = -1 # -1 = normal cycle, 0 = Pattern A, 1 = Pattern B

# ====================
# NODES
# ====================
@onready var missile_spawns = [
    $missile/missilespawn1,
    $missile/missilespawn2,
    $missile/missilespawn3
]

@onready var muzzle_flash: AnimatedSprite2D = $missile/missilemuzzle
@onready var exhaust: AnimatedSprite2D = $exhaust
@onready var bulletspawn: Node2D = $bulletspawn
@onready var coneshotspawn: Node2D = $coneshotspawn

# ====================
# INTERNAL
# ====================
var fire_timer := 0.0
var attacking := false
var pattern_index := 0

# ====================
# READY
# ====================
func _ready() -> void:
    randomize()

    if muzzle_flash:
        muzzle_flash.visible = false

    if exhaust:
        exhaust.visible = true
        exhaust.play("default")

    # Start cone attack loop
    start_cone_loop()

# ====================
# PROCESS
# ====================
func _process(delta: float) -> void:
    if attacking:
        return

    fire_timer -= delta
    if fire_timer <= 0.0:
        var player = get_player()
        if player:
            start_attack(player)
        fire_timer = fire_rate

# ====================
# PLAYER
# ====================
func get_player() -> Node2D:
    var players = get_tree().get_nodes_in_group("player")
    return players[0] if players.size() > 0 else null

# ====================
# ATTACK CONTROL
# ====================
func start_attack(target: Node2D) -> void:
    if attacking:
        return

    attacking = true

    var pattern_to_run = force_pattern if force_pattern >= 0 else pattern_index
    match pattern_to_run:
        0: await pattern_a(target)
        1: await pattern_b()

    if force_pattern < 0:
        pattern_index = (pattern_index + 1) % 2

    attacking = false

# ====================
# PATTERN A
# ====================
func pattern_a(target: Node2D) -> void:
    var middle_y = (pattern_b_y_min + pattern_b_y_max) * 0.5
    if abs(global_position.y - middle_y) > 1.0:
        await move_to_y(middle_y)

    await fire_missiles(target)
    await fire_lasers()

# ====================
# PATTERN B
# ====================
func pattern_b() -> void:
    var middle_y = (pattern_b_y_min + pattern_b_y_max) * 0.5

    for i in range(pattern_b_repeat):
        var player = get_player()
        var target_y = player.global_position.y if player else middle_y

        await move_to_y(target_y)
        await _wait(pattern_b_pause)

        var beam = beam_b_scene.instantiate()
        beam.global_position = bulletspawn.global_position
        get_tree().current_scene.add_child(beam)

        if beam.has_node("AnimationPlayer"):
            await beam.get_node("AnimationPlayer").animation_finished
        else:
            await _wait(2.0)

        if i < pattern_b_repeat - 1:
            await _wait(pattern_b_cooldown)

# ====================
# CONE SHOT (BASIC)
# ====================
func start_cone_loop() -> void:
    call_deferred("_cone_loop")

func _cone_loop() -> void:
    while is_inside_tree():
        await _wait(cone_fire_delay)
        fire_cone()

func fire_cone() -> void:
    var player = get_player()
    if not player or not bullet_scene or not coneshotspawn:
        return

    var base_dir = (player.global_position - coneshotspawn.global_position).normalized()
    var half_angle = deg_to_rad(cone_angle_deg * 0.5)

    for i in range(cone_bullet_count):
        var t = 0.0 if cone_bullet_count == 1 else float(i) / float(cone_bullet_count - 1)
        var angle = lerp(-half_angle, half_angle, t)
        var dir = base_dir.rotated(angle)

        var bullet = bullet_scene.instantiate()
        bullet.global_position = coneshotspawn.global_position
        bullet.set_velocity(dir)
        bullet.bullet_color = cone_bullet_color

        get_tree().current_scene.add_child(bullet)

# ====================
# HELPERS
# ====================
func move_to_y(target_y: float) -> void:
    while abs(global_position.y - target_y) > 1.0:
        var diff = target_y - global_position.y
        var move_amount = min(abs(diff), pattern_b_move_speed * get_process_delta_time())
        global_position.y += sign(diff) * move_amount
        await get_tree().process_frame

    global_position.y = target_y

func fire_missiles(target: Node2D) -> void:
    for i in range(missile_count):
        var spawn = missile_spawns[i % missile_spawns.size()]
        var missile = missile_scene.instantiate()
        missile.global_position = spawn.global_position
        missile.global_rotation = -PI / 2
        if missile.has_method("set_target"):
            missile.set_target(target)
        get_tree().current_scene.add_child(missile)

        if muzzle_flash:
            var flash = muzzle_flash.duplicate()
            flash.global_position = spawn.global_position
            flash.visible = true
            get_tree().current_scene.add_child(flash)
            flash.play()
            flash.animation_finished.connect(Callable(flash, "queue_free"))

        await _wait(missile_delay)

func fire_lasers() -> void:
    for wave in range(laser_waves):
        var players = get_tree().get_nodes_in_group("player")
        var player_x = players[0].global_position.x if players.size() > 0 else 0.0
        var tracking_index = randi() % lasers_per_wave

        for i in range(lasers_per_wave):
            var laser = laser_scene.instantiate()
            laser.position.x = player_x if i == tracking_index else randf_range(laser_x_min, laser_x_max)
            laser.position.y = 0
            get_tree().current_scene.add_child(laser)
            if laser.has_method("start_telegraph"):
                laser.start_telegraph(laser_warning_time, laser_duration)

        await _wait(laser_warning_time + laser_duration)
        if wave < laser_waves - 1:
            await _wait(laser_wave_delay)

func _wait(seconds: float) -> void:
    await get_tree().create_timer(seconds).timeout
