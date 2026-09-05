class_name AudioSfx
extends Node

var enabled := true
var player: AudioStreamPlayer
var playback: AudioStreamGeneratorPlayback
var time := 0.0
var duration := 0.0
var frequency := 0.0

func _ready() -> void:
	player = AudioStreamPlayer.new()
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 22050.0
	stream.buffer_length = 0.15
	player.stream = stream
	add_child(player)
	player.play()
	playback = player.get_stream_playback()

func play_tone(new_frequency: float, new_duration: float) -> void:
	if enabled:
		frequency = new_frequency
		duration = new_duration
		time = 0.0

func _process(_delta: float) -> void:
	if playback == null:
		return
	for i in range(playback.get_frames_available()):
		var sample := 0.0
		if time < duration:
			var fade := 1.0 - time / duration
			sample = sin(time * frequency * TAU) * fade * 0.18
			time += 1.0 / 22050.0
		playback.push_frame(Vector2(sample, sample))
