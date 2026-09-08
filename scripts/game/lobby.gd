class_name Lobby
extends RefCounted

# The co-op join screen: two seats decide, in order, whether they are playing,
# who they are, and what they start holding. Only then does a run begin.
#
# It lives apart from GameSession because none of the survivors exist yet --
# reset_run builds them from what is decided here.

const SEATS := 2
const STAGES := ["character", "weapon"]
# How long the button has to be held to join. Long enough that a thumb resting
# on a pad, or a Space pressed for something else, does not sign anybody up.
const HOLD_TIME := 0.55

var stage := "character"
# Untyped on purpose: a typed Array[bool] rejects a plain `[false, false]`
# literal at runtime, and these are reassigned wholesale on every reset.
var joined: Array = [false, false]
# Which device took each seat, in the order they finished holding. There is no
# "the keyboard is player one" -- two pads is as valid a pairing as a pad and a
# keyboard, and the seat is decided by who joined first.
var seat_device: Array = ["", ""]
# Hold progress per *device*, not per seat, for exactly that reason: the seat
# does not exist until the hold completes.
var device_hold: Dictionary = {}
var character: Array = [0, 0]
var gun: Array = [0, 0]
var locked: Array = [false, false]

# Catalog indices this profile has actually unlocked. Navigation walks these
# rather than the whole catalog, so a seat can never settle on something the
# player does not own -- buying is the armory's job, not the lobby's.
var allowed_characters: Array = [0]
var allowed_guns: Array = [0]

func reset(characters: Array, guns: Array) -> void:
	stage = "character"
	joined = [false, false]
	seat_device = ["", ""]
	device_hold = {}
	locked = [false, false]
	allowed_characters = characters if not characters.is_empty() else [0]
	allowed_guns = guns if not guns.is_empty() else [0]
	character = [int(allowed_characters[0]), int(allowed_characters[0])]
	gun = [int(allowed_guns[0]), int(allowed_guns[0])]

func options() -> Array:
	return allowed_characters if stage == "character" else allowed_guns

func selection(seat: int) -> int:
	return int(character[seat]) if stage == "character" else int(gun[seat])

func set_selection(seat: int, value: int) -> void:
	if bool(locked[seat]) or not (value in options()): return
	if stage == "character": character[seat] = value
	else: gun[seat] = value

func move(seat: int, step: int) -> void:
	if bool(locked[seat]): return
	var list := options()
	if list.is_empty(): return
	var at := list.find(selection(seat))
	at = 0 if at < 0 else wrapi(at + step, 0, list.size())
	set_selection(seat, int(list[at]))

func count() -> int:
	var total := 0
	for seat in joined:
		if bool(seat): total += 1
	return total

# Co-op means two. One player holding the screen alone never starts a run.
func everyone_in() -> bool:
	return count() == SEATS

func all_locked() -> bool:
	if not everyone_in(): return false
	for seat in locked:
		if not bool(seat): return false
	return true

func last_stage() -> bool:
	return stage == String(STAGES[STAGES.size() - 1])

func advance() -> bool:
	var at := STAGES.find(stage)
	if at < 0 or at >= STAGES.size() - 1: return false
	stage = String(STAGES[at + 1])
	locked = [false, false]
	return true

func step_back() -> bool:
	var at := STAGES.find(stage)
	if at <= 0: return false
	stage = String(STAGES[at - 1])
	locked = [false, false]
	return true

# Returns true on the frame the hold completes, so the caller can make a noise
# about it. Joining is only open during the first stage: once everybody is
# picking weapons, the roster is settled.
# One device's hold, ticked. Returns the seat it just claimed, or -1. Joining is
# a hold rather than a press so a thumb resting on a pad, or a Space pressed for
# something else, cannot sign anybody up.
func tick_join(device: String, delta: float, held: bool) -> int:
	if seat_of(device) >= 0 or stage != "character" or not held:
		device_hold[device] = 0.0
		return -1
	device_hold[device] = float(device_hold.get(device, 0.0)) + delta
	if float(device_hold[device]) < HOLD_TIME: return -1
	device_hold[device] = 0.0
	return claim(device)

func seat_of(device: String) -> int:
	return seat_device.find(device) if device != "" else -1

# The lowest free seat, so the first to finish holding is player one.
func claim(device: String) -> int:
	for i in range(SEATS):
		if String(seat_device[i]) == "":
			seat_device[i] = device
			joined[i] = true
			return i
	return -1

# Progress for a seat nobody has taken yet. Holds belong to *devices* now, and a
# device has no seat until its hold finishes, so an empty seat shows whichever
# unclaimed device is furthest along -- which is the one about to fill it.
func hold_ratio(seat: int) -> float:
	if bool(joined[seat]): return 1.0
	var best := 0.0
	for device in device_hold:
		if seat_of(String(device)) >= 0: continue
		best = maxf(best, float(device_hold[device]))
	return clampf(best / HOLD_TIME, 0.0, 1.0)

# What each seat takes into the run, in seat order.
func characters() -> Array[int]:
	var picks: Array[int] = []
	for seat in range(SEATS): picks.append(int(character[seat]))
	return picks

func guns() -> Array[int]:
	var picks: Array[int] = []
	for seat in range(SEATS): picks.append(int(gun[seat]))
	return picks
