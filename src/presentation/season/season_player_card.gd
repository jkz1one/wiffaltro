class_name SeasonPlayerCard
extends RefCounted

const RATING_NAMES: Array[String] = [
	"Contact", "Power", "Fielding", "Velocity", "Break", "Control", "Stamina"
]
const STYLE_NAMES: Array[String] = [
	"Mixes speeds", "Power pitcher", "Breaking specialist", "Works the corners"
]


static func values(player: PlayerDefinition) -> Array[int]:
	if player.progression_test:
		return [player.contact, player.power, player.fielding, player.control]
	return [
		player.contact,
		player.power,
		player.fielding,
		player.velocity,
		player.break_rating,
		player.control,
		player.stamina
	]


static func hands(player: PlayerDefinition) -> String:
	return (
		"%s / %s"
		% [
			"S" if player.switch_hitter else ("L" if player.bats == 1 else "R"),
			"L" if player.throws == 1 else "R"
		]
	)


static func rating_names(player: PlayerDefinition) -> Array[String]:
	return ["Contact", "Power", "Fielding", "Pitching"] if player.progression_test else RATING_NAMES


static func pitch_name(player: PlayerDefinition, pitch: PitchDefinition) -> String:
	return pitch.display_name + (" Lv%d" % pitch.mastery_level if player.progression_test else "")


static func panel(parent: Node, selected: bool = false) -> VBoxContainer:
	var panel_node: PanelContainer = PanelContainer.new()
	panel_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style: StyleBoxFlat = ClubhouseTheme.surface(selected, 16)
	panel_node.add_theme_stylebox_override("panel", style)
	parent.add_child(panel_node)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel_node.add_child(box)
	return box


static func draft_card(
	parent: Node,
	player: PlayerDefinition,
	selected: bool,
	action: Callable,
	reference: PlayerDefinition = null
) -> void:
	var box: VBoxContainer = panel(parent, selected)
	var name_button: Button = Button.new()
	name_button.text = ("✓ " if selected else "") + player.display_name
	name_button.custom_minimum_size = Vector2(300, 42)
	name_button.add_theme_font_size_override("font_size", 23)
	if selected:
		ClubhouseTheme.primary(name_button)
	name_button.pressed.connect(action)
	box.add_child(name_button)
	line(box, "Bats / Throws: " + hands(player), 18)
	line(box, STYLE_NAMES[player.pitching_style], 18)
	var ratings: Array[int] = values(player)
	for index in range(ratings.size()):
		var row: HBoxContainer = HBoxContainer.new()
		box.add_child(row)
		var label: Label = line(row, rating_names(player)[index], 18)
		label.custom_minimum_size.x = 94
		var bar: ProgressBar = ProgressBar.new()
		bar.max_value = 10
		bar.value = ratings[index]
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(100, 12)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		line(row, "%2d" % ratings[index], 18)
		if reference != null:
			var difference: int = ratings[index] - values(reference)[index]
			var delta: Label = line(row, "(%+d)" % difference, 16)
			delta.add_theme_color_override("font_color", ClubhouseTheme.GREEN if difference > 0
				else (ClubhouseTheme.RED if difference < 0 else ClubhouseTheme.MUTED))
	line(
		box,
		(
			"%d PITCHES%s"
			% [
				player.starting_pitches.size(),
				" • RARE ARSENAL" if player.starting_pitches.size() >= 4 else ""
			]
		),
		16
	)
	var pitches: PackedStringArray = []
	for pitch in player.starting_pitches:
		pitches.append(pitch_name(player, pitch))
	var label: Label = line(box, " • ".join(pitches), 18)
	label.custom_minimum_size.x = 280
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if player.switch_hitter:
		line(box, "SWITCH HITTER • Pick your batting side", 16)


static func line(parent: Node, text: String, font_size: int = 18) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	if font_size <= 17:
		ClubhouseTheme.section(label)
	return label


static func ratings_card(
	parent: Node, player: PlayerDefinition, heading: String, detail: String = ""
) -> void:
	var box: VBoxContainer = panel(parent)
	line(box, heading, 21)
	line(box, "Bats / Throws: " + hands(player) + detail, 17)
	var grid: GridContainer = GridContainer.new()
	grid.columns = rating_names(player).size()
	grid.add_theme_constant_override("h_separation", 25)
	box.add_child(grid)
	for rating in rating_names(player):
		line(grid, rating, 17)
	for value in values(player):
		var rating: Label = line(grid, str(value), 24)
		rating.add_theme_color_override("font_color", ClubhouseTheme.GOLD)
	var pitches: PackedStringArray = []
	for pitch in player.starting_pitches:
		pitches.append(pitch_name(player, pitch))
	var arsenal: Label = line(box, "Pitches: " + " • ".join(pitches), 17)
	arsenal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
