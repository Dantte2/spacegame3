extends CharacterBody2D

@export var speed: float = 750.0
@export var turn_speed: float = 5.0       # How fast the bullet turns toward the target (radians/sec)
@export var damage_to_shield: int = 1
@export var damage_to_health: int = 1

var target: Node = null

func _ready():
    # Find the player (assuming it is in group "player")
    var players = get_tree().get_nodes_in_group("player")
    if players.size() > 0:
        target = players[0]
    
    # Initial velocity pointing toward the target (or left if no target)
    if target:
        velocity = (target.global_position - global_position).normalized() * speed
        rotation = velocity.angle()
    else:
        velocity = Vector2.LEFT * speed
        rotation = velocity.angle()


func _physics_process(delta):
    if target:
        var dir_to_target = (target.global_position - global_position).normalized()
        velocity = velocity.lerp(dir_to_target * speed, turn_speed * delta)
    else:
        velocity = velocity.normalized() * speed

    # Move bullet and detect collision
    var collision = move_and_collide(velocity * delta)
    if collision:
        _handle_hit(collision.get_collider())
        return  # Stop processing after hitting

    rotation = velocity.angle()

func _on_body_entered(body):
    _handle_hit(body)

func _on_area_entered(area):
    _handle_hit(area)


func _handle_hit(target_node):
    var player = target_node
    while player and not player.has_method("take_damage"):
        player = player.get_parent()
    if not player:
        return

    if player.shield > 0:
        player.apply_shield_damage(damage_to_shield, global_position)
    else:
        player.take_damage(damage_to_health)

    queue_free()
