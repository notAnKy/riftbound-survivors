class_name Survivor
extends RefCounted

# One player's half of a run.
#
# Every field here used to sit directly on GameSession as a single set, because
# there was only ever one of them. Co-op is the reason it is a thing you can
# have two of. GameSession still forwards all the old names to survivor 0, so
# solo play, the HUD and every existing test go on speaking in the singular and
# only the co-op paths ever name a seat.

var seat := 0
# Which device drives this seat. Solo is "any" and both work at once; in co-op
# one player is pinned to the keyboard and the other to the pad, or the two of
# them would steer each other around the arena.
var device := "any"

var player: Player = null
var stats := Stats.new()
var weapons: Array[Weapon] = []
var items: Array[String] = []
# Level-up grants are kept apart from the items, because the sheet is rebuilt
# from scratch whenever the inventory changes and they have to survive that.
var upgrade_totals: Dictionary = {}
var upgrades: Array[Dictionary] = []
# A board each: the whole point of the split shop is that the two players are
# not fighting over the same four offers.
var shop := Shop.new()

# Materials are earned by whoever walks over the drop, so they are per seat as
# well -- which is what makes spreading out to collect worth doing.
var materials := 0
var level := 1
var xp := 0
var xp_to_next := Balance.XP_FIRST_LEVEL
var nova_cooldown := 0.0

var character := 0
var weapon_slots := 6
var allowed_kinds: Array = []

# Down, not dead. A downed survivor is out for the rest of the round and comes
# back at the start of the next one, as long as somebody was still standing when
# it ended. The run only ends when nobody is left.
var downed := false
# Whether this seat has pressed NEXT WAVE. Both have to before the wave starts,
# or one player would drag the other out of the shop mid-purchase.
var ready := false

func alive() -> bool:
	return not downed and is_instance_valid(player) and player.alive

# The level-up overlay stays up while anybody still has a choice to make.
func choosing() -> bool:
	return not upgrades.is_empty()
