extends CharacterBody3D

@export var walk_speed : float = 5.0
@export var sprint_speed : float = 10.0
@export var jump_velocity : float = 4.5
@export var mouse_sensitivity : float = 0.002

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@export var camera_pivot : Node3D
@export var camera : Camera3D

func _ready():

	set_multiplayer_authority(name.to_int())
	print(is_multiplayer_authority())
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if is_multiplayer_authority():
		camera.current = true

func _input(event):
	if not is_multiplayer_authority(): return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)

		camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
		camera_pivot.rotation.x = clamp(
			camera_pivot.rotation.x,
			deg_to_rad(-90),
			deg_to_rad(90)
		)

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta):
	if not is_multiplayer_authority(): return

	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var speed = walk_speed

	if Input.is_action_pressed("sprint"):
		speed = sprint_speed

	var input_dir = Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_backward"
	)

	var direction = (transform.basis * Vector3(
		input_dir.x,
		0,
		input_dir.y
	)).normalized()

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()
