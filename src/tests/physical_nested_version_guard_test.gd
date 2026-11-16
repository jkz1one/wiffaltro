extends Node
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(label)
func _ready() -> void:
 var malformed: Array = [null,true,false,"13","45","",[],{},
  PackedInt32Array([13]),Vector2(13,0),NAN,INF,
  -INF,13.5,-1,0,9999]
 for version: int in [27,28]:
  var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
   'res://src/tests/fixtures/report_version_guard/report%d.json' % version))
  check(PhysicalMatchReport.valid(original),'original wrapper')
  for field: String in ['physical','ownership0','ownership1']:
   for value: Variant in malformed:
    var changed: Dictionary = original.duplicate(true)
    if field == 'physical': changed.physical.version = value
    else: changed.ownership[0 if field == 'ownership0' else 1].version = value
    check(not PhysicalMatchReport.valid(changed),'nested malformed '+str(version)+' '+field)
   for integral: bool in [false,true]:
    var changed: Dictionary = original.duplicate(true)
    if field == 'physical':
     changed.physical.version = int(changed.physical.version) \
      if integral else float(changed.physical.version)
    else:
     var index: int = 0 if field == 'ownership0' else 1
     changed.ownership[index].version = int(changed.ownership[index].version) \
      if integral else float(changed.ownership[index].version)
    check(PhysicalMatchReport.valid(changed),'nested valid numeric encoding')
  var changed: Dictionary = original.duplicate(true)
  changed.physical.teams.reverse()
  check(not PhysicalMatchReport.valid(changed),'swapped team roles')
  changed = original.duplicate(true)
  changed.physical.teams[0].workload[changed.physical.teams[0].roster[0]].capacity += 1
  check(not PhysicalMatchReport.valid(changed),'single-field capacity forgery')
  if version == 28:
   changed = original.duplicate(true)
   changed.ownership.reverse()
   check(not PhysicalMatchReport.valid(changed),'swapped distinct ownership')
   changed = original.duplicate(true)
   changed.workload.reverse()
   check(not PhysicalMatchReport.valid(changed),'swapped workload roles')
   changed = original.duplicate(true)
   changed.workload[0].events.reverse()
   check(not PhysicalMatchReport.valid(changed),'reversed release chronology')
   changed = original.duplicate(true)
   changed.uses[1][0].receipt = 'unowned'
   check(not PhysicalMatchReport.valid(changed),'unowned recovery receipt')
  else:
   var legacy: Dictionary = original.physical.duplicate(true)
   legacy.erase('league_bound')
   check(PhysicalMatchReport.valid(legacy),'historical legacy core remains valid')
   for encoding: Variant in [int(legacy.version),float(legacy.version)]:
    legacy.version = encoding
    check(PhysicalMatchReport.valid(legacy),'legacy numeric encoding')
   for value: Variant in malformed:
    legacy.version = value
    check(not PhysicalMatchReport.valid(legacy),'legacy malformed version')
 print('Nested report guard checks: %d, failures: %d' % [checks,failures])
 get_tree().quit(0 if failures==0 else 1)
