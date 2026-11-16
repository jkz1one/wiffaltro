extends Node
const R = preload("res://src/presentation/stadium/stadium_npc_yard_two_runtime_v1.gd")
var checks := 0
var failures := 0
func check(value: bool, label: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error(label)
func route(lab: PitchBatLab, actor: PitchFlightActor, owner: WeakRef) -> bool:
 return R._interrupted_route(actor, Vector3.ZERO, Vector3.ZERO, weakref(lab), owner)
func _ready() -> void:
 var lab := PitchBatLab.new()
 var actor := PitchFlightActor.new()
 var foreign := PitchFlightActor.new()
 var owner := StadiumNpcYardTwoPropertyV1.new()
 var next := StadiumNpcYardTwoPropertyV1.new()
 lab._pitch_actor = actor
 lab.set_meta("stadium_npc_runtime_interrupted", true)
 owner.phase = &"retired"
 var ref: WeakRef = weakref(owner)
 lab.set_meta("stadium_property", owner)
 check(route(lab,actor,ref), "retired current owner swallowed")
 lab.remove_meta("stadium_property")
 check(route(lab,actor,ref), "retired detached owner swallowed")
 check(not route(lab,foreign,ref), "foreign actor rejected")
 check(not route(lab,null,ref), "null actor rejected")
 lab.remove_meta("stadium_npc_runtime_interrupted")
 check(not route(lab,actor,ref), "non-interrupted lab rejected")
 lab.set_meta("stadium_npc_runtime_interrupted", true)
 owner.phase = &"installed"
 check(not route(lab,actor,ref), "non-retired detached owner rejected")
 owner.phase = &"retired"
 lab.set_meta("stadium_property", next)
 check(not route(lab,actor,ref), "replacement owner rejected")
 owner.free()
 check(not route(lab,actor,ref), "freed old owner cannot swallow replacement")
 check(not route(lab,actor,null), "null owner cannot swallow replacement")
 var foreign_owner := Node.new()
 lab.set_meta("stadium_property", foreign_owner)
 check(not route(lab,actor,ref), "cross-family Node replacement rejected")
 check(not route(lab,actor,null), "ownerless guard rejects foreign Node replacement")
 lab.set_meta("stadium_property", {"foreign": true})
 check(not route(lab,actor,ref), "foreign dictionary metadata rejected")
 lab.set_meta("stadium_property", 1)
 check(not route(lab,actor,ref), "foreign scalar metadata rejected")
 foreign_owner.free()
 lab.remove_meta("stadium_property")
 check(route(lab,actor,ref), "freed owner with no replacement swallowed")
 check(route(lab,actor,null), "ownerless interruption swallowed")
 lab._pitch_actor = foreign
 check(not route(lab,actor,ref), "replaced actor rejects old continuation")
 var dead_lab: WeakRef = weakref(lab)
 lab.free()
 check(not R._interrupted_route(actor,Vector3.ZERO,Vector3.ZERO,dead_lab,ref), "freed lab rejected")
 actor.free()
 foreign.free()
 next.free()
 print("AY02_INTERRUPTED_ROUTE_UNIT checks=%d failures=%d" % [checks,failures])
 get_tree().quit(0 if failures == 0 else 1)
