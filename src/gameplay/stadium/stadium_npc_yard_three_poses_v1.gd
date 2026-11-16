class_name StadiumNpcYardThreePosesV1
extends RefCounted
## Literal beam poses from the genuine source-bound AY-03 report, not recomputed look-at math.


static func beams() -> Dictionary:
	return {
		"YLIGHT-FL": [
			1.0,
			1.6850189865635912e-07,
			1.8123408551673492e-08,
			1.6850189865635912e-07,
			-0.9771280288696289,
			-0.21265219151973724,
			-1.8123408551673492e-08,
			0.21265219151973724,
			-0.9771280288696289,
			0.0,
			6.295000076293945,
			0.5400000214576721
		],
		"YLIGHT-FR": [
			1.0,
			-1.6850189865635912e-07,
			-1.8123408551673492e-08,
			-1.6850189865635912e-07,
			-0.9771280288696289,
			-0.21265219151973724,
			1.8123408551673492e-08,
			0.21265219151973724,
			-0.9771280288696289,
			0.0,
			6.295000076293945,
			0.5400000214576721
		],
		"YLIGHT-RL": [
			1.0,
			0.0,
			0.0,
			0.0,
			-0.9766263961791992,
			-0.21494454145431519,
			0.0,
			0.21494454145431519,
			-0.9766263961791992,
			0.0,
			6.295000076293945,
			0.5400000214576721
		],
		"YLIGHT-RR": [
			1.0,
			0.0,
			0.0,
			0.0,
			-0.9766263961791992,
			-0.21494454145431519,
			0.0,
			0.21494454145431519,
			-0.9766263961791992,
			0.0,
			6.295000076293945,
			0.5400000214576721
		]
	}


static func transform(components: Array) -> Transform3D:
	return Transform3D(Basis(Vector3(components[0], components[1], components[2]),
		Vector3(components[3], components[4], components[5]),
		Vector3(components[6], components[7], components[8])),
		Vector3(components[9], components[10], components[11]))
