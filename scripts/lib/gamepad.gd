class_name Gamepad
extends RefCounted

# Everything that knows a controller exists: the extra input-map bindings, which
# brand of pad is plugged in, and what each button is called on screen.
#
# The bindings are registered from code rather than authored into
# project.godot. That file stores an InputEvent as a serialised object literal
# -- unreadable, and easy to corrupt with a hand edit -- and the arena walls and
# the prop scatter are already built in code for the same reason: one readable
# source beats a generated resource nobody can diff.

# Godot names the face buttons after their position on an Xbox pad, and a
# DualShock reports the same indices: Cross sits where A does, Circle where B
# does. So these are the PlayStation names for the Xbox numbers, and nothing
# else in the game has to know that they are the same button.
const CROSS := JOY_BUTTON_A
const CIRCLE := JOY_BUTTON_B
const SQUARE := JOY_BUTTON_X
const TRIANGLE := JOY_BUTTON_Y
const OPTIONS := JOY_BUTTON_START
# The shoulder, for a screen that needs one more verb than the face has room
# for -- the shop wants pin, reroll and next wave all reachable without walking
# the cursor over to a button.
const R1 := JOY_BUTTON_RIGHT_SHOULDER

# Past this the stick counts as pushed for menu navigation. Deliberately well
# above the movement deadzone: a thumb resting on the stick must not scroll a
# menu, even though the same push would drift the player in a fight.
const MENU_DEADZONE := 0.6
# Hold-to-repeat, so one flick moves one row but holding still scrolls.
const REPEAT_FIRST := 0.42
const REPEAT_NEXT := 0.14

# Substrings of the reported pad name that mean PlayStation. Windows reports a
# DualShock 4 over Bluetooth as plain "Wireless Controller", which is why that
# vague-looking entry is in the list.
const PLAYSTATION_NAMES := ["ps3", "ps4", "ps5", "playstation", "dualshock",
	"dualsense", "sony", "wireless controller"]

# The movement actions already exist for the keyboard; this hangs the stick and
# the d-pad off the same four, so Player.get_vector never learns there is a
# controller.
#
# The InputMap is global while a GameController is not, so the latch matters:
# the test suite builds a dozen games in one process, and without it every one
# would staple another copy of the same four bindings onto the map.
static var _bound := false

static func bind_movement() -> void:
	if _bound: return
	_bound = true
	var axes := {
		"move_left": [JOY_AXIS_LEFT_X, -1.0],
		"move_right": [JOY_AXIS_LEFT_X, 1.0],
		"move_up": [JOY_AXIS_LEFT_Y, -1.0],
		"move_down": [JOY_AXIS_LEFT_Y, 1.0],
	}
	var pad := {
		"move_left": JOY_BUTTON_DPAD_LEFT,
		"move_right": JOY_BUTTON_DPAD_RIGHT,
		"move_up": JOY_BUTTON_DPAD_UP,
		"move_down": JOY_BUTTON_DPAD_DOWN,
	}
	for action in axes:
		var name := String(action)
		if not InputMap.has_action(name): continue
		var spec: Array = axes[action]
		var motion := InputEventJoypadMotion.new()
		motion.axis = int(spec[0])
		motion.axis_value = float(spec[1])
		InputMap.action_add_event(name, motion)
		var button := InputEventJoypadButton.new()
		button.button_index = int(pad[action])
		InputMap.action_add_event(name, button)

static func connected() -> bool:
	return not Input.get_connected_joypads().is_empty()

# "playstation" or "xbox". Only the glyph names differ -- every binding is the
# same on both -- so an unrecognised pad falling back to letters is harmless.
static func brand() -> String:
	var pads := Input.get_connected_joypads()
	if pads.is_empty(): return "xbox"
	var name := Input.get_joy_name(int(pads[0])).to_lower()
	for token in PLAYSTATION_NAMES:
		if name.contains(String(token)): return "playstation"
	return "xbox"

# What to put in a button badge. PlayStation face buttons are shapes, so this
# returns a shape name the UI draws itself; neither bundled font has a glyph
# for them. An Xbox pad returns the letter, drawn as text in the same badge.
static func glyph(button: int) -> String:
	if brand() == "playstation":
		if button == CROSS: return "cross"
		if button == CIRCLE: return "circle"
		if button == SQUARE: return "square"
		if button == TRIANGLE: return "triangle"
		if button == OPTIONS: return "options"
		if button == R1: return "R1"
		return "cross"
	if button == CROSS: return "A"
	if button == CIRCLE: return "B"
	if button == SQUARE: return "X"
	if button == TRIANGLE: return "Y"
	if button == OPTIONS: return "options"
	if button == R1: return "RB"
	return "A"

# The face-button colours a PlayStation pad is printed with. An Xbox letter
# borrows the same slot colour, which keeps confirm green-blue and back red
# whichever pad is plugged in.
const COLORS := {
	"cross": Color("8ea6e8"),
	"circle": Color("ff6d7d"),
	"square": Color("ef7ad0"),
	"triangle": Color("5ee0a8"),
	"options": Color("cddcf7"),
	"R1": Color("cddcf7"), "RB": Color("cddcf7"),
	"A": Color("8ea6e8"),
	"B": Color("ff6d7d"),
	"X": Color("ef7ad0"),
	"Y": Color("5ee0a8"),
}

static func color(glyph_name: String) -> Color:
	return COLORS.get(glyph_name, Color("cddcf7"))
