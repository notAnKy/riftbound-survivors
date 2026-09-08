class_name Controls
extends RefCounted

# Per-device movement actions.
#
# `move_*` is every device at once, which is what a solo player wants: pick up
# whichever is nearest and it works. That is exactly wrong in co-op, where two
# people sit at one machine -- one would drag the other around. So each device
# also gets its own set, registered here from the same key and button lists, and
# a Player reads whichever set its seat was given.
#
# There is no "the keyboard is player one" any more. A device is `kb`, `pad0` or
# `pad1`, seats are handed out in the order people actually join, and two pads
# is as valid a pairing as a pad and a keyboard.

const ANY := ["move_left", "move_right", "move_up", "move_down"]
const KEYBOARD := ["kb_left", "kb_right", "kb_up", "kb_down"]
# One set per pad, bound to that pad's device index so the two cannot bleed.
const MAX_PADS := 2
const PADS := [
	["pad0_left", "pad0_right", "pad0_up", "pad0_down"],
	["pad1_left", "pad1_right", "pad1_up", "pad1_down"],
]

# In the order the action lists above use: left, right, up, down.
const KEYS := [
	[KEY_A, KEY_LEFT],
	[KEY_D, KEY_RIGHT],
	[KEY_W, KEY_UP],
	[KEY_S, KEY_DOWN],
]
const PAD_BUTTONS := [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT,
	JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN]
const PAD_AXES := [
	[JOY_AXIS_LEFT_X, -1.0],
	[JOY_AXIS_LEFT_X, 1.0],
	[JOY_AXIS_LEFT_Y, -1.0],
	[JOY_AXIS_LEFT_Y, 1.0],
]

# The InputMap is global while a GameSession is not, so this latches: the test
# suite builds a dozen games in one process and each would otherwise staple
# another copy of the same bindings onto the map.
static var _bound := false

static func bind_all() -> void:
	if _bound: return
	_bound = true
	for i in range(4):
		var keyboard := String(KEYBOARD[i])
		if not InputMap.has_action(keyboard):
			InputMap.add_action(keyboard, 0.5)
		for code in KEYS[i]:
			var key := InputEventKey.new()
			key.physical_keycode = int(code)
			InputMap.action_add_event(keyboard, key)

		for pad_index in range(MAX_PADS):
			var pad := String(PADS[pad_index][i])
			if not InputMap.has_action(pad):
				InputMap.add_action(pad, 0.5)
			# `device` is what keeps two pads apart. Without it both sets would
			# answer to whichever controller moved, and the second player would
			# steer the first.
			var button := InputEventJoypadButton.new()
			button.button_index = int(PAD_BUTTONS[i])
			button.device = pad_index
			InputMap.action_add_event(pad, button)
			var spec: Array = PAD_AXES[i]
			var motion := InputEventJoypadMotion.new()
			motion.axis = int(spec[0])
			motion.axis_value = float(spec[1])
			motion.device = pad_index
			InputMap.action_add_event(pad, motion)

# Which device an input event came from, in the vocabulary above. This is the
# one place a raw event turns into a device name.
static func device_of(event: InputEvent) -> String:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return "pad%d" % clampi(event.device, 0, MAX_PADS - 1)
	return "kb"

static func is_pad(device: String) -> bool:
	return device.begins_with("pad")

# The joypad index behind a device name, or -1 for the keyboard.
static func pad_index(device: String) -> int:
	return int(device.trim_prefix("pad")) if is_pad(device) else -1

# Everything that could join a co-op game right now: the keyboard, plus each
# pad actually plugged in.
static func join_candidates() -> Array:
	var found: Array = ["kb"]
	for index in Input.get_connected_joypads():
		if index < MAX_PADS: found.append("pad%d" % index)
	return found

# Whether this device is holding its join button.
static func join_held(device: String) -> bool:
	if is_pad(device):
		return Input.is_joy_button_pressed(pad_index(device), Gamepad.CROSS)
	return Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_ENTER)

# What to call a device on screen. Seats no longer imply a device, so the lobby
# has to say which one actually took each one.
static func label(device: String) -> String:
	if device == "kb": return "KEYBOARD"
	var index := pad_index(device)
	if index >= 0: return "CONTROLLER %d" % (index + 1)
	return "OPEN"

# The four action names a seat should read, by the device it was given.
static func actions_for(device: String) -> Array:
	if device == "kb": return KEYBOARD
	var index := pad_index(device)
	if index >= 0 and index < MAX_PADS: return PADS[index]
	return ANY

static func vector_for(device: String) -> Vector2:
	var actions := actions_for(device)
	return Input.get_vector(String(actions[0]), String(actions[1]),
		String(actions[2]), String(actions[3]))
