extends Node
const RETAINED_COMPAT = preload("res://src/tests/ac02_startup_retained_compatibility.gd")
const MANUAL_INPUT = preload("res://src/tests/ac02_manual_qc_input_driver.gd")
const MANUAL_OBSERVER = preload("res://src/tests/ac02_manual_qc_observer.gd")
const ACTIVE_COMPONENTS = preload("res://src/tests/ac02_manual_qc_active_components.gd")
const DIRECT_RUNTIME = preload("res://src/tests/ac02_public_runtime_test.gd")
const POSITIVE = preload("res://src/tests/ac02_startup_preparing_positive.gd")
const CONTROL = preload("res://src/tests/ac02_startup_preparing_control.gd")
const ATTEMPT = preload("res://src/presentation/stadium/stadium_npc_ac02_startup_preparing_v1.gd")


func _ready() -> void:
	var attempt: RefCounted = ATTEMPT.new()
	print("STARTUP_PREPARING real script load complete contract=", attempt.CONTRACT)
	var control_script: Script = CONTROL
	var positive_script: Script = POSITIVE
	var valid: bool = control_script.can_instantiate() and positive_script.can_instantiate()
	var compatibility_script: Script = RETAINED_COMPAT
	valid = valid and compatibility_script.can_instantiate()
	var input_script: Script = MANUAL_INPUT
	var observer_script: Script = MANUAL_OBSERVER
	var active_script: Script = ACTIVE_COMPONENTS
	var direct_script: Script = DIRECT_RUNTIME
	valid = valid and input_script.can_instantiate() and observer_script.can_instantiate() \
		and active_script.can_instantiate() and direct_script.can_instantiate()
	print("STARTUP_PREPARING startup/manual-QC/direct scripts can_instantiate=", valid)
	get_tree().quit(0 if valid else 1)
