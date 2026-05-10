extends CharacterBody3D

enum State { HIDDEN, CARTON_CLOSED, CARTON_OPENING, CARTON_OPEN, SMOKING }

@onready var head        := $Head
@onready var cigarette           = $Head/Camera3D/ItemAnchor/CigAnchor
@onready var carton              = $Head/Camera3D/ItemAnchor/CigCartonAnchor
@onready var carton_anim: AnimationPlayer = $Head/Camera3D/ItemAnchor/CigCartonAnchor/cigs_carton/AnimationPlayer

var sensitivity := 0.002
const SPEED := 3.0
var state   := State.HIDDEN

var _carton_rest: Vector3
var _cig_rest:    Vector3
const _APPEAR_OFFSET := Vector3(0.0, -0.06, 0.0)
const _APPEAR_TIME   := 0.25
var _carton_tween: Tween
var _cig_tween:    Tween

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_carton_rest = carton.position
	_cig_rest    = cigarette.position
	carton.visible    = false
	cigarette.visible = false
	carton_anim.animation_finished.connect(_on_carton_anim_finished)
	cigarette.burned_out.connect(_on_cigarette_burned_out)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * sensitivity)
		head.rotate_x(-event.relative.y * sensitivity)
		head.rotation.x = clamp(head.rotation.x, -PI/2, PI/2)

	if event is InputEventKey and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if event is InputEventKey and event.is_action_pressed("Smoke") and not event.is_echo():
		if state == State.HIDDEN:
			_enter_carton_closed()
		else:
			_enter_hidden()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			match state:
				State.CARTON_CLOSED:
					_enter_carton_opening()
				State.CARTON_OPEN:
					_enter_smoking()
				State.SMOKING:
					cigarette.start_smoking()
		else:
			if state == State.SMOKING:
				cigarette.stop_smoking()

func _appear(node: Node3D, rest: Vector3) -> Tween:
	var t := create_tween()
	node.position = rest + _APPEAR_OFFSET
	node.visible  = true
	t.tween_property(node, "position", rest, _APPEAR_TIME) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	return t

func _disappear(node: Node3D, rest: Vector3) -> Tween:
	var t := create_tween()
	t.tween_property(node, "position", rest + _APPEAR_OFFSET, _APPEAR_TIME) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	t.tween_callback(func():
		node.visible  = false
		node.position = rest
	)
	return t

func _kill_tweens() -> void:
	if _carton_tween and _carton_tween.is_running():
		_carton_tween.kill()
	if _cig_tween and _cig_tween.is_running():
		_cig_tween.kill()

func _enter_hidden() -> void:
	var prev := state
	state = State.HIDDEN
	_kill_tweens()
	if prev == State.SMOKING:
		cigarette.stop_smoking()
		_cig_tween = _disappear(cigarette, _cig_rest)
	else:
		_reset_carton_anim()
		_carton_tween = _disappear(carton, _carton_rest)

func _enter_carton_closed() -> void:
	state = State.CARTON_CLOSED
	_kill_tweens()
	_carton_tween = _appear(carton, _carton_rest)

func _enter_carton_opening() -> void:
	state = State.CARTON_OPENING
	carton_anim.play("CartonTopOpen")

func _enter_carton_open() -> void:
	state = State.CARTON_OPEN

func _enter_smoking() -> void:
	state = State.SMOKING
	_kill_tweens()
	_carton_tween = _disappear(carton, _carton_rest)
	cigarette.reset_cigarette()
	_cig_tween = _appear(cigarette, _cig_rest)

func _reset_carton_anim() -> void:
	carton_anim.play("CartonTopOpen")
	carton_anim.seek(0.0, true)
	carton_anim.stop()

func _on_carton_anim_finished(_anim_name: StringName) -> void:
	if state == State.CARTON_OPENING:
		_enter_carton_open()

func _on_cigarette_burned_out() -> void:
	_kill_tweens()
	_cig_tween = _disappear(cigarette, _cig_rest)
	_reset_carton_anim()
	state = State.CARTON_CLOSED
	var t := create_tween()
	t.tween_interval(_APPEAR_TIME)
	t.tween_callback(func():
		if state == State.CARTON_CLOSED:
			_carton_tween = _appear(carton, _carton_rest)
	)

func _physics_process(_delta: float) -> void:
	var input := Input.get_vector("Left", "Right", "Fowared", "Back")
	var direction := (transform.basis.x * input.x + transform.basis.z * input.y).normalized()
	var speed := SPEED * 0.5 if cigarette.is_smoking else SPEED
	velocity = direction * speed
	move_and_slide()
