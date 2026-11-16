class_name SeasonLegends
extends RefCounted
## Per-purchased-copy seasonal stamps are reconstructed from the build journal.


static func settle(build: SeasonBuild, performance: Dictionary) -> void:
	for receipt: Dictionary in build._bank.view().sponsors:
		if receipt.item != "E05":
			continue
		var stamps: Array = build._legends.get(receipt.id, []).duplicate()
		for kind: String in SeasonSponsorProgress.hit_types(performance, build.roster()):
			if not stamps.has(kind):
				stamps.append(kind)
		stamps.sort()
		build._legends[receipt.id] = stamps


static func prune(build: SeasonBuild) -> void:
	var active: Array = []
	for receipt: Dictionary in build._bank.view().sponsors:
		if receipt.item == "E05":
			active.append(receipt.id)
	for id: String in build._legends.keys():
		if not active.has(id):
			build._legends.erase(id)
