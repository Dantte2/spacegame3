extends CharacterBody2D

# -----------------------------
# EXPORT VARIABLES
# -----------------------------
@export var fire_delay_min := 1.0
@export var fire_delay_max := 2.5
@export var bullet_scene: PackedScene
@export var aim_line_length := 3000.0

@export var bullet_offset := Vector2(50, 0)   
@export var exhaust_offset := Vector2(-50, 0) 

# -----------------------------
# INTERNAL VARIABLES
# -----------------------------
var target: Node2D = null
var can_fire := true

@export var muzzle_delay := 0.90 
@onready var sprite := $Sprite2D
@onready var bullet_spawn := $BulletSpawn
@onready var exhaust := $Exhaust

# --- Health system ---
@export var max_health: int = 150
var health: int
@export var death_animation_scene: PackedScene

# -----------------------------
# READY
# -----------------------------
func _ready():
    health = max_health
    # Setup timer
    if $Timer:
        $Timer.one_shot = true
        $Timer.connect("timeout", Callable(self, "_on_Timer_timeout"))
        _start_timer()

    # Play exhaust
    if exhaust:
        exhaust.visible = true
        exhaust.play()

# -----------------------------
# PROCESS
# -----------------------------
func _process(delta):
    # Find nearest player in "player" group
    var players = get_tree().get_nodes_in_group("player")
    if players.size() > 0:
        target = _get_nearest_player(players)
    else:
        target = null

    if target:
        var dir = (target.global_position - global_position).normalized()

        # Rotate sprite to face player
        if sprite:
            sprite.rotation = dir.angle()

        # Update BulletSpawn position & rotation (nose)
        if bullet_spawn:
            bullet_spawn.global_position = global_position + bullet_offset.rotated(sprite.rotation)
            bullet_spawn.rotation = sprite.rotation

        # Update exhaust position & rotation (rear)
        if exhaust:
            exhaust.global_position = global_position + exhaust_offset.rotated(sprite.rotation)
            exhaust.rotation = sprite.rotation
            if not exhaust.is_playing():
                exhaust.play()

        # Update RayCast2D position & rotation
        if $RayCast2D:
            $RayCast2D.global_position = bullet_spawn.global_position
            $RayCast2D.rotation = sprite.rotation

        # Update aim line
        if $Line2D and can_fire:
            $Line2D.clear_points()
            $Line2D.add_point(bullet_spawn.position)
            $Line2D.add_point(bullet_spawn.position + dir * aim_line_length)

# -----------------------------
# TIMER
# -----------------------------
func _start_timer():
    if $Timer:
        var t = randf_range(fire_delay_min, fire_delay_max)
        $Timer.start(t)

@export var muzzle_flash_scene: PackedScene  # assign your muzzle flash scene here


           
# -----------------------------
# ON TIMER TIMEOUT (firing)
# -----------------------------
func _on_Timer_timeout():
    if not target or not bullet_scene:
        _start_timer()
        return

    # --- Spawn muzzle flash first ---
    if muzzle_flash_scene:
        var flash = muzzle_flash_scene.instantiate()
        bullet_spawn.add_child(flash)  # attach to BulletSpawn
        flash.global_position = bullet_spawn.global_position
        flash.rotation = bullet_spawn.rotation
        if flash.has_method("restart"):
            flash.restart()  # for AnimatedSprite2D or CPUParticles2D

    # --- Wait for muzzle flash duration ---
    await get_tree().create_timer(muzzle_delay).timeout

    # --- Fire bullet ---
    var bullet = bullet_scene.instantiate()
    get_tree().current_scene.add_child(bullet)
    bullet.global_position = bullet_spawn.global_position
    bullet.velocity = (target.global_position - bullet.global_position).normalized() * -1

    _start_timer()



# -----------------------------
# UTILITY: find nearest player
# -----------------------------
func _get_nearest_player(players: Array) -> Node2D:
    var nearest: Node2D = null
    var min_dist = INF
    for p in players:
        var d = global_position.distance_to(p.global_position)
        if d < min_dist:
            min_dist = d
            nearest = p
    return nearest
    
# --- Damage Handling ---
func take_damage(amount: int):
    health -= amount
    if health <= 0:
        die()

func die():
    if death_animation_scene:
        var anim = death_animation_scene.instantiate()
        anim.global_position = global_position
        get_tree().current_scene.call_deferred("add_child", anim)

    queue_free()
