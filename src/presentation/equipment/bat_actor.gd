class_name BatActor
extends Node3D

const DEFAULT_SWING_SECONDS: float = 0.26
const FOLLOW_THROUGH_HOLD_SECONDS: float = 0.10
const SLOT_SPLIT: float = 0.34
const EXTENSION_SPLIT: float = 0.48
const STANCE_YAW_DEGREES: float = 72.0
const SLOT_YAW_DEGREES: float = 38.0
const CONTACT_YAW_DEGREES: float = 0.0
const EXTENSION_YAW_DEGREES: float = -28.0
const FINISH_YAW_DEGREES: float = -102.0
const STANCE_AXIS_TILT_DEGREES: float = 54.0
const SLOT_AXIS_TILT_DEGREES: float = 68.0
const CONTACT_AXIS_TILT_DEGREES: float = 88.0
const EXTENSION_AXIS_TILT_DEGREES: float = 78.0
const FINISH_AXIS_TILT_DEGREES: float = 42.0

var cosmetic_id: String = ""
var bats_left: bool = false

var _bat_visual: MeshInstance3D

var _pivot: Node3D
var _bat_axis: Node3D
var _swing_elapsed: float = 0.0
var _swing_duration: float = DEFAULT_SWING_SECONDS
var _sweet_spot_progress: float = 0.44
var _attack_angle_degrees: float = 7.0
var _swinging: bool = false
var _aim_pose: Vector2 = Vector2.ZERO


func _ready() -> void:
	_build_bat()
	_apply_stance()


func configure(new_bats_left: bool, batter_position: Vector3) -> void:
	bats_left = new_bats_left
	position = batter_position
	if _pivot != null:
		reset_swing()


func play_swing(profile: SwingProfileDefinition) -> void:
	if profile == null:
		return
	_swing_duration = profile.swing_duration_seconds
	_sweet_spot_progress = clampf(
		profile.sweet_spot_seconds / maxf(0.001, _swing_duration), 0.25, 0.72
	)
	_attack_angle_degrees = profile.attack_angle_degrees
	_swing_elapsed = 0.0
	_swinging = true
	_apply_stance()


func set_aim_pose(normalized_aim: Vector2) -> void:
	_aim_pose = Vector2(clampf(normalized_aim.x, -1.0, 1.0), clampf(normalized_aim.y, -1.0, 1.0))
	if not _swinging and _pivot != null:
		_apply_stance()


func reset_swing() -> void:
	_swinging = false
	_swing_elapsed = 0.0
	if _pivot != null:
		_apply_stance()


func _process(delta: float) -> void:
	if not _swinging or _pivot == null:
		return
	_swing_elapsed += maxf(0.0, delta)
	_apply_swing_pose(minf(_swing_elapsed, _swing_duration))
	if _swing_elapsed >= _swing_duration + FOLLOW_THROUGH_HOLD_SECONDS:
		reset_swing()


func _apply_swing_pose(elapsed_seconds: float) -> void:
	var side: float = handed_side(bats_left)
	var phases: Vector2 = phase_progress_at_elapsed(
		elapsed_seconds, _sweet_spot_progress * _swing_duration, _swing_duration
	)
	var aim_influence: float = aim_influence_at_phases(phases)
	_pivot.position = (
		pivot_position_at_elapsed(
			bats_left, elapsed_seconds, _sweet_spot_progress * _swing_duration, _swing_duration
		)
		+ aim_pose_position_offset(_aim_pose) * aim_influence
	)
	_pivot.rotation = Vector3(
		deg_to_rad(-_attack_angle_degrees),
		deg_to_rad(
			(
				yaw_degrees_at_elapsed(
					bats_left,
					elapsed_seconds,
					_sweet_spot_progress * _swing_duration,
					_swing_duration
				)
				+ aim_pose_yaw_offset_degrees(_aim_pose) * aim_influence
			)
		),
		0.0
	)
	_bat_axis.rotation.z = deg_to_rad(
		(
			-side
			* (
				axis_tilt_degrees_at_elapsed(
					elapsed_seconds, _sweet_spot_progress * _swing_duration, _swing_duration
				)
				+ aim_pose_axis_tilt_degrees(_aim_pose) * aim_influence
			)
		)
	)


func _build_bat() -> void:
	_pivot = Node3D.new()
	_pivot.name = "SwingPivot"
	add_child(_pivot)
	_bat_axis = Node3D.new()
	_bat_axis.name = "BatAxis"
	_pivot.add_child(_bat_axis)
	_bat_visual = MeshInstance3D.new()
	_bat_visual.name = "BatVisual"
	_bat_visual.set_meta("visual_only", true)
	_bat_axis.add_child(_bat_visual)
	_refresh_cosmetic()


static func cosmetic_ids() -> Array[String]:
	# Nine existing equipment identities. Empty is the unpaid yellow plastic bat.
	return [
		"",
		"BAT-CON-01",
		"BAT-CON-02",
		"BAT-CON-03",
		"BAT-POW-01",
		"BAT-POW-02",
		"BAT-POW-03",
		"A02",
		"BAT-ALY-02",
		"BAT-ALY-03"
	]


func set_cosmetic(id: String) -> void:
	var selected: String = id if id in cosmetic_ids() else ""
	if selected == cosmetic_id:
		return
	cosmetic_id = selected
	if is_instance_valid(_bat_visual):
		_refresh_cosmetic()


func _refresh_cosmetic() -> void:
	# Presentation only: no collision shape, swing profile or contact dimensions change.
	# Replace resources, rather than modifying a resource held by the camera cutaway.
	_bat_visual.mesh = _cosmetic_mesh(cosmetic_id)
	var paint: Image = Image.new()
	var error: Error = paint.load_svg_from_string(_paint_svg(cosmetic_id))
	if error != OK:
		push_error("Bat cosmetic paint failed for %s: %s" % [cosmetic_id, error])
		return
	paint.generate_mipmaps()
	var material: StandardMaterial3D = _material(Color.WHITE)
	material.albedo_texture = ImageTexture.create_from_image(paint)
	material.roughness = 0.38
	material.metallic = 0.0
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_bat_visual.material_override = material
	_bat_visual.set_meta("cosmetic_id", cosmetic_id)


static func _cosmetic_mesh(id: String) -> ArrayMesh:
	# Ring coordinates are (height, radius). All styles retain the original hand
	# anchor and total -0.065..1.0 m visual reach; silhouettes are cosmetic only.
	var barrel: float = 0.055
	if id == "BAT-CON-01":
		barrel = 0.066
	elif id == "BAT-CON-02":
		barrel = 0.077
	elif id == "BAT-CON-03":
		barrel = 0.100
	var profile: PackedVector2Array = PackedVector2Array(
		[
			Vector2(-0.065, 0.0),
			Vector2(-0.062, 0.026),
			Vector2(-0.053, 0.038),
			Vector2(-0.032, 0.040),
			Vector2(-0.012, 0.032),
			Vector2(0.012, 0.025),
			Vector2(0.08, 0.023),
			Vector2(0.27, 0.024),
			Vector2(0.34, 0.028),
			Vector2(0.43, 0.036),
			Vector2(0.56, barrel * 0.90),
			Vector2(0.68, barrel),
			Vector2(0.91, barrel),
			Vector2(0.974, barrel * 0.96),
			Vector2(0.994, barrel * 0.78),
			Vector2(1.0, 0.0)
		]
	)
	if id == "BAT-POW-02":
		# Loaded is visibly end-weighted: a narrow neck, stepped shoulder and heavy cap.
		# Its original gameplay radii and swing remain entirely independent of this mesh.
		profile = PackedVector2Array(
			[
				Vector2(-0.065, 0.0),
				Vector2(-0.062, 0.026),
				Vector2(-0.045, 0.039),
				Vector2(-0.015, 0.032),
				Vector2(0.015, 0.024),
				Vector2(0.28, 0.023),
				Vector2(0.43, 0.031),
				Vector2(0.56, 0.042),
				Vector2(0.66, 0.050),
				Vector2(0.72, 0.069),
				Vector2(0.78, 0.081),
				Vector2(0.91, 0.081),
				Vector2(0.955, 0.081),
				Vector2(0.975, 0.075),
				Vector2(0.994, 0.060),
				Vector2(1.0, 0.0)
			]
		)
	elif id == "BAT-POW-03":
		# The owner's torpedo reference swells below the tip, then narrows again.
		profile = PackedVector2Array(
			[
				Vector2(-0.065, 0.0),
				Vector2(-0.062, 0.028),
				Vector2(-0.045, 0.040),
				Vector2(-0.015, 0.032),
				Vector2(0.015, 0.024),
				Vector2(0.28, 0.023),
				Vector2(0.40, 0.029),
				Vector2(0.51, 0.043),
				Vector2(0.63, 0.062),
				Vector2(0.73, 0.068),
				Vector2(0.82, 0.065),
				Vector2(0.91, 0.055),
				Vector2(0.975, 0.052),
				Vector2(0.993, 0.046),
				Vector2(1.0, 0.0)
			]
		)
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	const SIDES: int = 48
	for ring: int in range(profile.size()):
		var p: Vector2 = profile[ring]
		var before: Vector2 = profile[maxi(0, ring - 1)]
		var after: Vector2 = profile[mini(profile.size() - 1, ring + 1)]
		var slope: float = (after.y - before.y) / maxf(0.0001, after.x - before.x)
		var flatten: float = 1.0
		if id == "BAT-CON-03":
			flatten = lerpf(1.0, 0.27, smoothstep(0.28, 0.57, p.x))
		for side: int in range(SIDES + 1):
			var angle: float = TAU * float(side) / float(SIDES)
			vertices.append(Vector3(cos(angle) * p.y, p.x, sin(angle) * p.y * flatten))
			var normal: Vector3 = Vector3(cos(angle), -slope, sin(angle) / flatten).normalized()
			if ring == 0:
				normal = Vector3.DOWN
			elif ring == profile.size() - 1:
				normal = Vector3.UP
			normals.append(normal)
			uvs.append(Vector2(float(side) / float(SIDES), (1.0 - p.x) / 1.065))
			if ring < profile.size() - 1 and side < SIDES:
				var a: int = ring * (SIDES + 1) + side
				var b: int = a + SIDES + 1
				indices.append_array(PackedInt32Array([a, a + 1, b, a + 1, b + 1, b]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _paint_svg(id: String) -> String:
	# Authored paint, not a new equipment catalog. StandardMaterial3D keeps the
	# same ordinary batting-camera cutaway/fade path as the old unpainted bat.
	var ground: String = "#f4ce20"
	var art: String = ""
	match id:
		"BAT-CON-01":
			# The broad original silhouette remains yellow, with a blue V at its lower barrel.
			ground = "#f4ce20"
			art = (
				'<path d="M0 350L64 425L128 350L192 425L256 350V405L192 480L128 405L64 480L0 405Z" '
				+ 'fill="#2377b5"/>'
			)
			# Straight circumferential blue band at the narrow handle-to-barrel transition.
			art += '<path data-wide-junction-band="blue" d="M0 560H256V588H0Z" fill="#2377b5"/>'
		"BAT-CON-02":
			# Broad red/orange/yellow chevrons from the owner's first, favored reference.
			ground = "#f2c728"
			art = '<path d="M0 0H256V260L192 400L128 260L64 400L0 260Z" fill="#e87921"/>'
			art += '<path d="M0 0H256V180L192 320L128 180L64 320L0 180Z" fill="#c92b34"/>'
			art += '<path d="M0 690H256V986H0Z" fill="#536778"/>'
		"BAT-CON-03":
			ground = "#309c5b"
			art = (
				'<path d="M0 350L64 410L128 350L192 410L256 350V391L192 451L128 391L64 451L0 391Z" '
				+ 'fill="#c5e7a2"/>'
			)
			art += '<path d="M0 625H256V647H0Z M0 677H256V986H0Z" fill="#184d3b"/>'
		"BAT-POW-01":
			# Broad overlapping electrical-tape turns centered on the sweet mid-barrel.
			for y: int in [126, 170, 214, 258]:
				art += (
					'<path d="M-128 %dL384 %dV%dL-128 %dZ" fill="#202428" stroke="#34383c" stroke-width="2"/>'
					% [y - 24, y + 24, y + 86, y + 38]
				)
		"BAT-POW-02":
			ground = "#333c42"
			art = '<path d="M0 0H256V67H0Z M0 215H256V246H0Z" fill="#171e24"/>'
			art += '<path d="M0 68H256V84H0Z M0 247H256V267H0Z" fill="#b7a477"/>'
			art += '<path d="M0 291H256V310H0Z" fill="#75838b"/>'
			for x: int in [18, 82, 146, 210]:
				art += '<path d="M%d 90H%dV213H%dZ" fill="#56646c"/>' % [x, x + 12, x]
			art += '<path d="M0 690H256V986H0Z" fill="#22282b"/>'
		"PREVIEW-LIBERTY":
			ground = "#f3eee0"
			for y: int in range(270, 700, 72):
				art += (
					'<path d="M-128 %dL384 %dV%dL-128 %dZ" fill="#b62b39"/>'
					% [y - 32, y + 32, y + 66, y + 2]
				)
			art += '<path d="M0 0H256V275H0Z" fill="#173568"/>'
			for y: int in [55, 128, 201]:
				for x: int in [32, 96, 160, 224]:
					art += _svg_star(Vector2(x, y), 15.0, "#f9f5e8")
			art += '<path d="M0 720H256V986H0Z" fill="#263447"/>'
		"BAT-POW-03":
			ground = "#17283e"
			for x: int in [64, 192]:
				# Actual crescent outline; the ball and trailing arc pass over its upper edge.
				art += (
					'<path d="M%d 139A33 39 0 1 0 %d 207A27 35 0 0 1 %d 139Z" fill="#f7f5e7"/>'
					% [x + 15, x + 15, x + 15]
				)
				art += (
					(
						'<path d="M%d 208C%d 105 %d 58 %d 100" fill="none" stroke="#f7f5e7" '
						+ 'stroke-width="5" stroke-linecap="round"/>'
					)
					% [x - 42, x - 62, x + 24, x + 38]
				)
				art += '<circle cx="%d" cy="100" r="11" fill="#ffffff"/>' % [x + 38]
			for point: Vector2 in [
				Vector2(24, 280),
				Vector2(109, 336),
				Vector2(53, 463),
				Vector2(171, 293),
				Vector2(223, 421)
			]:
				art += _svg_star(point, 5.0, "#f7f5e7")
			art += '<path d="M0 653H256V666H0Z" fill="#c7ae68"/>'
		"A02":
			# Original copper grid, with a restrained redder/darker gradient toward the tip; no decal.
			ground = "#bd642e"
			art = (
				'<defs><linearGradient id="alley-copper" x1="0" y1="1" x2="0" y2="0"><stop '
				+ 'offset="0" stop-color="#bd642e"/><stop offset="1" '
				+ 'stop-color="#ae5530"/></linearGradient></defs><rect '
				+ 'data-alley-finish="subtle-copper-gradient" width="256" height="700" '
				+ 'fill="url(#alley-copper)"/>'
			)
			for y: int in range(35, 665, 76):
				var offset: int = 24 if (y / 76) % 2 == 0 else 0
				art += (
					(
						'<path d="M0 %dH256M%d %dV%dM%d %dV%d" fill="none" stroke="#e8bb75" '
						+ 'stroke-width="2" opacity="0.38"/>'
					)
					% [y, 30 + offset, y, y + 76, 158 + offset, y, y + 76]
				)
			art += '<path d="M0 655H256V671H0Z M0 704H256V986H0Z" fill="#533c2f"/>'
		"BAT-ALY-02":
			# Gap Finder: crisp digital sports telemetry, never military insignia.
			ground = "#163449"
			art = '<defs><clipPath id="gf-radar"><circle r="102"/></clipPath></defs>'
			art += '<path d="M0 0H256V56H0Z" fill="#55ed73"/><path d="M0 610H256V636H0Z" fill="#e7bf6b"/>'
			for x: int in [64, 192]:
				art += (
					(
						'<g transform="translate(%d 255) scale(0.45 1)"><circle r="105" fill="#122c3e" '
						+ 'stroke="#78ff80" stroke-width="3"/><g clip-path="url(#gf-radar)">'
					)
					% x
				)
				# Fine Cartesian grid and range rings stay legible through the barrel's mipmaps.
				for grid: int in range(-84, 85, 21):
					art += (
						(
							'<path d="M-102 %dH102M%d-102V102" fill="none" stroke="#318b51" '
							+ 'stroke-width="1.8" opacity="0.78"/>'
						)
						% [grid, grid]
					)
				for radius: int in [26, 52, 78]:
					art += '<circle r="%d" fill="none" stroke="#4dc571" stroke-width="2"/>' % radius
				# Three separated, hard-edged sweep cells replace the continuous analog fan.
				art += '<path d="M8-5L29-19L34-5L10-1Z" fill="#a5ff80" opacity="0.58"/>'
				art += '<path d="M35-23L57-37L66-10L40-6Z" fill="#7cec68" opacity="0.45"/>'
				art += '<path d="M63-41L87-57L101-15L73-11Z" fill="#53c95f" opacity="0.34"/>'
				art += (
					'<path d="M0 0L88-57" fill="none" stroke="#d9ffb8" stroke-width="3" '
					+ 'stroke-dasharray="12 6"/>'
				)
				# Square pixel lock, with separated corner brackets rather than a round blip.
				# Baseball diamond inside the radar. The bright dot sits in right-center's outfield gap.
				art += (
					'<g data-baseball-diamond="infield"><path d="M-34 0L-6-28L22 0L-6 28Z" '
					+ 'fill="#164934" fill-opacity="0.7" stroke="#e2ffd2" stroke-width="3.5"/><path '
					+ 'd="M-34 0L36-70Q102 0 36 70Z" fill="none" stroke="#a4ef8c" stroke-width="2.2" '
					+ 'opacity="0.8"/><path d="M-39 0L-34-5L-29 0L-34 5Z M-11-28L-6-33L-1-28L-6-23Z M17 '
					+ '0L22-5L27 0L22 5Z M-11 28L-6 23L-1 28L-6 33Z" fill="#eeffdc"/></g>'
				)
				art += (
					'<circle data-gap-target="outfield" cx="47" cy="-35" r="5" fill="#e7bf6b"/><path '
					+ 'd="M35-41V-47H41M53-47H59V-41M59-29V-23H53M41-23H35V-29" fill="none" '
					+ 'stroke="#8aff74" stroke-width="2.5"/>'
				)
				art += '<path d="M-5-5H5V5H-5Z" fill="#78ff80"/></g>'
				art += (
					'<path d="M-105-7V7M105-7V7M-7-105H7M-7 105H7" fill="none" stroke="#dbffbe" '
					+ 'stroke-width="3"/></g>'
				)
				# The satellite center body is the three-slot ball; original little dish remains above.
				art += (
					(
						'<g data-gap-emblem="satellite" transform="translate(%d 467) scale(-1 1) '
						+ 'rotate(-90)"><g transform="rotate(-20)"><path d="M-12 0H12" fill="none" '
						+ 'stroke="#d5eee5" stroke-width="3"/><path d="M-30-12H-12V12H-30Z '
						+ 'M12-12H30V12H12Z" fill="#163449" stroke="#78ff80" stroke-width="2.4"/><path '
						+ 'd="M-24-12V12M-18-12V12M18-12V12M24-12V12M-30 0H-12M12 0H30" fill="none" '
						+ 'stroke="#59bd69" stroke-width="1.5"/><g data-gap-body="wiffle-ball" '
						+ 'transform="translate(0 0) scale(0.5)"><circle r="18" fill="#d5eee5" '
						+ 'stroke="#78ff80" stroke-width="1.4"/><g data-wiffle-slots="upper-hemisphere" '
						+ 'fill="#163449"><path data-wiffle-slot="left-curved" '
						+ 'd="M-9.2-12.8C-11.1-12-14-6-13.5-3.8C-13.2-2.1-11.4-1.8-10.5-3.6L-5.9-11C-5-12.7-'
						+ '7.2-14-9.2-12.8Z"/><path data-wiffle-slot="center-vertical" d="M-2.5-12.5Q0-15 '
						+ '2.5-12.5V-3Q2.5-0.5 0-0.5Q-2.5-0.5-2.5-3Z"/><path '
						+ 'data-wiffle-slot="right-curved" d="M9.2-12.8C11.1-12 14-6 13.5-3.8C13.2-2.1 '
						+ '11.4-1.8 10.5-3.6L5.9-11C5-12.7 7.2-14 9.2-12.8Z"/></g><path '
						+ 'd="M-12.4-4.1Q-11.5-9.3-8.6-11.8M-1.6-11.9Q0-13.4 1.6-11.9M8.6-11.8Q11.5-9.3 '
						+ '12.4-4.1" fill="none" stroke="#d5eee5" stroke-width="0.65" '
						+ 'stroke-linecap="round"/></g><path d="M0-8V-18M-6-22Q0-14 6-22M-5-28Q0-31 5-28" '
						+ 'fill="none" stroke="#d5eee5" stroke-width="2.3" stroke-linecap="round"/></g></g>'
					)
					% x
				)
			art += '<path d="M0 700H256V986H0Z" fill="#15242f"/>'
		"BAT-ALY-03":
			# Fine rime, translucent icy facets and grain. The emblem has a quiet clear patch.
			ground = "#89bfd2"
			art = (
				'<defs><linearGradient id="ice" x1="0" y1="0" x2="1" y2="1"><stop offset="0" '
				+ 'stop-color="#e3f4f6"/><stop offset="0.36" stop-color="#91c9df"/><stop offset="0.7" '
				+ 'stop-color="#c4e7ec"/><stop offset="1" '
				+ 'stop-color="#6eabc7"/></linearGradient></defs>'
			)
			art += '<rect width="256" height="700" fill="url(#ice)"/>'
			for index: int in range(260):
				var x: int = (index * 73 + 19) % 256
				var y: int = (index * 137 + 11) % 687
				var radius: float = 0.55 + float(index % 4) * 0.38
				var ice_color: String = "#f3fdff" if index % 3 != 0 else "#4e91b4"
				art += (
					'<circle cx="%d" cy="%d" r="%.2f" fill="%s" opacity="0.42"/>'
					% [x, y, radius, ice_color]
				)
			for index: int in range(67):
				# Nonlinear scatter and small unequal facets avoid repeated tape-like bands.
				var x: int = (index * (index * 17 + 71) + 13) % 256
				var y: int = (index * (index * 31 + 97) + 23) % 660
				var span: int = 3 + index % 6
				art += (
					'<path d="M%d %dL%d %dL%d %dL%d %dZ" fill="#effbff" opacity="0.14"/>'
					% [
						x - span,
						y + span,
						x + 2,
						y - span * 2,
						x + span,
						y + 1,
						x + 3,
						y + span * 2
					]
				)
			for index: int in range(15):
				var x: int = (index * 61 + 29) % 256
				var y: int = (index * 97 + 17) % 635
				art += (
					(
						'<path d="M%d %dL%d %dL%d %dM%d %dL%d %d" fill="none" stroke="#f4fcff" '
						+ 'stroke-width="1.5" opacity="0.56"/>'
					)
					% [x - 15, y, x, y + 15, x - 6, y + 43, x, y + 15, x + 13, y + 27]
				)
			for x: int in [64, 192]:
				# Nothing is drawn over this opaque, unbroken emblem field or its snowflake.
				art += '<ellipse cx="%d" cy="252" rx="43" ry="70" fill="#79afc5"/>' % x
				art += '<g transform="translate(%d 252) scale(0.78 1)">' % x
				for angle: int in range(0, 360, 60):
					art += (
						(
							'<path d="M0 0V-49M0-21L-9-30M0-21L9-30M0-35L-11-46M0-35L11-46" '
							+ 'transform="rotate(%d)" fill="none" stroke="#f6feff" stroke-width="4" '
							+ 'stroke-linecap="round" stroke-linejoin="round"/>'
						)
						% angle
					)
				art += '<circle r="4" fill="#ffffff"/></g>'
			art += '<path d="M0 700H256V986H0Z" fill="#304f67"/>'
		"PREVIEW-WARHAWK":
			# Two aircraft side profiles join through the actual rounded nose/cap UV field.
			# U spans the circumference; V=0 is the pole and V=5.77 the last nonzero-radius ring.
			ground = "#657147"
			# A short olive-to-dark transition joins the nose without a separate cream rim.
			# Cream remains only in the actual side-lip paths layered over this shared field.
			art = (
				'<defs><linearGradient id="warhawk-nose-shade" x1="0" y1="0" x2="0" y2="1"><stop '
				+ 'offset="0" stop-color="#111c19"/><stop offset="0.2" stop-color="#111c19"/><stop '
				+ 'offset="1" stop-color="#657147"/></linearGradient></defs><g '
				+ 'data-warhawk-nose-wrap="continuous"><path d="M0 0H256V30H0Z" '
				+ 'fill="url(#warhawk-nose-shade)"/></g>'
			)
			for offset: int in [240, 368]:
				art += (
					'<g data-warhawk-profile="side" transform="matrix(0 -1 -0.8 0 %d 1060)">'
					% offset
				)
				art += (
					'<g data-warhawk-mouth="slightly-reduced" transform="translate(1080 242) '
					+ 'scale(0.96 0.94) translate(-1080 -242)"><path d="M625 245 Q743 203 837 197 Q901 '
					+ '188 973 197 Q1030 202 1080 218 L1080 267 Q976 291 900 284 Q840 291 783 262 Q728 '
					+ '250 625 245Z" fill="#eee6cb" stroke="#19201a" stroke-width="5"/>'
				)
				art += (
					'<path d="M638 245 Q746 208 838 203 Q901 194 973 203 Q1030 208 1080 224 L1080 260 '
					+ 'Q976 284 900 278 Q840 284 783 257 Q730 250 638 245Z" fill="#a73327"/>'
				)
				art += (
					'<path d="M646 245 Q748 213 838 208 Q901 199 973 208 Q1030 213 1080 229 L1080 255 '
					+ 'Q976 278 900 273 Q840 278 783 254 Q734 250 646 245Z" fill="#111c19"/>'
				)
				art += (
					'<path d="M662 247 Q758 251 806 263 Q849 254 900 258 Q953 268 1000 252 Q1042 246 '
					+ '1080 236 L1080 255 Q976 278 900 273 Q840 278 783 254Z" fill="#a73327"/></g>'
				)
				art += (
					'<g data-warhawk-eye-placement="tipward-separated" transform="translate(75 '
					+ '-1)"><path data-warhawk-eye="curved-socket" d="M883 165 Q897 156 916 164 L958 181 '
					+ 'Q950 190 927 190 Q900 190 887 181 Q880 175 883 165Z" fill="#eee6cb" '
					+ 'stroke="#19201a" stroke-width="4.5"/><circle cx="927" cy="180" r="7" '
					+ 'fill="#a64d32" stroke="#19201a" stroke-width="2"/><circle cx="930" cy="179" '
					+ 'r="3.4" fill="#111c19"/><circle cx="928" cy="176" r="1.2" fill="#f1ead6"/><path '
					+ 'd="M884 164Q897 157 916 164L958 181" fill="none" stroke="#19201a" '
					+ 'stroke-width="5" stroke-linecap="round"/></g>'
				)
				art += (
					'<g data-warhawk-teeth="curved-varied" transform="translate(1080 242) scale(0.96 '
					+ '0.94) translate(-1080 -242)"><path d="M669 238Q672 247 679 243Q682 244 684 234Z" '
					+ 'fill="#f1ead6"/><path d="M697 230Q700 239 706 239Q714 236 716 226Z" '
					+ 'fill="#f1ead6"/><path d="M731 222Q734 231 742 238Q750 228 752 218Z" '
					+ 'fill="#f1ead6"/><path d="M770 215Q773 224 782 237Q792 221 794 211Z" '
					+ 'fill="#f1ead6"/><path d="M812 209Q815 218 827 239Q836 218 838 208Z" '
					+ 'fill="#f1ead6"/><path d="M854 205Q857 214 862 237Q877 214 879 204Z" '
					+ 'fill="#f1ead6"/><path d="M895 204Q898 213 912 242Q921 215 923 205Z" '
					+ 'fill="#f1ead6"/><path d="M939 205Q942 214 947 239Q963 218 965 208Z" '
					+ 'fill="#f1ead6"/><path d="M980 210Q983 219 993 244Q1005 225 1007 215Z" '
					+ 'fill="#f1ead6"/><path d="M1023 219Q1026 228 1035 244Q1048 235 1050 225Z" '
					+ 'fill="#f1ead6"/><path d="M691 250Q693 242 702 246Q707 244 710 251Z" '
					+ 'fill="#f1ead6"/><path d="M732 252Q734 244 744 245Q751 247 754 254Z" '
					+ 'fill="#f1ead6"/><path d="M775 254Q777 246 791 248Q795 255 798 262Z" '
					+ 'fill="#f1ead6"/><path d="M816 269Q818 261 832 249Q839 266 842 273Z" '
					+ 'fill="#f1ead6"/><path d="M859 274Q861 266 877 248Q882 267 885 274Z" '
					+ 'fill="#f1ead6"/><path d="M905 273Q907 265 916 248Q930 264 933 271Z" '
					+ 'fill="#f1ead6"/><path d="M948 269Q950 261 960 248Q972 258 975 265Z" '
					+ 'fill="#f1ead6"/><path d="M987 261Q989 253 1002 247Q1011 251 1014 258Z" '
					+ 'fill="#f1ead6"/><path d="M1027 255Q1029 247 1041 246Q1051 244 1054 251Z" '
					+ 'fill="#f1ead6"/></g>'
				)
				art += "</g>"
			# Uniform pole paint prevents a pinwheel where all cap longitudes converge.
			art += '<path data-warhawk-cap-pole="joined" d="M0 0H256V6H0Z" fill="#111c19"/>'
			# Identical readable P-40 / larger winged-wiffle-ball stacks on both sides.
			for stencil_side: int in [64, 192]:
				art += (
					(
						'<g transform="translate(%d 510) scale(-1 1) rotate(-90)"><path d="M-32 '
						+ '15V-15H-19Q-11-15-11-6Q-11 3-19 3H-32M-5 0H3M18-15L7 '
						+ '5H25M20-15V15M34-15H45V15H34Z" fill="none" stroke="#d6d0ae" stroke-width="3" '
						+ 'opacity="0.68"/></g>'
					)
					% stencil_side
				)
				art += (
					(
						'<g data-warhawk-side-badge="winged-wiffle-ball" transform="translate(%d 615) '
						+ 'scale(-2.35 1.4) rotate(-90)" opacity="0.76"><path d="M-16-7L-40-15L-35-5L-17 '
						+ '2M16-7L40-15L35-5L17 2M-17 3L-32 0L-26 8L-15 10M17 3L32 0L26 8L15 10" '
						+ 'fill="#d6d0ae"/><circle r="18" fill="#d6d0ae"/><g '
						+ 'data-wiffle-slots="upper-hemisphere" fill="#293323"><path '
						+ 'data-wiffle-slot="left-curved" '
						+ 'd="M-9.2-12.8C-11.1-12-14-6-13.5-3.8C-13.2-2.1-11.4-1.8-10.5-3.6L-5.9-11C-5-12.7-'
						+ '7.2-14-9.2-12.8Z"/><path data-wiffle-slot="center-vertical" d="M-2.5-12.5Q0-15 '
						+ '2.5-12.5V-3Q2.5-0.5 0-0.5Q-2.5-0.5-2.5-3Z"/><path '
						+ 'data-wiffle-slot="right-curved" d="M9.2-12.8C11.1-12 14-6 13.5-3.8C13.2-2.1 '
						+ '11.4-1.8 10.5-3.6L5.9-11C5-12.7 7.2-14 9.2-12.8Z"/></g><path '
						+ 'data-wiffle-slot-highlights="subtle" '
						+ 'd="M-12.4-4.1Q-11.5-9.3-8.6-11.8M-1.6-11.9Q0-13.4 1.6-11.9M8.6-11.8Q11.5-9.3 '
						+ '12.4-4.1" fill="none" stroke="#f3edd6" stroke-width="0.65" '
						+ 'stroke-linecap="round"/><path d="M-34-10L-29-8L-32-6Z M29 3L25 4L28 6Z" '
						+ 'fill="#657147"/></g>'
					)
					% stencil_side
				)
			for index: int in range(29):
				art += (
					'<path d="M%d %dh%d" stroke="#596442" stroke-width="2" opacity="0.6"/>'
					% [(index * 71 + 9) % 256, 480 + (index * 43) % 235, 2 + index % 5]
				)
			art += '<path d="M0 750H256V986H0Z" fill="#202720"/>'
	# Tiny molded grip bands, low contrast; never a crayon/pencil novelty shape.
	if not id.is_empty() and id != "BAT-POW-01":
		for y: int in range(754, 956, 28):
			art += '<path d="M0 %dH256" stroke="#14202a" stroke-width="2" opacity="0.18"/>' % y
	return (
		(
			'<svg xmlns="http://www.w3.org/2000/svg" width="256" height="1024" viewBox="0 0 256 '
			+ '1024"><rect width="256" height="1024" fill="%s"/>%s</svg>'
		)
		% [ground, art]
	)


static func _svg_star(center: Vector2, radius: float, color: String) -> String:
	var points: PackedStringArray = PackedStringArray()
	for index: int in range(10):
		var angle: float = -PI * 0.5 + float(index) * PI / 5.0
		var r: float = radius if index % 2 == 0 else radius * 0.43
		points.append("%.2f,%.2f" % [center.x + cos(angle) * r, center.y + sin(angle) * r])
	return '<polygon points="%s" fill="%s"/>' % [" ".join(points), color]


func _apply_stance() -> void:
	var side: float = handed_side(bats_left)
	# The hands begin behind the back shoulder (-Z), drive to a square barrel
	# at the authored sweet-spot time, then finish toward the front shoulder.
	# Handedness mirrors X and yaw while preserving that back-to-front motion.
	_pivot.position = (stance_pivot_position(bats_left) + aim_pose_position_offset(_aim_pose))
	_pivot.rotation = Vector3(
		deg_to_rad(-_attack_angle_degrees),
		deg_to_rad(side * STANCE_YAW_DEGREES + aim_pose_yaw_offset_degrees(_aim_pose)),
		0.0
	)
	_bat_axis.rotation = Vector3(
		0.0,
		0.0,
		deg_to_rad(-side * (STANCE_AXIS_TILT_DEGREES + aim_pose_axis_tilt_degrees(_aim_pose)))
	)


static func aim_pose_position_offset(normalized_aim: Vector2) -> Vector3:
	return Vector3(0.0, clampf(normalized_aim.y, -1.0, 1.0) * 0.075, 0.0)


static func aim_pose_yaw_offset_degrees(normalized_aim: Vector2) -> float:
	return clampf(normalized_aim.x, -1.0, 1.0) * 4.0


static func aim_pose_axis_tilt_degrees(normalized_aim: Vector2) -> float:
	return clampf(normalized_aim.y, -1.0, 1.0) * 4.0 + clampf(normalized_aim.x, -1.0, 1.0) * 2.0


static func handed_side(is_left_handed: bool) -> float:
	return 1.0 if is_left_handed else -1.0


static func stance_pivot_x(is_left_handed: bool) -> float:
	return handed_side(is_left_handed) * 0.24


static func stance_yaw_degrees(is_left_handed: bool) -> float:
	return handed_side(is_left_handed) * STANCE_YAW_DEGREES


static func contact_yaw_degrees(_is_left_handed: bool) -> float:
	return CONTACT_YAW_DEGREES


static func finish_yaw_degrees(is_left_handed: bool) -> float:
	return handed_side(is_left_handed) * FINISH_YAW_DEGREES


static func stance_pivot_position(is_left_handed: bool) -> Vector3:
	return Vector3(stance_pivot_x(is_left_handed), 1.20, -0.20)


static func slot_pivot_position(is_left_handed: bool) -> Vector3:
	return Vector3(handed_side(is_left_handed) * 0.19, 1.08, -0.04)


static func contact_pivot_position(is_left_handed: bool) -> Vector3:
	return Vector3(handed_side(is_left_handed) * 0.34, 0.98, 0.09)


static func extension_pivot_position(is_left_handed: bool) -> Vector3:
	return Vector3(handed_side(is_left_handed) * 0.42, 1.02, 0.34)


static func finish_pivot_position(is_left_handed: bool) -> Vector3:
	return Vector3(handed_side(is_left_handed) * 0.12, 1.30, 0.22)


static func pivot_position_at_elapsed(
	is_left_handed: bool,
	elapsed_seconds: float,
	sweet_spot_seconds: float,
	swing_duration_seconds: float
) -> Vector3:
	var phases: Vector2 = phase_progress_at_elapsed(
		elapsed_seconds, sweet_spot_seconds, swing_duration_seconds
	)
	if phases.y <= 0.0:
		return _interpolate_keyed_vector3(
			stance_pivot_position(is_left_handed),
			slot_pivot_position(is_left_handed),
			contact_pivot_position(is_left_handed),
			phases.x,
			SLOT_SPLIT
		)
	return _interpolate_keyed_vector3(
		contact_pivot_position(is_left_handed),
		extension_pivot_position(is_left_handed),
		finish_pivot_position(is_left_handed),
		phases.y,
		EXTENSION_SPLIT
	)


static func yaw_degrees_at_elapsed(
	is_left_handed: bool,
	elapsed_seconds: float,
	sweet_spot_seconds: float,
	swing_duration_seconds: float
) -> float:
	var phases: Vector2 = phase_progress_at_elapsed(
		elapsed_seconds, sweet_spot_seconds, swing_duration_seconds
	)
	var side: float = handed_side(is_left_handed)
	if phases.y <= 0.0:
		return (
			side
			* _interpolate_keyed_float(
				STANCE_YAW_DEGREES, SLOT_YAW_DEGREES, CONTACT_YAW_DEGREES, phases.x, SLOT_SPLIT
			)
		)
	return (
		side
		* _interpolate_keyed_float(
			CONTACT_YAW_DEGREES,
			EXTENSION_YAW_DEGREES,
			FINISH_YAW_DEGREES,
			phases.y,
			EXTENSION_SPLIT
		)
	)


static func axis_tilt_degrees_at_elapsed(
	elapsed_seconds: float, sweet_spot_seconds: float, swing_duration_seconds: float
) -> float:
	var phases: Vector2 = phase_progress_at_elapsed(
		elapsed_seconds, sweet_spot_seconds, swing_duration_seconds
	)
	if phases.y <= 0.0:
		return _interpolate_keyed_float(
			STANCE_AXIS_TILT_DEGREES,
			SLOT_AXIS_TILT_DEGREES,
			CONTACT_AXIS_TILT_DEGREES,
			phases.x,
			SLOT_SPLIT
		)
	return _interpolate_keyed_float(
		CONTACT_AXIS_TILT_DEGREES,
		EXTENSION_AXIS_TILT_DEGREES,
		FINISH_AXIS_TILT_DEGREES,
		phases.y,
		EXTENSION_SPLIT
	)


static func torso_yaw_degrees_at_elapsed(
	is_left_handed: bool,
	elapsed_seconds: float,
	sweet_spot_seconds: float,
	swing_duration_seconds: float
) -> float:
	var phases: Vector2 = phase_progress_at_elapsed(
		elapsed_seconds, sweet_spot_seconds, swing_duration_seconds
	)
	var side: float = handed_side(is_left_handed)
	if phases.y <= 0.0:
		return side * _interpolate_keyed_float(-10.0, 4.0, 20.0, phases.x, SLOT_SPLIT)
	return side * _interpolate_keyed_float(20.0, 32.0, 42.0, phases.y, EXTENSION_SPLIT)


static func body_offset_at_elapsed(
	elapsed_seconds: float, sweet_spot_seconds: float, swing_duration_seconds: float
) -> Vector3:
	var phases: Vector2 = phase_progress_at_elapsed(
		elapsed_seconds, sweet_spot_seconds, swing_duration_seconds
	)
	if phases.y <= 0.0:
		return _interpolate_keyed_vector3(
			Vector3(0.0, 0.0, -0.02), Vector3.ZERO, Vector3(0.0, 0.0, 0.07), phases.x, SLOT_SPLIT
		)
	return _interpolate_keyed_vector3(
		Vector3(0.0, 0.0, 0.07),
		Vector3(0.0, 0.0, 0.09),
		Vector3(0.0, 0.0, 0.05),
		phases.y,
		EXTENSION_SPLIT
	)


static func aim_influence_at_phases(phases: Vector2) -> float:
	if phases.y <= 0.0:
		return lerpf(1.0, 0.65, phases.x)
	return lerpf(0.65, 0.15, phases.y)


static func phase_progress_at_elapsed(
	elapsed_seconds: float, sweet_spot_seconds: float, swing_duration_seconds: float
) -> Vector2:
	var safe_sweet_spot: float = maxf(0.001, sweet_spot_seconds)
	var safe_duration: float = maxf(safe_sweet_spot + 0.001, swing_duration_seconds)
	if elapsed_seconds <= safe_sweet_spot:
		var pre_contact: float = clampf(elapsed_seconds / safe_sweet_spot, 0.0, 1.0)
		# Cubic Hermite drive: start at rest, peak shortly before contact, and
		# retain nearly that velocity through the ball instead of easing to a
		# stop at the authored sweet spot.
		var drive: float = (
			-0.6 * pre_contact * pre_contact * pre_contact + 1.6 * pre_contact * pre_contact
		)
		return Vector2(drive, 0.0)
	var post_contact: float = clampf(
		(elapsed_seconds - safe_sweet_spot) / (safe_duration - safe_sweet_spot), 0.0, 1.0
	)
	# Continue through contact without a speed discontinuity, then decelerate
	# monotonically into a readable front-shoulder finish.
	var follow_through: float = (
		1.5 * post_contact - 0.5 * post_contact * post_contact * post_contact
	)
	return Vector2(1.0, follow_through)


static func _interpolate_keyed_float(
	start_value: float, middle_value: float, end_value: float, progress: float, split: float
) -> float:
	var bounded: float = clampf(progress, 0.0, 1.0)
	if bounded <= split:
		var first_progress: float = smoothstep(0.0, split, bounded)
		return lerpf(start_value, middle_value, first_progress)
	var second_progress: float = smoothstep(split, 1.0, bounded)
	return lerpf(middle_value, end_value, second_progress)


static func _interpolate_keyed_vector3(
	start_value: Vector3, middle_value: Vector3, end_value: Vector3, progress: float, split: float
) -> Vector3:
	var bounded: float = clampf(progress, 0.0, 1.0)
	if bounded <= split:
		var first_progress: float = smoothstep(0.0, split, bounded)
		return start_value.lerp(middle_value, first_progress)
	var second_progress: float = smoothstep(split, 1.0, bounded)
	return middle_value.lerp(end_value, second_progress)


static func _material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.76
	return material
