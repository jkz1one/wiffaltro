extends Node
const Copy = preload("res://src/presentation/season/closed_league_player_copy.gd")
const GearCopy = preload("res://src/presentation/season/season_gear_player_copy.gd")
const Glyph = preload("res://src/presentation/season/season_loadout_glyph.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(label)
func text_of(node: Node) -> String:
 var value: String = node.text if node is Label else ""
 for child: Node in node.get_children(): value += "\n" + text_of(child)
 return value
func _ready() -> void:
 for key: String in Copy.NOTICES:
  check(Copy.notice(key) == Copy.NOTICES[key], "exact alias")
 check(Copy.notice("unknown diagnostic 17") == "unknown diagnostic 17", "unknown error preserved")
 check(Copy.recovery("ready",true) == Copy.BLOCKED, "blocked wins over metadata ready")
 check(Copy.recovery("pending") == Copy.PENDING, "pending cannot cancel message")
 for id: String in ["A04", "MISC-FLD-01", "MISC-FLD-02", "A02", "BAT-ALY-02"]:
  var item: Dictionary = SeasonGearCatalog.item(id)
  var before: String = JSON.stringify(item)
  GearCopy.effect(id,item)
  GearCopy.status(id,item)
  check(JSON.stringify(item)==before,"catalog data untouched "+id)
 var custom: Dictionary={"effect":"unknown exact effect", "status":"Important custom limitation"}
 check(GearCopy.effect("X",custom)==custom.effect
  and GearCopy.status("X",custom)==custom.status,
  "unknown disclosures preserved")
 for league: String in ["standard","sponsorship","dugout","equipment","academy"]:
  var season: SeasonState = SeasonState.create_closed_league(61002,LeagueRules.capture(league),true)
  check(season!=null,"closed fixture created")
  for i in range(4): check(season.choose_player(season.offers()[0]),"legal draft")
  var before: String=JSON.stringify(SeasonSave.snapshot(season),"",true,true)
  var club: Dictionary=season.opponents.clubs["1"]
  var card: VBoxContainer=VBoxContainer.new()
  add_child(card)
  SeasonOpponentSponsorsUI.preview(card,club)
  SeasonOpponentTacticsUI.preview(card,club)
  var rendered: String=text_of(card)
  var actual_pool: Dictionary=SeasonOpponentSponsors.pool(club.build)
  var actual_supplies: Dictionary=SeasonOpponentTactics.pool(club.build._market)
  check(actual_pool.has("F01") and actual_pool.has("F03")
   and actual_pool.has("E08") and actual_supplies.size()==5,
   "actual market12 capabilities "+league)
  print(("OPPONENT_DISCLOSURE league=%s market=%d supplies=%d "
   + "says_supplies_gated=%s names_budget=%s names_choices=%s") % [
   league,club.build._market,actual_supplies.size(),
   rendered.contains("Other sponsors, supplies and recruiting remain gated"),
   rendered.contains("Budget Bites"),
   rendered.contains("plus Cornerstone and Split Decision")
   or rendered.contains("Cornerstone, ")])
  check(not rendered.contains("Other sponsors, supplies and recruiting remain gated"),
   "market12 cannot claim supported supplies gated "+league)
  check(rendered.contains("Budget Bites") and rendered.contains("Cornerstone")
   and rendered.contains("Split Decision"),
   "market12 sponsor scope must be disclosed "+league)
  check(rendered.contains("0 / %d active" % club.build._bank.view().capacity.sponsors),
   "actual sponsor capacity "+league)
  check(rendered.contains("0 / %d held" % club.build._bank.view().capacity.held),
   "actual held capacity "+league)
  check(JSON.stringify(SeasonSave.snapshot(season),"",true,true)==before,
   "read-only preview "+league)
  card.queue_free()
 for category: String in ["bat","ball","sponsors","supplies","abilities","misc"]:
  for inactive: bool in [false,true]:
   var glyph: Control=Glyph.new()
   glyph.category=category
   glyph.inactive=inactive
   add_child(glyph)
   glyph.size=Vector2(48,40)
   glyph.queue_redraw()
   check(glyph.mouse_filter==Control.MOUSE_FILTER_IGNORE,"glyph never intercepts input")
   glyph.queue_free()
 await get_tree().process_frame
 print("OMITTED_UI_READONLY_RESULT checks=%d failures=%d" % [checks,failures])
 get_tree().quit(0 if failures==0 else 1)
