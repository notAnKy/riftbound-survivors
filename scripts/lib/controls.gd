class_name Controls
extends RefCounted

# Per-device movement actions.
#
# `move_*` is both devices at once, which is what a solo player wants: pick up
# whichever is nearest and it works. That is exactly wrong in co-op, where two
# people sit at one machine -- the pad player would drag the keyboard player
# around and vice versa. So each device also gets its own set, registered here
# from the same key and button lists, and a Player reads whichever set its seat
# was given.

const ANY := ["move_left", "move_right", "move_up", "move_down"]
const KEYBOARD := ["kb_left", "kb_right", "kb_up", "kb_down"]
const PAD := ["pad_left", "pad_right", "pad_up", "pad_down"]

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

		var pad := String(PAD[i])
		if not InputMap.has_action(pad):
			InputMap.add_action(pad, 0.5)
		var button := InputEventJoypadButton.new()
		button.button_index = int(PAD_BUTTONS[i])
		InputMap.action_add_event(pad, button)
		var spec: Array = PAD_AXES[i]
		var motion := InputEventJoypadMotion.new()
		motion.axis = int(spec[0])
		motion.axis_value = float(spec[1])
		InputMap.action_add_event(pad, motion)

# The four action names a seat should read, by the device it was given.
static func actions_for(device: String) -> Array:
	match device:
		"keyboard": return KEYBOARD
		"pad": return PAD
	return ANY

static func vector_for(device: String) -> Vector2:
	var actions := actions_for(device)
	return Input.get_vector(String(actions[0]), String(actions[1]),
		String(actions[2]), String(actions[3]))
