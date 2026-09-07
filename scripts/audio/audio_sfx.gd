class_name AudioSfx
extends Node

# Kenney CC0 samples played through a pool of voices. The old version was a
# single generated sine: every shot cut off the previous shot, the kill and the
# pickup, so a busy wave was one voice fighting itself.

const SOUND_DIR := "res://assets/audio/"
const MUSIC_DIR := "res://assets/music/"
# Enough that a shotgun volley, a kill and a pickup can all ring at once
# without a burst of SMG fire starving everything else.
const VOICES := 20

# name -> how many numbered variations exist on disk. More than one means the
# sound is picked at random each time, which is what stops a fast weapon
# sounding like a stuck loop.
const BANKS := {
	"shoot_light": 3, "shoot_medium": 3, "shoot_heavy": 3,
	"hit": 3, "crit": 2, "kill": 3, "player_hurt": 2, "pickup": 2, "boom": 2,
	"nova": 1, "dash": 1, "heal": 1, "level_up": 1, "wave_clear": 1,
	"buy": 1, "sell": 1, "reroll": 1, "ui_click": 1, "ui_move": 1,
	"merge": 1, "victory": 1,
}

# The mix, in dB against the master volume. One table, because a mix is a set of
# relationships and these used to be two dozen literals scattered across the
# call sites with no relationship at all -- `kill` sat at -3dB and fires once per
# enemy, which late in a run is dozens a second, while `wave_clear` fires once a
# wave at the same level.
#
# The organizing principle is how often a sound fires. Anything on the constant
# list is heard hundreds of times a wave and has to sit well under the things
# that are supposed to mean something.
const MIX := {
	# Constant: every shot, every hit, every pickup, every death.
	"hit": -20.0, "kill": -14.0, "pickup": -15.0,
	"shoot_light": -17.0, "shoot_medium": -13.0, "shoot_heavy": -10.0,
	# Frequent, but each one is telling you something happened.
	"crit": -9.0, "dash": -8.0, "heal": -6.0, "merge": -4.0,
	# Rare, and allowed to cut through a busy wave.
	"player_hurt": -2.0, "boom": -3.0, "nova": 0.0,
	"level_up": -2.0, "wave_clear": -3.0, "victory": 0.0,
	# UI. The shop is not silent, so these stay under a fight rather than over it.
	"buy": -7.0, "sell": -8.0, "reroll": -8.0, "ui_click": -9.0, "ui_move": -15.0,
}

# The shortest gap between two plays of the same bank, in seconds.
#
# Without this, a frame that kills forty enemies asks for forty voices out of a
# pool of twenty: they steal each other mid-attack and the result is a click
# rather than forty kills. Only the sounds that can burst are listed; everything
# else is rare enough to look after itself.
const THROTTLE := {
	"hit": 0.045, "crit": 0.06, "kill": 0.05, "pickup": 0.05,
	"shoot_light": 0.04, "shoot_medium": 0.05, "shoot_heavy": 0.06,
}

var enabled := true
# Bank name -> the millisecond at which it may next be heard.
var next_allowed: Dictionary = {}
var volume := 0.7
var music_volume := 0.45
var music: AudioStreamPlayer
var current_track := ""
var banks: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var next_voice := 0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	for i in range(VOICES):
		var player := AudioStreamPlayer.new()
		add_child(player)
		voices.append(player)
	music = AudioStreamPlayer.new()
	add_child(music)
	# MP3 loop points are set on the stream, but a finished signal is a cheap
	# belt-and-braces restart if a decoder ever drops the loop.
	music.finished.connect(func() -> void:
		if current_track != "" and music_volume > 0.0: music.play())
	for name in BANKS:
		banks[name] = load_bank(String(name), int(BANKS[name]))

func load_bank(name: String, count: int) -> Array:
	var streams: Array = []
	if count > 1:
		for i in range(count):
			var stream := find_stream("%s_%d" % [name, i])
			if stream != null: streams.append(stream)
	else:
		var stream := find_stream(name)
		if stream != null: streams.append(stream)
	return streams

# The packs mix .ogg and .wav, so the extension is resolved rather than baked
# into the sound map.
func find_stream(stem: String) -> AudioStream:
	for ext in [".ogg", ".wav"]:
		var path: String = SOUND_DIR + stem + ext
		if ResourceLoader.exists(path): return load(path) as AudioStream
	return null

# `gain` is a trim on top of that sound's entry in MIX, for the cases where the
# same sound genuinely wants two levels -- a fast weapon against a slow one.
# `jitter` detunes each shot a little so repeats do not phase into one flat tone.
func play(name: String, gain: float = 0.0, jitter: float = 0.07) -> void:
	if not enabled or voices.is_empty(): return
	var bank: Array = banks.get(name, [])
	if bank.is_empty(): return
	var wait := float(THROTTLE.get(name, 0.0))
	if wait > 0.0:
		var now := Time.get_ticks_msec()
		if now < int(next_allowed.get(name, 0)): return
		next_allowed[name] = now + int(wait * 1000.0)
	# Round-robin, so a new sound steals the oldest voice rather than the one
	# that just started.
	var player: AudioStreamPlayer = voices[next_voice]
	next_voice = (next_voice + 1) % voices.size()
	player.stream = bank[rng.randi_range(0, bank.size() - 1)]
	player.pitch_scale = 1.0 + rng.randf_range(-jitter, jitter)
	player.volume_db = linear_to_db(clampf(volume, 0.001, 1.0)) + float(MIX.get(name, -6.0)) + gain
	player.play()

# Switching to the track already playing is a no-op, so this is safe to call
# every frame from the state machine.
func play_music(track: String) -> void:
	if track == current_track: return
	current_track = track
	if track == "" or music_volume <= 0.0:
		music.stop()
		return
	start_track()

func start_track() -> void:
	var stream := load(MUSIC_DIR + current_track + ".mp3") as AudioStream
	if stream == null: return
	if stream is AudioStreamMP3: stream.loop = true
	music.stream = stream
	music.volume_db = linear_to_db(clampf(music_volume, 0.001, 1.0))
	music.play()

func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	if music_volume <= 0.0:
		music.stop()
	else:
		music.volume_db = linear_to_db(music_volume)
		if not music.playing and current_track != "": start_track()

func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	enabled = volume > 0.0

func stop_all() -> void:
	for player in voices:
		player.stop()
	next_allowed.clear()
