class_name FielderPlan
extends RefCounted

var intercept_position: Vector3 = Vector3.ZERO
var intercept_seconds: float = 0.0
var reachable: bool = false
var reaction_margin_seconds: float = 0.0
# Private Working advisory data. Ball center, legal feet goal and preview endpoint
# are different positions; only actual supported contact may award control.
var supported_feet_position: Vector3 = Vector3.INF
var route_endpoint: Vector3 = Vector3.INF
var route_reason: String = "unbound"
var advisory_route: bool = false
var forecast_samples: int = 0
var route_queries: int = 0
var route_support_segments: int = 0
var route_support_checks: int = 0
