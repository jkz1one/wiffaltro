extends "res://src/tests/stadium_waterfall_live_runtime_test.gd"
## Reuses the exact six native-drop witnesses and cold evidence controls against explicit47.
## No historical source or factory is changed. Native physics runs with a frozen nonzero phase.


func _build() -> bool:
	var credits: Array = []
	var progress: Array = []
	for index in range(40):
		credits.append(10000)
		progress.append({"seasons": 1, "wins": 5})
	var ledger: ClubAssetLedger = ClubAssetLedger.new(208, credits, progress)
	for tier: String in ["expanded", "club", "mogul"]:
		var land: Dictionary = ledger.commit(
			{
				"id": "wf-runtime-land-" + tier,
				"rev": ledger.revision(),
				"op": "stadium_land",
				"tier": tier,
				"through": 40,
				"progress_through": 40,
				"price_version": StadiumLand.VERSION
			}
		)
		_check(land.ok, "paid Mogul path " + tier)
		if not land.ok:
			return false
	var bought: Dictionary = ledger.commit(
		{
			"id": "runtime-waterfall",
			"rev": ledger.revision(),
			"op": "stadium_buy",
			"item": "ST-046",
			"quantity": 1,
			"price_version": 32,
			"through": 40,
			"progress_through": 40
		}
	)
	_check(
		bought.ok and ledger.construction().copies.has(COPY),
		"unchanged paid ST046 stock supplies exact live copy"
	)
	if not bought.ok:
		return false
	var layout: Dictionary = StadiumWaterfallLiveItems.place(
		ledger.view().stadium_draft,
		ledger.construction(),
		COPY,
		StadiumWaterfallLiveSites.SITE,
		0,
		ledger.surface_owned()
	)
	layout = StadiumWaterfallAnimationLayout.select(layout, COPY, true)
	var drafted: Dictionary = ledger.commit(
		{
			"id": "wf-runtime-draft",
			"rev": ledger.revision(),
			"op": "stadium_draft",
			"layout": layout
		}
	)
	_check(drafted.ok, "family47 real owned draft succeeds")
	if not drafted.ok:
		return false
	var applied: Dictionary = ledger.commit(
		{
			"id": "wf-runtime-apply",
			"rev": ledger.revision(),
			"op": "stadium_apply",
			"layout": layout,
			"geometry": StadiumWaterfallAnimationLayout.geometry("mogul", layout)
		}
	)
	_check(applied.ok, "family47 explicit paid-copy Apply succeeds")
	if not applied.ok:
		return false
	_snapshot = StadiumLayoutSnapshot.capture(ledger, true)
	_property = StadiumWaterfallAnimationProperty.new()
	add_child(_property)
	_check(
		(_property as StadiumWaterfallAnimationProperty).build_complete(
			"mogul",
			ledger.view().stadium_active,
			ledger.construction(),
			ledger.wall_pieces(),
			ledger.scoreboards(),
			ledger.surface_owned()
		),
		"full exact owned property builds"
	)
	_boundary = StadiumWaterfallAnimationBoundary.new()
	_boundary.name = "BoundaryGraph"
	if not _boundary.build_from(
		_property, _property.get_meta("boundary_layout"), ledger.construction()
	):
		return false
	_property.get_node("TemplateBackWall").free()
	_property.add_child(_boundary)
	_check(
		(
			_property._waterfall_animation.advance(0.1, false, false)
			and _property._waterfall_animation.phase > 0
		),
		"explicit animated phase advances before native drop, with unchanged trap geometry"
	)
	_check(
		_boundary != null and _property.props_intact(),
		"ordinary owned boundary seals and routes live waterfall"
	)
	_model = _property.objects.get(COPY)
	return _boundary != null and _model != null and _property.props_intact()


func _finish() -> void:
	print(
		(
			"WATERFALL_ANIMATION_NATIVE_RESULT "
			+ JSON.stringify(
				{
					"checks": _checks,
					"failures": _failures,
					"native_drops": _native_drops_count,
					"physical_games": 0,
					"synthetic_progression": true,
					"visual_qualified": false,
					"explicit_snapshot47": true
				}
			)
		)
	)
	get_tree().quit(0 if _failures.is_empty() else 1)
