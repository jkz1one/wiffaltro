class_name StadiumYardLab
extends RefCounted
## Explicit opt-in only. Reuses free-template receiver, boundary, camera and route machinery.


static func install(lab: PitchBatLab, fixture: Variant = null) -> bool:
	if not StadiumPropertyRuntime.authoring_delivery_idle(lab) \
		or not lab.get_meta("stadium_yard_lab_only", false) or lab._managed_match \
		or lab._automation != null or lab._field_id != PitchBatLab.FIELD_ID \
		or lab.has_meta("stadium_property") or is_instance_valid(lab._batted_ball) \
		or lab._pitch_actor.receiver_router.is_valid():
		return false
	if fixture != null and not StadiumYardFixtureStudy.valid(fixture):
		return false
	var host: StarterFieldLabGeometry = lab.get_node_or_null("StarterFieldGeometry")
	if host == null or not host.is_inside_tree() \
		or not host.global_transform.is_equal_approx(Transform3D.IDENTITY) \
		or not host.has_node("PitchReceiverDebug"):
		return false
	var property: StadiumPropertyGeometry = StadiumYardVenueStudy.build()
	if property == null:
		return false
	# All rejection occurs before replacing the original scene; receiver stays the free template.
	StadiumPropertyRuntime._attach(lab, host, property, StadiumStarterLayout.empty())
	lab.set_meta("stadium_candidate_only", true)
	lab.set_meta("stadium_yard_candidate", StadiumYardFixtureStudy.capture(
		property.get_meta("candidate_venue")))
	lab.set_meta("boundary_signature", StadiumBoundaryGraph.signature())
	lab._ball_play_resolver.segment_observer = StadiumBoundaryObserver.observe
	lab._primary_fielder.stadium_boundary_clip = StadiumBoundaryGraph.clip
	lab._camera_director.tracking_visibility = StadiumYardFieldVisibility.new()
	lab._camera_director.tracking_visibility.configure(host)
	return true
