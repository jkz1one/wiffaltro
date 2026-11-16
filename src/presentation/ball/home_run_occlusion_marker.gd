class_name HomeRunOcclusionMarker
extends Node2D
## A hollow location cue, never a replacement ball or a physics/visibility guarantee.

const SAMPLE_SECONDS: float = 0.10
const FADE_IN_SECONDS: float = 0.15
const FADE_OUT_SECONDS: float = 0.20
const RADIUS_PIXELS: float = 5.0
const TERRAIN_QUERY_REACH: float = 1000.0
const TERRAIN_QUERY_LIMIT: int = 32
const Occlusion = preload("res://src/presentation/ball/home_run_visual_occlusion.gd")

var opacity: float = 0.0
var blocked: bool = false
var _point: Vector2
var _sample_elapsed: float = SAMPLE_SECONDS
var _lab: WeakRef
var _ball: WeakRef
var _camera: WeakRef
var _owner: WeakRef
var _generation: int = -1
var _layer: CanvasLayer


static func attach(lab: PitchBatLab, owner: PitchBatLabHomeRun) -> HomeRunOcclusionMarker:
	if not is_instance_valid(lab._camera) or not is_instance_valid(lab._batted_ball):
		return null
	var marker := HomeRunOcclusionMarker.new()
	marker._lab = weakref(lab)
	marker._ball = weakref(lab._batted_ball)
	marker._camera = weakref(lab._camera)
	marker._owner = weakref(owner)
	marker._generation = owner._generation
	marker._layer = CanvasLayer.new()
	marker._layer.name = "HomeRunLocationCue"
	# Behind normal HUD; no control node or input capture.
	marker._layer.layer = 0
	lab.add_child(marker._layer)
	if (
		not is_instance_valid(lab)
		or lab.is_queued_for_deletion()
		or not is_instance_valid(marker._layer)
		or marker._layer.is_queued_for_deletion()
	):
		if is_instance_valid(marker._layer) and not marker._layer.is_queued_for_deletion():
			marker._layer.queue_free()
		marker.free()
		return null
	marker._layer.add_child(marker)
	if not is_instance_valid(marker):
		return null
	if (
		marker.is_queued_for_deletion()
		or not is_instance_valid(marker._layer)
		or marker._layer.is_queued_for_deletion()
	):
		marker.dispose()
		return null
	return marker


func dispose() -> void:
	blocked = false
	opacity = 0.0
	var layer: CanvasLayer = _layer
	set_process(false)
	hide()
	if is_instance_valid(layer) and not layer.is_queued_for_deletion():
		layer.queue_free()
	elif is_instance_valid(self) and not is_queued_for_deletion():
		queue_free()


func _process(delta: float) -> void:
	var lab: PitchBatLab = _lab.get_ref() as PitchBatLab if _lab != null else null
	var ball: BattedBallBody = _ball.get_ref() as BattedBallBody if _ball != null else null
	var camera: Camera3D = _camera.get_ref() as Camera3D if _camera != null else null
	var owner: PitchBatLabHomeRun = (
		_owner.get_ref() as PitchBatLabHomeRun if _owner != null else null
	)
	if not _context_valid(lab, ball, camera, owner):
		dispose()
		return
	var projectable: bool = not camera.is_position_behind(ball.global_position)
	if projectable:
		_point = camera.unproject_position(ball.global_position)
		var safe: Rect2 = get_viewport_rect().grow(-RADIUS_PIXELS - 2.0)
		projectable = _point.is_finite() and safe.has_point(_point)
	_sample_elapsed += maxf(0.0, delta)
	if owner.flight_complete or not projectable:
		blocked = false
	elif _sample_elapsed >= SAMPLE_SECONDS:
		_sample_elapsed = 0.0
		blocked = _terrain_clear(lab, camera, ball) and Occlusion.blocked(lab, camera, ball)
	advance_fade(delta, blocked)
	# Never leave a stale screen point on camera reversal or viewport exit.
	visible = projectable and opacity > 0.0
	queue_redraw()


func _context_valid(
	lab: PitchBatLab, ball: BattedBallBody, camera: Camera3D, owner: PitchBatLabHomeRun
) -> bool:
	return (
		is_instance_valid(lab)
		and not lab.is_queued_for_deletion()
		and is_instance_valid(ball)
		and is_instance_valid(camera)
		and not camera.is_queued_for_deletion()
		and camera.is_inside_tree()
		and owner != null
		and owner._generation == _generation
		and lab._home_run == owner
		and lab._camera == camera
		and lab._batted_ball == ball
		and owner.presentation_pending(lab)
	)


func _terrain_clear(lab: PitchBatLab, camera: Camera3D, ball: BattedBallBody) -> bool:
	var target: Vector3 = ball.global_position
	if not target.is_finite():
		return false
	# Preserve below-terrain refusal within the existing 1000m stadium query envelope.
	# Missing finite ground below an airborne ball is not itself a reason to hide a cue.
	if not _ground_segment_clear(lab, ball, target, target + Vector3.UP * TERRAIN_QUERY_REACH):
		return false
	var start: Vector3 = camera.project_position(camera.unproject_position(target), camera.near)
	return _ground_segment_clear(lab, ball, start, target)


func _ground_segment_clear(
	lab: PitchBatLab, ball: BattedBallBody, start: Vector3, end: Vector3
) -> bool:
	if not start.is_finite() or not end.is_finite():
		return false
	var ray := PhysicsRayQueryParameters3D.create(start, end, 1)
	var excluded: Array[RID] = [ball.get_rid()]
	ray.hit_from_inside = true
	ray.hit_back_faces = true
	for step: int in range(TERRAIN_QUERY_LIMIT):
		ray.exclude = excluded
		var hit: Dictionary = lab.get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.is_empty():
			return true
		if not _skip_non_ground_hit(hit, excluded):
			return false
	# Never treat an exhausted traversal as proof that terrain is absent.
	return false


func _skip_non_ground_hit(hit: Dictionary, excluded: Array[RID]) -> bool:
	var collider: Variant = hit.get("collider")
	var rid: Variant = hit.get("rid")
	if not is_instance_valid(collider) or not collider is CollisionObject3D:
		return false
	if not rid is RID or not rid.is_valid() or excluded.has(rid):
		return false
	if collider.get_rid() != rid or collider.get_meta(&"ball_surface", &"") == &"ground":
		return false
	excluded.append(rid)
	return true


func advance_fade(delta: float, show_cue: bool) -> void:
	var duration: float = FADE_IN_SECONDS if show_cue else FADE_OUT_SECONDS
	opacity = move_toward(opacity, 1.0 if show_cue else 0.0, maxf(0.0, delta) / duration)


func _draw() -> void:
	if opacity <= 0.0:
		return
	draw_arc(_point, RADIUS_PIXELS, 0, TAU, 24, Color(0.05, 0.08, 0.1, 0.65 * opacity), 2.5, true)
	draw_arc(_point, RADIUS_PIXELS, 0, TAU, 24, Color(1, 0.98, 0.85, 0.8 * opacity), 1, true)
