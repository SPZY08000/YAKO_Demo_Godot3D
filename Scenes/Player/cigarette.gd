extends Node3D

signal burned_out

# 燃烧阶段节点
@onready var cig_full = $Cig2/Cig
@onready var burn0    = $Cig2/CigBurn0
@onready var burn1    = $Cig2/CigBurn1
@onready var burn2    = $Cig2/CigBurn2
@onready var smoke    = $SmokeParticle

var smoke_elapsed  = 0.0
const BURN0_TIME   = 5.0
const BURN1_TIME   = 10.0
const BURN2_TIME   = 15.0

var is_smoking = false
var ember: GPUParticles3D
var _stage := -1

func _ready() -> void:
	_setup_smoke_particles()
	smoke.emitting = false
	_set_stage(0)

func start_smoking() -> void:
	is_smoking = true
	smoke.emitting = true
	ember.emitting = true

func stop_smoking() -> void:
	is_smoking = false
	smoke.emitting = false
	ember.emitting = false

func reset_cigarette() -> void:
	smoke_elapsed = 0.0
	_set_stage(0)

func _process(delta):
	if not is_smoking:
		return
	smoke_elapsed += delta
	var new_stage: int
	if smoke_elapsed < BURN0_TIME:
		new_stage = 0
	elif smoke_elapsed < BURN1_TIME:
		new_stage = 1
	elif smoke_elapsed < BURN2_TIME:
		new_stage = 2
	else:
		stop_smoking()
		burned_out.emit()
		return
	if new_stage != _stage:
		_set_stage(new_stage)

func _set_stage(stage: int) -> void:
	_stage = stage
	_show_stage(stage)

func _show_stage(stage: int) -> void:
	cig_full.visible = (stage == 0)
	burn0.visible    = (stage == 1)
	burn1.visible    = (stage == 2)
	burn2.visible    = (stage == 3)
	_sync_tip(stage)

func _sync_tip(stage: int) -> void:
	var roots := [cig_full, burn0, burn1, burn2]
	if stage >= roots.size():
		return
	var root := roots[stage] as Node3D
	var mi: MeshInstance3D = null
	if root is MeshInstance3D:
		mi = root as MeshInstance3D
	else:
		for child in root.find_children("*", "MeshInstance3D", true, false):
			mi = child as MeshInstance3D
			break
	if mi == null:
		return
	var aabb := mi.get_aabb()
	var c := aabb.get_center()
	# Tip = face center farthest from the camera — lit end always points away from the face
	var cam := get_viewport().get_camera_3d()
	var cam_pos: Vector3 = cam.global_position if cam != null else global_position
	var candidates := [
		c + Vector3(aabb.size.x * 0.5, 0, 0),
		c - Vector3(aabb.size.x * 0.5, 0, 0),
		c + Vector3(0, aabb.size.y * 0.5, 0),
		c - Vector3(0, aabb.size.y * 0.5, 0),
		c + Vector3(0, 0, aabb.size.z * 0.5),
		c - Vector3(0, 0, aabb.size.z * 0.5),
	]
	var best_dist := -INF
	var tip: Vector3 = smoke.position
	for pt in candidates:
		var world_pos := mi.to_global(pt)
		var dist := world_pos.distance_squared_to(cam_pos)
		if dist > best_dist:
			best_dist = dist
			tip = to_local(world_pos)
	smoke.position = tip
	if ember != null:
		ember.position = tip

func _setup_smoke_particles() -> void:
	# CigAnchor is scaled ~0.15; with local_coords=true all sizes/velocities live in
	# that local space, so compensate with the inverse scale. Direction and gravity
	# are rotated into local space so they still act as world-up in the simulation.
	var gs      : float = smoke.global_transform.basis.x.length()
	var inv     : float = 1.0 / maxf(gs, 0.001)
	var b_inv   : Basis = smoke.global_transform.basis.inverse()
	var local_up: Vector3 = (b_inv * Vector3.UP).normalized()

	var smoke_mat := StandardMaterial3D.new()
	smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	smoke_mat.vertex_color_use_as_albedo = true

	var smoke_quad := QuadMesh.new()
	smoke_quad.size = Vector2(0.007, 0.007)
	smoke_quad.material = smoke_mat
	smoke.draw_pass_1 = smoke_quad

	var smoke_process := ParticleProcessMaterial.new()
	smoke_process.direction = local_up
	smoke_process.spread = 30.0
	smoke_process.initial_velocity_min = 0.05 * inv
	smoke_process.initial_velocity_max = 0.10 * inv
	smoke_process.gravity = b_inv * Vector3(0, 0.02, 0)

	var smoke_grad := Gradient.new()
	smoke_grad.set_color(0, Color(0.4, 0.4, 0.4, 0.4))
	smoke_grad.set_color(1, Color(0.55, 0.55, 0.55, 0.0))
	var smoke_grad_tex := GradientTexture1D.new()
	smoke_grad_tex.gradient = smoke_grad
	smoke_process.color_ramp = smoke_grad_tex

	smoke_process.scale_min = 0.8
	smoke_process.scale_max = 1.5

	smoke.process_material = smoke_process
	smoke.amount = 8
	smoke.lifetime = 0.7
	smoke.explosiveness = 0.0
	smoke.randomness = 0.6
	smoke.local_coords = true

	ember = GPUParticles3D.new()
	add_child(ember)
	ember.position = smoke.position

	var ember_mat := StandardMaterial3D.new()
	ember_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ember_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ember_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	ember_mat.vertex_color_use_as_albedo = true

	var ember_quad := QuadMesh.new()
	ember_quad.size = Vector2(0.003, 0.003)
	ember_quad.material = ember_mat
	ember.draw_pass_1 = ember_quad

	var ember_process := ParticleProcessMaterial.new()
	ember_process.direction = local_up
	ember_process.spread = 30.0
	ember_process.initial_velocity_min = 0.03 * inv
	ember_process.initial_velocity_max = 0.07 * inv
	ember_process.gravity = b_inv * Vector3(0, -0.05, 0)

	var ember_grad := Gradient.new()
	ember_grad.set_color(0, Color(1.0, 0.45, 0.0, 1.0))
	ember_grad.set_color(1, Color(0.8, 0.1, 0.0, 0.0))
	var ember_grad_tex := GradientTexture1D.new()
	ember_grad_tex.gradient = ember_grad
	ember_process.color_ramp = ember_grad_tex

	ember_process.scale_min = 0.5
	ember_process.scale_max = 1.0

	ember.process_material = ember_process
	ember.amount = 3
	ember.lifetime = 0.3
	ember.explosiveness = 0.0
	ember.randomness = 1.0
	ember.local_coords = true
	ember.emitting = false
