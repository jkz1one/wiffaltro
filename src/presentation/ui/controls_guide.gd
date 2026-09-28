class_name ControlsGuide
extends RefCounted


static func populate(parent: Control) -> void:
	var lines: Array[String] = [
		"BATTING • Mouse / WASD: aim • Left click / Z: contact • Right click / X: power",
		"PITCHING • Mouse / arrows: aim • Hold left click / Space, release at the mark",
		"1–9: select pitch • − / +: effort • Field setup and Bullpen: between batters",
		"Space / click: ready • T: timeout before release • B: switch hitter's side before ready",
		"Esc: pause / back • V while paused: inspect camera • Tab / arrows: menu focus",
		"Controller • Left stick: batting aim • Right stick: pitch aim • A: contact / hold pitch",
		"X: power • Y: ready • Start: pause • B in menus: back",
		"Games use ghost runners and scoring lines. Fielders move automatically.",
		"Season progress saves between games. Leaving an unfinished game restarts that game."
	]
	for text in lines:
		var label: Label = Label.new()
		label.text = text
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 17)
		parent.add_child(label)
