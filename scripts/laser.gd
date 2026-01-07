extends Area2D

# --- Bullet properties ---
var velocity: Vector2 = Vector2.ZERO
@export var lifetime := 10.0
@export var damage: int = 15
var has_hit := false  # track if bullet hit something

# --- Impact rate limiting ---
@export var impact_cooldown := 0.10  # seconds
static var can_spawn_impact := true

func _ready():
    if has_node("AnimatedSprite2D"):
        $AnimatedSprite2D.play()
    if has_node("Impact"):
        $Impact.visible = false

    if has_node("CollisionShape2D"):
        connect("body_entered", Callable(self, "_on_body_entered"))

    # Delete after lifetime
    await get_tree().create_timer(lifetime).timeout
    queue_free()

func _physics_process(delta):
    if not has_hit:
        position += velocity * delta

func _on_body_entered(body):
    if has_hit:
        return
    if not body.is_in_group("enemy"):
        return

    has_hit = true

    # Apply damage every bullet
    if body.has_method("take_damage"):
        body.take_damage(damage)

    # Stop visuals
    if has_node("AnimatedSprite2D"):
        $AnimatedSprite2D.visible = false
    if has_node("Trail2D"):
        $Trail2D.visible = false
    if has_node("CollisionShape2D"):
        $CollisionShape2D.call_deferred("set_disabled", true)

    # --- Impact with cooldown ---
    if can_spawn_impact and has_node("Impact"):
        can_spawn_impact = false
        $Impact.visible = true
        $Impact.modulate = Color(2.787, 2.058, 0.576)
        $Impact.play("default")
        $Impact.animation_finished.connect(Callable(self, "queue_free"))

        # Reset cooldown using a timer
        var t = Timer.new()
        t.wait_time = impact_cooldown
        t.one_shot = true
        t.autostart = true
        add_child(t)
        t.timeout.connect(Callable(self, "_reset_impact_cooldown"))
    else:
        queue_free()

func _reset_impact_cooldown():
    can_spawn_impact = true
