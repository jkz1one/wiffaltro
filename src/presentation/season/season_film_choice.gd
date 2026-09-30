class_name SeasonFilmChoice
extends RefCounted


static func add(menu: SeasonMenu, card: VBoxContainer, fixture: Dictionary) -> void:
	var app: SeasonApp = menu.app
	var build: SeasonBuild = app.season.build
	if build == null or SeasonSchoolSponsors.active(build, "J08").is_empty():
		return
	var game: String = str(int(fixture.id))
	if build._pregames.has(game) or build._scouts.has(game):
		var selected: String = build._scouts.get(game, "")
		SeasonPages.wrapped(
			card,
			(
				"Film Room locked: "
				+ (
					ContentDB.get_pitch(StringName(selected)).display_name
					if selected != ""
					else "no selection for this already committed game"
				)
			)
		)
		return
	if app.film_game != int(fixture.id):
		app.film_game = int(fixture.id)
		app.film_recipe = ""
	SeasonPages.wrapped(
		card,
		(
			"Film Room: choose one exact recipe. Play Game saves and locks it. "
			+ "At release, its name appears. No aim or accuracy bonus. Working contract."
		)
	)
	var picker: OptionButton = OptionButton.new()
	picker.name = "FilmRecipe"
	picker.add_item("Choose a recipe…")
	picker.set_item_metadata(0, "")
	for recipe: String in SeasonFilmRoom.choices(app.season, fixture):
		picker.add_item(ContentDB.get_pitch(StringName(recipe)).display_name)
		var index: int = picker.item_count - 1
		picker.set_item_metadata(index, recipe)
		if recipe == app.film_recipe:
			picker.select(index)
	picker.item_selected.connect(
		func(index: int) -> void: app.film_recipe = picker.get_item_metadata(index)
	)
	card.add_child(picker)
