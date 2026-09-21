class_name TestAudioDrain
extends RefCounted


static func finish(tree: SceneTree) -> void:
	# Fixed-fps tests advance simulation faster than the real audio mixer.
	# Let queued node deletion and two mixer/update cycles retire stopped voices
	# before engine shutdown. This wait belongs only to test teardown.
	await tree.process_frame
	OS.delay_msec(50)
	await tree.process_frame
	OS.delay_msec(50)
	await tree.process_frame
