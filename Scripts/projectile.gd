extends CharacterBody2D

signal hit_target(target: Node)

@export var SPEED: float = 300.0

var direction: Vector2 = Vector2.RIGHT
var is_active: bool = true
var target: Node = null
var can_collide: bool = false  # Ignore collisions for the first frame
var frame_count: int = 0

func _ready():
	print("[Projectile._ready] START")
	
	# Make the projectile and sprite visible
	visible = true
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		print("[Projectile._ready] Sprite2D found")
		sprite.visible = true
		sprite.z_index = 10
		print("[Projectile._ready] Sprite texture: ", sprite.texture)
		print("[Projectile._ready] Sprite scale: ", sprite.scale)
		print("[Projectile._ready] Sprite modulate: ", sprite.modulate)
	else:
		print("[Projectile._ready] ERROR: Sprite2D NOT found!")
	
	# Initialize velocity based on rotation
	velocity = Vector2(SPEED, 0).rotated(global_rotation)
	
	# Make sure physics layer collision is enabled
	collision_mask = 3
	collision_layer = 1
	z_index = 10
	
	print("[Projectile._ready] Position: ", global_position, " Rotation: ", global_rotation)
	print("[Projectile._ready] Visible: ", visible, " Z-index: ", z_index)
	var parent_name = "NULL"
	if get_parent() != null:
		parent_name = get_parent().name
	print("[Projectile._ready] Parent: ", parent_name)
	
	# Enable collision detection after a tiny delay to avoid self-collision
	await get_tree().process_frame
	can_collide = true
	print("[Projectile._ready] DONE - can_collide=true")

func _physics_process(delta: float):
	frame_count += 1
	
	if not is_active:
		return
	
	# Move in the set direction
	velocity = Vector2(SPEED, 0).rotated(global_rotation)
	var collision = move_and_collide(velocity * delta)
	
	# Debug first frame
	if frame_count == 1:
		print("[Projectile._physics_process] Frame 1 - Pos: ", global_position, " Visible: ", visible)
		var sprite = get_node_or_null("Sprite2D")
		if sprite:
			print("[Projectile._physics_process] Sprite visible: ", sprite.visible, " offset: ", sprite.offset)
	
	# Handle collision (only if we're allowed to collide)
	if collision and can_collide:
		var collider = collision.get_collider()
		print("[Projectile] Hit: ", collider.name if collider else "unknown")
		is_active = false
		hit_target.emit(collider)
		queue_free()

func set_target(target_node: Node) -> void:
	target = target_node

func set_direction_to_target(start_pos: Vector2, target_pos: Vector2) -> void:
	var dir = (target_pos - start_pos).normalized()
	global_rotation = dir.angle()
