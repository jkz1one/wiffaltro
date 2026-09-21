class_name PlaySounds
extends Node

# Original, deterministic procedural cues. No recordings or third-party assets.
const SAMPLE_RATE: int = 22050
const CUES: Array[StringName] = [&"contact", &"catch", &"bobble", &"wall", &"home_run"]
var muted: bool = false
var last_cue: StringName = &""
var _players: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	for index in range(CUES.size()):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.stream = _synthesize(index)
		player.volume_db = -12.0
		add_child(player)
		_players[CUES[index]] = player


func _exit_tree() -> void:
	stop_all()
	for player: AudioStreamPlayer in _players.values():
		player.stream = null
	_players.clear()


func set_muted(value: bool) -> void:
	muted = value
	if muted:
		stop_all()


func stop_all() -> void:
	for player: AudioStreamPlayer in _players.values():
		player.stop()
	last_cue = &""


func play(cue: StringName) -> void:
	if muted or get_tree().paused or not _players.has(cue):
		return
	last_cue = cue
	_players[cue].play()


static func _synthesize(index: int) -> AudioStreamWAV:
	var durations: Array[float] = [0.11, 0.12, 0.26, 0.24, 0.85]
	var frequencies: Array[float] = [920.0, 230.0, 410.0, 140.0, 523.25]
	var duration: float = durations[index]
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(int(duration * SAMPLE_RATE) * 2)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 8191 + index
	for sample in range(bytes.size() / 2):
		var time: float = float(sample) / SAMPLE_RATE
		var local_time: float = fmod(time, 0.085) if index == 2 else time
		var envelope: float = exp(-local_time * (34.0 if index < 3 else 18.0))
		var tone: float = sin(TAU * frequencies[index] * local_time)
		var value: float = (tone * 0.55 + rng.randf_range(-1.0, 1.0) * 0.45) * envelope
		if index == 4:
			var note: int = mini(int(time / 0.20), 2)
			var ratio: float = [1.0, 1.25, 1.5][note]
			local_time = time - note * 0.20
			value = sin(TAU * frequencies[index] * ratio * local_time) * exp(-local_time * 7.0)
			value *= minf(local_time / 0.008, 1.0) * 0.55
		# Brief attack and tail ramps avoid discontinuities at the buffer edges.
		value *= minf(time / 0.002, 1.0) * minf((duration - time) / 0.018, 1.0)
		bytes.encode_s16(sample * 2, int(clampf(value, -1.0, 1.0) * 24000.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = bytes
	return stream
