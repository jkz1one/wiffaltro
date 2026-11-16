extends RefCounted
## Explicit reviewed admission choices only. Preview never changes a saved policy.
const TimeHome = preload("res://src/gameplay/season/dynasty_shared_time.gd")
const CHOICES: Array[String] = ["", "day", "sunset", "night", "fixed_night"]
const LABELS: Array[String] = ["Day (existing daylight field)", "Day · 13:10 (qualified lights)",
	"Sunset · 16:10 (qualified lights)", "Night (clocked, qualified lights)", "Night (fixed, qualified lights)"]

static func label(selected: String) -> String:
	var index: int = CHOICES.find(selected)
	return LABELS[index] if index >= 0 else "Unsupported time profile"

static func _choice(parent: Node, selected: String, changed: Callable = Callable()) -> OptionButton:
	var choice: OptionButton = OptionButton.new()
	choice.name = "SharedLeagueTime"
	for text: String in LABELS: choice.add_item(text)
	choice.selected = maxi(0, CHOICES.find(selected))
	choice.fit_to_longest_item = false
	choice.clip_text = true
	parent.add_child(choice)
	if changed.is_valid():
		var ref: WeakRef = weakref(choice)
		var origin: WeakRef = weakref(parent)
		choice.item_selected.connect(func(index: int) -> void:
			var control: OptionButton = ref.get_ref()
			var body: Node = origin.get_ref()
			if is_instance_valid(control) and control.is_inside_tree() and is_instance_valid(body) \
				and control.get_parent() == body and index in range(CHOICES.size()): changed.call(CHOICES[index]))
	return choice

static func enrollment(app: Node) -> void:
	var setup: RefCounted = app.dynasty_enrollment
	SeasonPages.wrapped(app.menu._body, "Home time: " + label(setup.time_profile()) + ". The new session derives its own paid policy; no played source result is imported.")
	if not TimeHome.ENTRY_ENABLED or setup.attempted(): return
	var ticket: int = setup.token()
	_choice(app.menu._body, setup.time_profile(), func(selected: String) -> void:
		if setup.starting_profile(ticket, selected):
			load("res://src/presentation/season/dynasty_career_ui.gd").enrollment(app))

static func next_review(app: Node) -> void:
	var controller: RefCounted = app.dynasty_owner
	var choice: Dictionary = controller._next_choice
	SeasonPages.wrapped(app.menu._body, "Home time: " + label(choice.get("starting_profile", "")) + ". This choice stays bound through any saved ability-forgetting step.")
	if not TimeHome.ENTRY_ENABLED or not controller.ready(): return
	var ticket: int = choice.ticket
	_choice(app.menu._body, choice.get("starting_profile", ""), func(selected: String) -> void:
		if controller.next_starting_profile(ticket, selected):
			load("res://src/presentation/season/dynasty_career_tier_ui.gd").review(app))

static func alternate(app: Node, league: String, revision: int, seed_value: int, tier: int) -> void:
	if not TimeHome.ENTRY_ENABLED: return
	var choice: OptionButton = _choice(app._confirmation_body, "")
	var ref: WeakRef = weakref(choice)
	app._dialog.dialog_text += " Choose home time explicitly. Unsupported Sunset/Night refuses without replacing either saved season. Current and paused fields remain frozen."
	app._confirmed_action = func() -> void:
		var control: OptionButton = ref.get_ref()
		if is_instance_valid(control) and control.selected in range(CHOICES.size()):
			if not app.dynasty_owner.start_other(league, revision, seed_value, tier, CHOICES[control.selected]):
				load("res://src/presentation/season/dynasty_career_ui.gd").show(app)
	app._dialog.visibility_changed.connect(func() -> void:
		var previous: OptionButton = ref.get_ref()
		if not app._dialog.visible and is_instance_valid(previous): previous.queue_free(), CONNECT_ONE_SHOT)
	app._refresh_confirmation()
