class_name DisplaySettings
extends RefCounted

# Window mode, resolution and quality: the three display settings, their lists,
# and what applying each one actually does.
#
# They live together because they interact. Resolution only means anything in a
# window -- both fullscreen modes take the monitor -- so the settings screen
# greys it out rather than pretending otherwise, and the quality preset is the
# one of the three that changes how the game runs rather than how it looks.

const WINDOW_MODES := ["WINDOWED", "BORDERLESS", "FULLSCREEN"]
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]

# Quality is a frame-cost dial, not a prettiness dial. Each preset caps the
# things that multiply with the crowd: floating damage numbers, the scatter, and
# how hard the screen is allowed to move.
const QUALITY := ["LOW", "MEDIUM", "HIGH"]
const QUALITY_NUMBERS := [18, 36, 60]
const QUALITY_PROPS := [0, 10, 22]
const QUALITY_SHAKE := [0.0, 0.7, 1.0]

static func resolution_label(index: int) -> String:
	var size: Vector2i = RESOLUTIONS[clampi(index, 0, RESOLUTIONS.size() - 1)]
	return "%d x %d" % [size.x, size.y]

# Borderless is MODE_FULLSCREEN, which in Godot 4 is a borderless window sized
# to the monitor -- alt-tab stays instant. MODE_EXCLUSIVE_FULLSCREEN is the real
# mode switch, which is the one worth having for a machine that struggles.
static func apply_window(window: Window, mode_index: int, resolution_index: int) -> void:
	match clampi(mode_index, 0, WINDOW_MODES.size() - 1):
		1: window.mode = Window.MODE_FULLSCREEN
		2: window.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		_:
			window.mode = Window.MODE_WINDOWED
			window.size = RESOLUTIONS[clampi(resolution_index, 0, RESOLUTIONS.size() - 1)]
			# Re-centred, or a window that just grew can end up mostly offscreen.
			var screen := DisplayServer.screen_get_usable_rect(window.current_screen)
			window.position = screen.position + (screen.size - window.size) / 2

static func numbers_cap(quality_index: int) -> int:
	return QUALITY_NUMBERS[clampi(quality_index, 0, QUALITY.size() - 1)]

static func prop_count(quality_index: int) -> int:
	return QUALITY_PROPS[clampi(quality_index, 0, QUALITY.size() - 1)]

static func shake_scale(quality_index: int) -> float:
	return QUALITY_SHAKE[clampi(quality_index, 0, QUALITY.size() - 1)]
