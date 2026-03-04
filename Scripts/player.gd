extends CharacterBody3D

const SPEED = 4.317*60
const JUMP = 400
const SENS = 0.004
var focus : bool = false
@onready var cam: Camera3D = $Camera3D
var spawn : Vector3i = Vector3i.ZERO
@onready var line_edit: LineEdit = $"../Control/VBoxContainer/LineEdit"
@onready var pause_menu: ColorRect = $"../Control/PauseMenu"

func _ready() -> void:
	GrabFocus()
	line_edit.hide()
	pause_menu.hide()

func GrabFocus() -> void:
	focus = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func ReleaseFocus() -> void:
	focus = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _input(event):
	if event is InputEventMouseMotion and focus:
		rotation.y -= event.relative.x * SENS
		cam.rotation.x -= event.relative.y * SENS
		cam.rotation.x = clamp(cam.rotation.x, deg_to_rad(-89), deg_to_rad(89))

func _physics_process(delta):
	# --- Input handling ---
	if Input.is_action_just_pressed("ui_cancel"):
		if line_edit.visible:
			line_edit.hide()
			line_edit.release_focus()
			GrabFocus()
		elif pause_menu.visible:
			pause_menu.hide()
			GrabFocus()
		else:
			pause_menu.show()
			ReleaseFocus()

	# --- Movement (blocked when any UI is open) ---
	var ui_open = line_edit.visible or pause_menu.visible

	if not ui_open:
		if Input.is_action_just_pressed("Chat"):
			if line_edit.visible:
				line_edit.hide()
				line_edit.release_focus()
				GrabFocus()
			else:
				line_edit.show()
				line_edit.grab_focus()
				ReleaseFocus()
			
		if Input.is_action_pressed("Respawn"):
			self.velocity = Vector3.ZERO
			self.global_position = spawn

		if not is_on_floor():
			velocity += get_gravity() * delta
		elif Input.is_action_pressed("Jump"):
			self.velocity.y = JUMP * delta

		var input_dir := Input.get_vector("Strafe Left", "Strafe Right", "Backward", "Forward")
		var forward = -transform.basis.z
		var right = transform.basis.x
		var dir = (forward * input_dir.y + right * input_dir.x).normalized()

		if dir != Vector3.ZERO:
			velocity.x = dir.x * SPEED * delta
			velocity.z = dir.z * SPEED * delta
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED * delta)
			velocity.z = move_toward(velocity.z, 0, SPEED * delta)
	else:
		if not is_on_floor():
			velocity += get_gravity() * delta
		velocity.x = move_toward(velocity.x, 0, SPEED * delta)
		velocity.z = move_toward(velocity.z, 0, SPEED * delta)

	move_and_slide()

func _on_return_to_game() -> void:
	pause_menu.hide()
	GrabFocus()
