class_name GameUI
extends Node2D

# Immediate-mode drawing. Every clickable thing gets its rectangle from a
# helper below, and menu_action_at hit-tests the same helpers, so a layout
# change never has to be made twice.

const SCREEN := Vector2(1920, 1080)
const MARGIN := 48.0

const SHOP_CARDS := 4
const CARD_SIZE := Vector2(340, 250)
const CARD_TOP := 230.0
const CARD_GAP := 26.0
const BUTTON_SIZE := Vector2(300, 58)
const BUTTON_TOP := 512.0
const SLOT_SIZE := Vector2(250, 62)
const SLOT_TOP := 640.0
const SLOT_GAP := 14.0

const UPGRADE_TOP := 400.0

const ROW_SIZE := Vector2(700, 66)
# Settings has ten rows now and they have to fit above MENU_FOOTER, so its rows
# are their own, shorter size rather than the shared menu one.
const SETTINGS_ROW := Vector2(700, 54)
const SETTINGS_GAP := 8.0
const ROW_GAP := 12.0
# Lifted when the display rows arrived: eight rows plus a hint line and the
# mouse footer no longer fit under the old start. Same failure the title screen
# had when it grew a sixth row -- a footer placed relative to the last row goes
# off the bottom rather than overlapping, which is quieter and worse.
const SETTINGS_TOP := 296.0
const PAUSE_TOP := 450.0
const CONFIRM_TOP := 520.0

const MENU_BUTTON := Vector2(440, 58)
const MENU_TOP := 404.0
const MENU_STEP := 72.0
# How much room the title screen needs under its last button for the coin line,
# the prompts and the click hint. A test holds the whole menu plus this inside
# the screen, because adding ACHIEVEMENTS as a sixth row is exactly what pushed
# QUIT GAME on top of all three.
const MENU_FOOTER := 126.0

# Co-op gives each player half the display. The cards and slots keep their size
# and wrap into a grid rather than shrinking -- that is the difference between a
# readable shop and a small one, and half of 1920 still fits two 340px cards.
const COOP_COLUMNS := 2
const COOP_SLOT_COLUMNS := 3
const COOP_CARD_TOP := 200.0
const COOP_BUTTON_TOP := 740.0
const COOP_SLOT_TOP := 856.0
const COOP_UPGRADE_TOP := 300.0

# The co-op join screen. One panel per seat, and a row of picks under each.
const LOBBY_BOX_TOP := 210.0
const LOBBY_BOX_HEIGHT := 560.0
const LOBBY_CHIP := Vector2(132, 46)
const LOBBY_CHIP_GAP := 9.0
const LOBBY_CHIP_TOP := 646.0

var game: GameController

# The region the current screen is laid out into. Every rect helper below reads
# it, so the split is expressed in exactly one place: set the pane, draw the
# screen, and the same code lays out a half as readily as the whole display.
var pane := Rect2(Vector2.ZERO, SCREEN)
var font: Font
var display: Font

func _ready() -> void:
	game = get_parent() as GameController
	# Linear. The actor art is vector rasterised well above its drawn size, and
	# nearest on a downscale of that is all jagged edges -- the opposite of the
	# pixel-art case this used to be set for.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# Rajdhani for text, Orbitron for headings. The engine fallback font is
	# what made every screen read as a prototype.
	font = load("res://assets/fonts/Rajdhani-SemiBold.ttf") as Font
	if font == null: font = ThemeDB.fallback_font
	display = build_display_font()

func build_display_font() -> Font:
	var orbitron := load("res://assets/fonts/Orbitron.ttf") as FontFile
	if orbitron == null: return font
	# Orbitron ships as a variable font; without this it renders at its
	# lightest weight, which is far too thin for a title.
	var heavy := FontVariation.new()
	heavy.base_font = orbitron
	heavy.variation_opentype = {"wght": 800}
	return heavy

func _draw() -> void:
	if game == null: return
	if game.state == "title": draw_title()
	elif game.state == "lobby": draw_lobby()
	elif game.state == "armory": draw_armory()
	elif game.state == "awards": draw_awards()
	elif game.state == "controls": draw_controls()
	elif game.state == "settings": draw_settings("SETTINGS", "ESC: back to title")
	else:
		# These three are full screens with their own headers and panels, so the
		# combat HUD under them just shows doubled numbers through the overlay.
		if not (game.state in ["shop", "victory", "game_over"]): draw_hud()
		if game.state == "level_up": draw_upgrades()
		elif game.state == "shop": draw_shop()
		elif game.state == "paused": draw_pause()
		elif game.state == "confirm_quit": draw_confirm_quit()
		elif game.state == "settings_pause": draw_settings("PAUSE SETTINGS", "ESC: back to pause")
		elif game.state == "game_over": draw_game_over()
		elif game.state == "victory": draw_victory()

# --- layout ------------------------------------------------------------------

func text_at(position: Vector2, text: String, size: int, color: Color) -> void:
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func text_width(text: String, size: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

func text_centered(centre_x: float, y: float, text: String, size: int, color: Color) -> void:
	text_at(Vector2(centre_x - text_width(text, size) * 0.5, y), text, size, color)

# Headings go through the display face; body text stays on Rajdhani.
func heading(centre_x: float, y: float, text: String, size: int, color: Color) -> void:
	var width := display.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(display, Vector2(centre_x - width * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func heading_right(right_x: float, y: float, text: String, size: int, color: Color) -> void:
	var width := display.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(display, Vector2(right_x - width, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func text_right(right_x: float, y: float, text: String, size: int, color: Color) -> void:
	text_at(Vector2(right_x - text_width(text, size), y), text, size, color)

func row_rect(index: int, count: int, size: Vector2, top: float, gap: float) -> Rect2:
	var total := size.x * count + gap * (count - 1)
	return Rect2(Vector2(pane.position.x + (pane.size.x - total) * 0.5 + index * (size.x + gap),
		pane.position.y + top), size)

# The same, wrapped into rows of `columns`. Co-op is the only caller: half the
# width will not take four cards across, but it takes two, twice.
func grid_rect(index: int, count: int, columns: int, size: Vector2, top: float, gap: float) -> Rect2:
	var across := mini(columns, maxi(1, count))
	var total := size.x * across + gap * (across - 1)
	var col := index % columns
	var row := index / columns
	return Rect2(Vector2(pane.position.x + (pane.size.x - total) * 0.5 + float(col) * (size.x + gap),
		pane.position.y + top + float(row) * (size.y + gap)), size)

# Sets the region the helpers lay out into. Solo is the whole display; co-op is
# one half per player. This is the only place the split screen exists.
func use_pane(at_seat: int) -> void:
	if not game.coop:
		pane = Rect2(Vector2.ZERO, SCREEN)
		return
	pane = Rect2(Vector2(SCREEN.x * 0.5 * float(at_seat), 0.0), Vector2(SCREEN.x * 0.5, SCREEN.y))

func card_rect(index: int) -> Rect2:
	if not game.coop: return row_rect(index, SHOP_CARDS, CARD_SIZE, CARD_TOP, CARD_GAP)
	return grid_rect(index, SHOP_CARDS, COOP_COLUMNS, CARD_SIZE, COOP_CARD_TOP, CARD_GAP)

# The level-up cards are laid out the same way, but there are as many of them
# as the roll produced rather than a fixed four.
func upgrade_rect(index: int, at_seat: int = 0) -> Rect2:
	var who := game.session.seat(at_seat)
	var count: int = maxi(1, who.upgrades.size() if who != null else 1)
	if not game.coop: return row_rect(index, count, CARD_SIZE, UPGRADE_TOP, CARD_GAP)
	return grid_rect(index, count, COOP_COLUMNS, CARD_SIZE, COOP_UPGRADE_TOP, CARD_GAP)

func slot_count() -> int:
	return game.session.weapon_slots

func slot_rect(index: int) -> Rect2:
	if not game.coop: return row_rect(index, slot_count(), SLOT_SIZE, SLOT_TOP, SLOT_GAP)
	return grid_rect(index, slot_count(), COOP_SLOT_COLUMNS, SLOT_SIZE, COOP_SLOT_TOP, SLOT_GAP)

func slots_bottom() -> float:
	return slot_rect(slot_count() - 1).end.y

func button_top() -> float:
	return COOP_BUTTON_TOP if game.coop else BUTTON_TOP

# The right end of a weapon slot. The rest of the slot still sells, so the two
# actions never share a pixel.
# The pin chip, in the bottom-right of an offer card. The rest of the card
# still buys, so the two actions never share a pixel.
func card_lock_rect(index: int) -> Rect2:
	var rect := card_rect(index)
	return Rect2(rect.end.x - 86.0, rect.end.y - 42.0, 74.0, 30.0)

func slot_combine_rect(index: int) -> Rect2:
	var rect := slot_rect(index)
	return Rect2(rect.end.x - 86.0, rect.position.y + 16.0, 78.0, 30.0)

func reroll_rect() -> Rect2:
	return Rect2(Vector2(card_rect(0).position.x, button_top()), BUTTON_SIZE)

func go_rect() -> Rect2:
	return Rect2(Vector2(card_rect(SHOP_CARDS - 1).end.x - BUTTON_SIZE.x, button_top()), BUTTON_SIZE)

func menu_button_rect(index: int) -> Rect2:
	return Rect2(Vector2((SCREEN.x - MENU_BUTTON.x) * 0.5, MENU_TOP + index * MENU_STEP), MENU_BUTTON)

func danger_rect(index: int) -> Rect2:
	return row_rect(index, Balance.DANGER_LEVELS, Vector2(80, 46), 776.0, 12.0)

func armory_back_rect() -> Rect2:
	return Rect2(60, 60, 170, 52)

# The survivor panel on the armory, and the BACK button on the controls screen.
# Both were laid out inline where they are drawn, which is exactly how a thing
# ends up visible and unclickable -- menu_action_at has nothing to test against.
func character_panel_rect() -> Rect2:
	return Rect2((SCREEN.x - 1000.0) * 0.5, 580, 1000, 150)

func controls_back_rect() -> Rect2:
	var after := 196.0 + float(game.CONTROL_ROWS.size()) * 52.0 + 30.0
	return Rect2(Vector2((SCREEN.x - BUTTON_SIZE.x) * 0.5, after), BUTTON_SIZE)

# The draggable part of a slider row, and the click position expressed as a
# 0..1 ratio along it.
func settings_bar_rect(index: int) -> Rect2:
	var row := settings_row_rect(index)
	return Rect2(row.position.x + 300.0, row.position.y + 24.0, row.size.x - 400.0, 18.0)

func slider_ratio_at(index: int, point: Vector2) -> float:
	var bar := settings_bar_rect(index)
	return clampf((point.x - bar.position.x) / maxf(bar.size.x, 1.0), 0.0, 1.0)

func settings_row_rect(index: int) -> Rect2:
	return Rect2(Vector2((SCREEN.x - SETTINGS_ROW.x) * 0.5, SETTINGS_TOP + index * (SETTINGS_ROW.y + SETTINGS_GAP)), SETTINGS_ROW)

func pause_row_rect(index: int) -> Rect2:
	return Rect2(Vector2((SCREEN.x - ROW_SIZE.x) * 0.5, PAUSE_TOP + index * (ROW_SIZE.y + ROW_GAP)), ROW_SIZE)

func confirm_row_rect(index: int) -> Rect2:
	return Rect2(Vector2((SCREEN.x - ROW_SIZE.x) * 0.5, CONFIRM_TOP + index * (ROW_SIZE.y + ROW_GAP)), ROW_SIZE)

# A row is lit either because the mouse is over it or because the keyboard
# cursor is on it; the controller keeps those two in step.
func is_focused(action: String, at_seat: int = 0) -> bool:
	# Hover belongs to the mouse, and the mouse is always seat 0's.
	if at_seat == 0 and game.menu_hover == action: return true
	var items := game.menu_items(at_seat)
	var index := game.cursor(at_seat)
	return index >= 0 and index < items.size() and items[index] == action

func gun_rect(index: int) -> Rect2:
	return row_rect(index, 3, Vector2(400, 240), 280.0, 40.0)

func menu_action_at(point: Vector2) -> String:
	# The mouse is seat 0's, so everything below hit-tests against seat 0's pane.
	use_pane(0)
	if game.state == "title":
		# Straight off menu_items: this once carried its own copy of the rows,
		# and adding one sent every click to the wrong entry.
		var actions := game.menu_items()
		for i in range(actions.size()):
			if menu_button_rect(i).has_point(point): return actions[i]
	elif game.state == "armory":
		if armory_back_rect().has_point(point): return "back"
		for i in range(GunCatalog.all().size()):
			if gun_rect(i).has_point(point): return "gun_%d" % i
		# One panel that steps to the next survivor, which is what C does.
		if character_panel_rect().has_point(point): return "character"
		for i in range(Balance.DANGER_LEVELS):
			if danger_rect(i).has_point(point): return "danger_%d" % i
	elif game.state == "controls":
		if controls_back_rect().has_point(point): return "back"
	elif game.state == "settings" or game.state == "settings_pause":
		# Taken straight from menu_items so the clickable rows and the keyboard
		# rows can never drift apart -- they did, the moment a row was added.
		var rows := game.menu_items()
		for i in range(rows.size()):
			if settings_row_rect(i).has_point(point): return rows[i]
	elif game.state == "paused":
		var rows := game.menu_items()
		for i in range(rows.size()):
			if pause_row_rect(i).has_point(point): return rows[i]
	elif game.state == "confirm_quit":
		var rows := game.menu_items()
		for i in range(rows.size()):
			if confirm_row_rect(i).has_point(point): return rows[i]
	elif game.state == "lobby":
		# Only seat 0 has a mouse, so only seat 0's row is clickable.
		if bool(game.lobby.joined[0]):
			var picks := game.lobby.options()
			for i in range(picks.size()):
				if lobby_chip_rect(i, picks.size()).has_point(point): return "pick_%d" % int(picks[i])
	elif game.state == "level_up":
		if game.session.seat(0) == null: return ""
		for i in range(game.session.seat(0).upgrades.size()):
			if upgrade_rect(i, 0).has_point(point): return "upgrade_%d" % i
	elif game.state == "shop":
		for i in range(SHOP_CARDS):
			# Tested first: the chip sits inside the card, and the card buys.
			var board := game.session.seat(0).shop
			if card_lock_rect(i).has_point(point) and i < board.offers.size() and not board.offers[i].is_empty():
				return "lock_%d" % i
			if card_rect(i).has_point(point): return "buy_%d" % i
		for i in range(game.session.seat(0).weapons.size()):
			# Tested first: the chip sits inside the slot, and the slot sells.
			if game.session.can_combine(i, 0) and slot_combine_rect(i).has_point(point):
				return "combine_%d" % i
			if slot_rect(i).has_point(point): return "sell_%d" % i
		if reroll_rect().has_point(point): return "reroll"
		if go_rect().has_point(point): return "go"
	return ""

# --- input prompts ------------------------------------------------------------
#
# Every screen names its controls through these, so the labels follow whichever
# device is in the player's hands. `verb` picks the pad button (Cross confirms,
# Circle backs out); `key` is what the same verb is called on the keyboard,
# which differs per screen -- the same verb is R in the shop and Q in a fight.

const BADGE := 15.0
const HINT_GAP := 26.0

func on_pad() -> bool:
	return game.input_device == "pad"

# A PlayStation face button is a shape, not a letter, and neither bundled font
# has a glyph for one -- so they are drawn. An Xbox pad puts its letter in the
# same badge, in the same slot colour, so confirm stays blue and back stays red
# whichever pad is plugged in.
func draw_pad_badge(centre: Vector2, glyph: String) -> void:
	var tint := Gamepad.color(glyph)
	draw_circle(centre, BADGE, Color(0.07, 0.10, 0.19, 0.95))
	draw_arc(centre, BADGE, 0.0, TAU, 24, tint, 2.0)
	var r := BADGE * 0.46
	match glyph:
		"cross":
			draw_line(centre + Vector2(-r, -r), centre + Vector2(r, r), tint, 2.4)
			draw_line(centre + Vector2(-r, r), centre + Vector2(r, -r), tint, 2.4)
		"circle":
			draw_arc(centre, r, 0.0, TAU, 20, tint, 2.4)
		"square":
			draw_rect(Rect2(centre - Vector2(r, r), Vector2(r, r) * 2.0), tint, false, 2.4)
		"triangle":
			var top := centre + Vector2(0.0, -r * 1.1)
			var left := centre + Vector2(-r, r * 0.7)
			var right := centre + Vector2(r, r * 0.7)
			draw_polyline(PackedVector2Array([top, right, left, top]), tint, 2.4)
		"dpad":
			# Filled, not outlined: two outlined bars cross into a four-square
			# grid that reads as a crosshair rather than a d-pad.
			var arm := r * 0.40
			draw_rect(Rect2(centre.x - arm, centre.y - r, arm * 2.0, r * 2.0), tint, true)
			draw_rect(Rect2(centre.x - r, centre.y - arm, r * 2.0, arm * 2.0), tint, true)
		"options":
			for i in range(3):
				var y := centre.y - 4.0 + float(i) * 4.0
				draw_line(Vector2(centre.x - r, y), Vector2(centre.x + r, y), tint, 1.8)
		_:
			# A shoulder reads "R1" or "RB", which does not fit at the face-button
			# size.
			text_centered(centre.x, centre.y + 5.0, glyph, 16 if glyph.length() < 2 else 12, tint)

func draw_key_cap(rect: Rect2, key: String) -> void:
	draw_panel(rect, Color(0.09, 0.13, 0.23, 0.95), Color("6d84b4"), 1.5)
	text_centered(rect.get_center().x, rect.get_center().y + 6.0, key, 15, Color("dce7ff"))

func badge_width(key: String) -> float:
	if on_pad(): return BADGE * 2.0
	return maxf(BADGE * 2.0, text_width(key, 15) + 18.0)

func hint_width(verb: String, key: String, label: String, size: int) -> float:
	return badge_width(key) + 10.0 + text_width(label, size)

# Draws one prompt with its badge left-aligned at `at`, vertically centred on it.
func draw_hint(at: Vector2, verb: String, key: String, label: String, size: int) -> void:
	var width := badge_width(key)
	if on_pad():
		# "nav" is the only verb that is a direction rather than a button, so
		# it draws the d-pad instead of asking Gamepad for a face glyph.
		var glyph := "dpad" if verb == "nav" else Gamepad.glyph(pad_button(verb))
		draw_pad_badge(Vector2(at.x + width * 0.5, at.y), glyph)
	else: draw_key_cap(Rect2(at.x, at.y - BADGE, width, BADGE * 2.0), key)
	text_at(Vector2(at.x + width + 10.0, at.y + size * 0.36), label, size, Color("a9bbde"))

func hints_width(hints: Array, size: int) -> float:
	var total := 0.0
	for hint in hints:
		var triple: Array = hint
		total += hint_width(String(triple[0]), String(triple[1]), String(triple[2]), size) + HINT_GAP
	return maxf(0.0, total - HINT_GAP)

# `hints` is a list of [verb, key, label] triples, centred as one row.
func draw_hint_row(centre_x: float, y: float, hints: Array, size: int = 16) -> void:
	var x := centre_x - hints_width(hints, size) * 0.5
	for hint in hints:
		var triple: Array = hint
		draw_hint(Vector2(x, y), String(triple[0]), String(triple[1]), String(triple[2]), size)
		x += hint_width(String(triple[0]), String(triple[1]), String(triple[2]), size) + HINT_GAP

func pad_button(verb: String) -> int:
	match verb:
		"back": return Gamepad.CIRCLE
		"alt": return Gamepad.SQUARE
		"special": return Gamepad.TRIANGLE
		"pause": return Gamepad.OPTIONS
		"ready": return Gamepad.R1
	return Gamepad.CROSS

# What "this one is selected" looks like everywhere. A slightly lighter fill and
# a 3px border was not enough to find on a screen of four bright cards, which is
# the complaint this answers: a bright ring sitting *outside* the panel, plus
# corner ticks, so focus reads from the shape and not only from a colour.
func draw_focus_ring(rect: Rect2, accent: Color) -> void:
	var glow := Rect2(rect.position - Vector2(7, 7), rect.size + Vector2(14, 14))
	draw_rect(glow, Color(accent.r, accent.g, accent.b, 0.16), true)
	draw_rect(glow, accent, false, 3.0)
	var arm: float = minf(22.0, minf(rect.size.x, rect.size.y) * 0.28)
	for corner in [[glow.position, Vector2(1, 1)], [Vector2(glow.end.x, glow.position.y), Vector2(-1, 1)],
			[Vector2(glow.position.x, glow.end.y), Vector2(1, -1)], [glow.end, Vector2(-1, -1)]]:
		var at: Vector2 = corner[0]
		var dir: Vector2 = corner[1]
		draw_line(at, at + Vector2(arm * dir.x, 0.0), accent, 5.0)
		draw_line(at, at + Vector2(0.0, arm * dir.y), accent, 5.0)

func draw_panel(rect: Rect2, fill: Color, edge: Color, width: float = 2.0) -> void:
	draw_rect(rect, fill, true)
	draw_rect(rect, edge, false, width)

func fill_screen(color: Color) -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), color)

# --- title and armory --------------------------------------------------------

const TITLE_LABELS := {
	"play": "PLAY", "coop": "CO-OP  (2 PLAYERS)", "armory": "ARMORY",
	"settings": "SETTINGS", "awards": "ACHIEVEMENTS", "quit": "QUIT GAME",
}
const TITLE_COLORS := {
	"play": Color("69f4d4"), "coop": Color("ffcf77"), "armory": Color("bf8cff"),
	"settings": Color("82b7ff"), "awards": Color("ffcf77"), "quit": Color("ff718b"),
}

func draw_title() -> void:
	draw_menu_background()
	heading(SCREEN.x * 0.5, 246, "RIFTBOUND", 68, Color("e8efff"))
	heading(SCREEN.x * 0.5, 322, "SURVIVORS", 68, Color("ffcf77"))
	text_centered(SCREEN.x * 0.5, 366, "An arcade survival run", 20, Color("aabce1"))
	# Drawn straight off menu_items, so a new entry cannot appear in one list and
	# not the other.
	var rows := game.menu_items()
	for i in range(rows.size()):
		draw_menu_button(menu_button_rect(i), TITLE_LABELS.get(rows[i], rows[i]),
			rows[i], TITLE_COLORS.get(rows[i], Color("aabce1")))
	# Placed off the last button rather than at fixed pixels, so another menu row
	# pushes the footer down instead of landing underneath it.
	var bottom := menu_button_rect(rows.size() - 1).end.y
	text_centered(SCREEN.x * 0.5, bottom + 34.0, "COINS  %d" % game.profile.coins(), 20, Color("ffcf77"))
	draw_hint_row(SCREEN.x * 0.5, bottom + 78.0, [["nav", "ARROWS", "MOVE"], ["confirm", "ENTER", "SELECT"]])
	if not on_pad(): text_centered(SCREEN.x * 0.5, bottom + 124.0, "or click  •  P  A  S  Q", 15, Color("8ea4cb"))

# --- co-op lobby -------------------------------------------------------------

func lobby_chip_rect(index: int, count: int) -> Rect2:
	var total := LOBBY_CHIP.x * count + LOBBY_CHIP_GAP * (count - 1)
	return Rect2(Vector2(pane.position.x + (pane.size.x - total) * 0.5
		+ float(index) * (LOBBY_CHIP.x + LOBBY_CHIP_GAP), LOBBY_CHIP_TOP), LOBBY_CHIP)

func draw_lobby() -> void:
	draw_menu_background()
	var lobby := game.lobby
	heading(SCREEN.x * 0.5, 118, "CO-OP", 44, Color("ffcf77"))
	text_centered(SCREEN.x * 0.5, 164,
		"PICK A SURVIVOR EACH" if lobby.stage == "character" else "PICK A STARTING WEAPON EACH",
		20, Color("aabce1"))
	for i in range(Lobby.SEATS):
		use_pane(i)
		draw_lobby_pane(i)
	use_pane(0)
	var footer := LOBBY_BOX_TOP + LOBBY_BOX_HEIGHT + 62.0
	if not lobby.everyone_in():
		text_centered(SCREEN.x * 0.5, footer, "BOTH PLAYERS HAVE TO JOIN", 20, Color("ffcf77"))
	elif lobby.all_locked():
		text_centered(SCREEN.x * 0.5, footer, "STARTING...", 20, Color("69f4d4"))
	else:
		draw_hint_row(SCREEN.x * 0.5, footer,
			[["nav", "ARROWS", "CHOOSE"], ["confirm", "ENTER", "LOCK IN"], ["back", "ESC", "BACK"]])

func draw_lobby_pane(at_seat: int) -> void:
	var lobby := game.lobby
	var accent := Color("69f4d4") if at_seat == 0 else Color("ffcf77")
	var joined := bool(lobby.joined[at_seat])
	var box := Rect2(pane.position.x + 56.0, LOBBY_BOX_TOP, pane.size.x - 112.0, LOBBY_BOX_HEIGHT)
	draw_panel(box, Color(0.07, 0.10, 0.19, 0.92) if joined else Color(0.04, 0.06, 0.12, 0.7),
		accent if joined else Color("2b3550"), 3.0 if joined else 1.5)
	# Whatever actually took this seat, not what used to be assumed to.
	var device := String(lobby.seat_device[at_seat])
	var who := Controls.label(device) if joined else ("PRESS TO CLAIM" if at_seat == lobby.next_seat() else "WAITING")
	text_centered(box.get_center().x, box.position.y + 42.0,
		"PLAYER %d   —   %s" % [at_seat + 1, who],
		18, accent if joined else Color("54617d"))
	if not joined:
		draw_lobby_join(at_seat, box, accent)
		return
	if lobby.stage == "character": draw_lobby_character(at_seat, box)
	else: draw_lobby_weapon(at_seat, box)
	var picks := lobby.options()
	for i in range(picks.size()):
		draw_lobby_chip(i, picks, at_seat, accent)
	if bool(lobby.locked[at_seat]):
		var badge := Rect2(box.get_center().x - 110.0, box.end.y - 62.0, 220.0, 40.0)
		draw_panel(badge, Color(accent.r, accent.g, accent.b, 0.22), accent, 2.0)
		text_centered(badge.get_center().x, badge.get_center().y + 7.0, "READY", 20, accent)

# The button is drawn per seat rather than through draw_hint, because this is
# the one screen where the prompt is not about the device last touched: seat 0
# is the keyboard and seat 1 is the pad, always.
func draw_lobby_join(at_seat: int, box: Rect2, accent: Color) -> void:
	var centre := box.get_center()
	var next_up: bool = at_seat == game.lobby.next_seat()
	text_centered(centre.x, centre.y - 58.0, "HOLD TO JOIN" if next_up else "WAITING FOR A PLAYER",
		26, Color("d6e2fa") if next_up else Color("54617d"))
	if not next_up: return
	# Either device can take either seat now, so both are offered on whichever
	# seat is next. Showing only one was the screen telling the player a rule
	# that had stopped being true.
	draw_key_cap(Rect2(centre.x - 118.0, centre.y - 32.0, 92.0, 34.0), "SPACE")
	text_centered(centre.x, centre.y - 8.0, "or", 16, Color("7f8db0"))
	draw_pad_badge(Vector2(centre.x + 76.0, centre.y - 15.0), Gamepad.glyph(Gamepad.CROSS))
	var bar := Rect2(centre.x - 170.0, centre.y + 34.0, 340.0, 14.0)
	draw_rect(bar, Color("101a30"), true)
	var filled := game.lobby.hold_ratio(at_seat)
	if filled > 0.0:
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * filled, bar.size.y)), accent, true)
	draw_rect(bar, Color("3d527d"), false, 1.5)

func draw_lobby_character(at_seat: int, box: Rect2) -> void:
	var def := CharacterCatalog.get_character(int(game.lobby.character[at_seat]))
	var centre := box.get_center().x
	# Below the seat label, not through it. The art used to start at +52 with
	# the "PLAYER 1 - KEYBOARD" line at +42, so the slime sat on the words --
	# invisible until the label became something worth reading.
	draw_character_art(Vector2(centre, box.position.y + 104.0), def, 96.0)
	heading(centre, box.position.y + 172.0, String(def.name), 34, def.color)
	text_centered(centre, box.position.y + 210.0, String(def.description), 17, Color("d1dcf5"))
	text_centered(centre, box.position.y + 246.0, "HP %d   •   SPEED %d" % [int(def.hp), int(def.speed)],
		16, Color("9fb3d9"))
	var kinds: Array = def.get("kinds", [])
	var shape := "%d weapon slots" % int(def.get("slots", 6))
	if not kinds.is_empty(): shape += "   •   %s weapons only" % String(kinds[0]).to_upper()
	text_centered(centre, box.position.y + 280.0, shape, 15, Color("ffcf77"))
	var perks := ItemCatalog.describe(def)
	draw_wrapped(Vector2(box.position.x + 44.0, box.position.y + 322.0),
		perks if perks != "" else "No stat modifiers", 16, Color("a9bbde"), box.size.x - 88.0)

# Held for the life of the UI, and not merely as an optimisation.
#
# A texture loaded into a local inside _draw() is freed the moment the function
# returns -- nothing else references it -- and the draw command that was queued
# against it is left pointing at a released RID, which the renderer fills as a
# solid white quad. The character art rendered as white boxes for exactly that
# reason, while player.png in the same call drew correctly, because the Player
# scene holds a reference to that one and keeps it alive.
var art_cache := {}

func character_art(def: Dictionary) -> Texture2D:
	var id := String(def.get("texture", "player"))
	if art_cache.has(id): return art_cache[id]
	var path := "res://assets/sprites/%s.png" % id
	var art: Texture2D = null
	if ResourceLoader.exists(path): art = load(path) as Texture2D
	art_cache[id] = art
	return art

# A character you cannot see is a row of statistics. Drawn from the catalog id
# so a new character needs no second place to register its art.
func draw_character_art(centre: Vector2, def: Dictionary, height: float) -> void:
	var art := character_art(def)
	if art == null: return
	var size := Vector2(height, height)
	draw_texture_rect(art, Rect2(centre - size * 0.5, size), false)

func draw_lobby_weapon(at_seat: int, box: Rect2) -> void:
	var def := GunCatalog.get_gun(int(game.lobby.gun[at_seat]))
	var id := String(def.weapon)
	var weapon := WeaponCatalog.get_weapon(id)
	var centre := box.get_center().x
	Icons.weapon(self, id, Vector2(centre, box.position.y + 116.0), 38.0, def.color)
	heading(centre, box.position.y + 196.0, String(def.name), 32, def.color)
	text_centered(centre, box.position.y + 234.0, String(def.description), 17, Color("d1dcf5"))
	var dps: float = WeaponCatalog.damage_at(id, 1) * float(weapon.shots) / WeaponCatalog.cooldown_at(id, 1)
	text_centered(centre, box.position.y + 274.0, "%.0f dps   •   %d range   •   %s" % [
		dps, int(weapon.range), String(weapon.kind).to_upper()], 16, Color("9fb3d9"))
	# No run exists yet, so there is nothing held for a class chip to light up --
	# they are drawn here purely to say what the weapon counts toward.
	draw_class_chips(Vector2(centre - 60.0, box.position.y + 314.0), weapon.get("classes", []),
		game.session, null)

func draw_lobby_chip(index: int, picks: Array, at_seat: int, accent: Color) -> void:
	var lobby := game.lobby
	var value := int(picks[index])
	var rect := lobby_chip_rect(index, picks.size())
	var chosen := lobby.selection(at_seat) == value
	var tint: Color = CharacterCatalog.get_character(value).color if lobby.stage == "character" else GunCatalog.get_gun(value).color
	draw_panel(rect, Color(tint.r, tint.g, tint.b, 0.20) if chosen else Color("141c31"),
		accent if chosen else Color(tint.r, tint.g, tint.b, 0.45), 3.0 if chosen else 1.0)
	var label: String = String(CharacterCatalog.get_character(value).name) if lobby.stage == "character" else String(GunCatalog.get_gun(value).name)
	text_centered(rect.get_center().x, rect.get_center().y + 5.0, label, 12,
		Color("ffffff") if chosen else Color("8ea4cb"))

func draw_armory() -> void:
	draw_menu_background()
	draw_menu_button(armory_back_rect(), "BACK", "back", Color("aabce1"))
	heading(SCREEN.x * 0.5, 150, "ARMORY", 44, Color("e8efff"))
	text_centered(SCREEN.x * 0.5, 196, "Choose a starting weapon and survivor", 18, Color("aabce1"))
	var guns := GunCatalog.all()
	for i in range(guns.size()):
		var box := gun_rect(i)
		var selected := i == game.selected_gun
		# The armory became clickable and said nothing about what the pointer was
		# over, which is worse than not being clickable: the screen looks inert
		# right up until something happens. Same ring as everywhere else.
		if is_focused("gun_%d" % i): draw_focus_ring(box, Color("ffe9a8"))
		draw_panel(box, Color("2f3f63") if is_focused("gun_%d" % i) else (Color("263452") if selected else Color("151d35")),
			guns[i].color, 4.0 if selected else 2.0)
		text_at(box.position + Vector2(26,52), "%d  %s" % [i+1, guns[i].name], 20, guns[i].color)
		text_at(box.position + Vector2(26,96), guns[i].description, 16, Color("d1dcf5"))
		var unlocked := game.profile.is_gun_unlocked(i)
		text_at(box.position + Vector2(26,158), "EQUIPPED" if selected and unlocked else ("UNLOCK  %d COINS" % guns[i].cost if not unlocked else "Press %d" % (i+1)), 16, Color("ffcf77"))
	var character := CharacterCatalog.get_character(game.selected_character)
	var panel := character_panel_rect()
	if is_focused("character"): draw_focus_ring(panel, Color("ffe9a8"))
	draw_panel(panel, Color("22314f") if is_focused("character") else Color("182441"), character.color)
	draw_character_art(Vector2(panel.position.x + 78.0, panel.get_center().y), character, 104.0)
	text_at(panel.position + Vector2(150, 52), "C  %s" % character.name, 24, character.color)
	if is_focused("character"):
		text_right(panel.end.x - 40.0, panel.position.y + 52.0, "CLICK FOR NEXT", 14, Color("ffe9a8"))
	text_at(panel.position + Vector2(150, 90), "%s  •  HP %d  •  SPEED %d" % [character.description, character.hp, character.speed], 17, Color("d1dcf5"))
	var perks := ItemCatalog.describe(character)
	var kinds: Array = character.get("kinds", [])
	var shape := "%d weapon slots" % int(character.get("slots", 6))
	if not kinds.is_empty(): shape += "  •  %s weapons only" % String(kinds[0]).to_upper()
	text_at(panel.position + Vector2(150, 122), shape, 15, Color("ffcf77"))
	text_at(panel.position + Vector2(430, 122), perks if perks != "" else "No stat modifiers", 15, Color("9fb3d9"))
	# What to go and do, rather than a price: characters are earned now.
	var earned := game.profile.is_character_unlocked(game.selected_character)
	var opener := AchievementCatalog.unlocker_for(game.selected_character)
	var gate: String = "READY" if earned else ("LOCKED  —  %s" % String(opener.description) if not opener.is_empty() else "LOCKED")
	text_right(panel.end.x - 40, panel.position.y + 122, gate, 15, Color("ffcf77") if earned else Color("ff9aa8"))
	text_centered(SCREEN.x * 0.5, 762, "DANGER  —  arrows or click", 15, Color("8ea4cb"))
	for i in range(Balance.DANGER_LEVELS):
		var chip := danger_rect(i)
		var unlocked := i <= game.profile.max_danger()
		var picked := i == game.danger
		var accent := Color("ffcf77").lerp(Color("ff718b"), float(i) / float(Balance.DANGER_LEVELS - 1))
		var over := is_focused("danger_%d" % i)
		if over: draw_focus_ring(chip, Color("ffe9a8"))
		draw_panel(chip, Color("2f3f63") if over else (Color("263452") if picked else Color("141c31")),
			accent if unlocked else Color("2b3550"), 3.0 if picked else 1.5)
		text_centered(chip.get_center().x, chip.get_center().y + 8, str(i) if unlocked else "-", 22, accent if unlocked else Color("46526e"))
	text_centered(SCREEN.x * 0.5, 872, "Press PLAY from the main menu to begin", 18, Color("aabce1"))
	draw_hint_row(SCREEN.x * 0.5, 934, [["nav", "ARROWS", "DANGER / SURVIVOR"],
		["alt", "C", "NEXT WEAPON"], ["back", "ESC", "BACK"]])

# What the profile has done, and what is still out there. Read-only: a record,
# not a screen you can act on.
func draw_awards() -> void:
	draw_menu_background()
	heading(SCREEN.x * 0.5, 130, "ACHIEVEMENTS", 42, Color("ffcf77"))
	var all := AchievementCatalog.all()
	var done := 0
	for def in all:
		if game.profile.has_achievement(String(def.id)): done += 1
	text_centered(SCREEN.x * 0.5, 176, "%d of %d earned" % [done, all.size()], 20, Color("aabce1"))
	for i in range(all.size()):
		draw_award_row(i, all[i])
	draw_hint_row(SCREEN.x * 0.5, 1006, [["back", "ESC", "BACK"]])

func award_row_rect(index: int) -> Rect2:
	var size := Vector2(880, 62)
	var total := size.x * 2.0 + 32.0
	return Rect2(Vector2((SCREEN.x - total) * 0.5 + float(index % 2) * (size.x + 32.0),
		236.0 + float(index / 2) * (size.y + 14.0)), size)

func draw_award_row(index: int, def: Dictionary) -> void:
	var rect := award_row_rect(index)
	var earned: bool = game.profile.has_achievement(String(def.id))
	var accent := Color("ffcf77") if earned else Color("46526e")
	draw_panel(rect, Color(0.10, 0.13, 0.22, 0.95) if earned else Color(0.05, 0.07, 0.12, 0.8), accent, 2.0 if earned else 1.0)
	# A filled pip reads as done at a glance, which is what a list like this is for.
	var pip := Vector2(rect.position.x + 30.0, rect.get_center().y)
	draw_circle(pip, 9.0, Color(accent.r, accent.g, accent.b, 0.22))
	if earned: draw_circle(pip, 5.0, accent)
	else: draw_arc(pip, 5.0, 0.0, TAU, 14, accent, 1.5)
	text_at(Vector2(rect.position.x + 54.0, rect.get_center().y - 2.0), String(def.name), 18,
		Color("f1f5ff") if earned else Color("7f8db0"))
	text_at(Vector2(rect.position.x + 54.0, rect.get_center().y + 20.0), String(def.description), 14, Color("9fb3d9"))
	var opens := int(def.unlocks)
	if opens >= 0:
		text_right(rect.end.x - 22.0, rect.get_center().y + 6.0,
			"UNLOCKS  %s" % String(CharacterCatalog.get_character(opens).name), 14,
			Color("69f4d4") if earned else Color("54617d"))

func draw_menu_background() -> void:
	fill_screen(Color("0b1020"))
	for i in range(60):
		var star := Vector2(float((i * 197) % int(SCREEN.x)), float((i * 131) % int(SCREEN.y)))
		draw_circle(star, 1.0 + float(i % 3), Color(0.35,0.70,1.0,0.22))
	draw_arc(Vector2(SCREEN.x * 0.5, 300), 150.0, 0.2, TAU - 0.2, 32, Color(0.62,0.42,1.0,0.25), 10.0)
	draw_arc(Vector2(SCREEN.x * 0.5, 300), 108.0, 0.0, TAU, 28, Color(0.27,0.88,0.94,0.16), 5.0)

func draw_menu_button(rect: Rect2, label: String, action: String, color: Color, at_seat: int = 0) -> void:
	var hovered := is_focused(action, at_seat)
	var pulse := (sin(Time.get_ticks_msec() * 0.008) + 1.0) * 0.5
	var shown_rect := rect.grow(4.0 + pulse * 2.0) if hovered else rect
	if hovered: draw_focus_ring(shown_rect, Color("ffe9a8"))
	draw_panel(shown_rect, Color(color.r, color.g, color.b, 0.16) if hovered else Color("17233e"), color, 3.0 if hovered else 1.5)
	text_centered(shown_rect.get_center().x, shown_rect.get_center().y + 8.0, label, 21, Color("ffffff") if hovered else Color("d6e2fa"))

# --- combat HUD --------------------------------------------------------------

func draw_hud() -> void:
	var s := game.session
	var right := SCREEN.x - MARGIN
	# Deliberately sparse. The title belongs on the title screen, and the strip
	# of weapon chips that used to run across the top said nothing the rack
	# orbiting the player does not already say -- it was six coloured boxes of
	# text between the player and the thing they have to watch.
	if not game.coop:
		text_at(Vector2(MARGIN, 56), "%d" % s.materials, 26, Color("8cffd1"))
		text_at(Vector2(MARGIN + text_width("%d" % s.materials, 26) + 10.0, 56), "MATERIALS", 14, Color("4f7d6d"))
	var round_status := "CLEAR HOSTILES" if s.round_phase == "cleanup" else ("SHOP" if s.round_phase == "shop" else "FIGHT")
	heading_right(right, 50, "WAVE %d / %d  %02d" % [s.round_number, Balance.FINAL_WAVE, int(ceil(s.round_time_left))], 28, Color("ffd166"))
	text_right(right, 80, "%s  •  KILLS %d" % [round_status, s.kills], 16, Color("ffcf77") if s.round_phase != "combat" else Color("b6c6e8"))
	# The two abilities are the only controls the fight needs named, and they
	# are the ones that differ most between a keyboard and a pad.
	var abilities: Array = [
		["alt", "SHIFT", "DASH  %s" % ("READY" if s.dash_cooldown <= 0.0 else "%.1fs" % s.dash_cooldown)],
		["special", "E", "NOVA  %s" % ("READY" if s.nova_cooldown <= 0.0 else "%.1fs" % s.nova_cooldown)],
	]
	# Centred so the row ends flush with the right margin, and lifted clear of
	# the arena border at Arena.BOUNDS.y -- a badge is taller than the line of
	# text it replaced, and at 112 the border cut straight through it.
	if not game.coop:
		draw_hint_row(right - hints_width(abilities, 15) * 0.5, 100, abilities, 15)
	var bar_y := SCREEN.y - 34.0
	if game.coop:
		draw_coop_vitals(s, bar_y)
	else:
		draw_rect(Rect2(MARGIN, bar_y, 520, 14), Color("3a2844"))
		draw_rect(Rect2(MARGIN, bar_y, 520 * s.player_hp / s.player_max_hp, 14), Color("ff5f7a"))
		text_at(Vector2(MARGIN, bar_y - 10), "HP %d / %d" % [s.player_hp, s.player_max_hp], 16, Color("f2d8e0"))
		draw_rect(Rect2(right - 520, bar_y, 520, 14), Color("1f3e4c"))
		draw_rect(Rect2(right - 520, bar_y, 520 * float(s.xp) / maxf(1.0, float(s.xp_to_next)), 14), Color("60e8d2"))
		text_at(Vector2(right - 520, bar_y - 10), "LEVEL %d  •  XP %d / %d" % [s.level, s.xp, s.xp_to_next], 16, Color("d0fff7"))
	# The banner and the bar say the same thing, and they said it in the same
	# place. Once the bar is up it is the better of the two.
	if game.profile.setting("show_fps"):
		# Top left, under the materials, and coloured by what it says. Tucked in
		# the top right at 15px it sat on the arena border and was unreadable at
		# exactly the moment it matters, which is while the screen is busy.
		var fps := int(Engine.get_frames_per_second())
		var tint := Color("69f4d4")
		if fps < 30: tint = Color("ff718b")
		elif fps < 55: tint = Color("ffd166")
		text_at(Vector2(MARGIN, 96), "%d" % fps, 24, tint)
		text_at(Vector2(MARGIN + text_width("%d" % fps, 24) + 10.0, 96), "FPS", 14, Color("5c6b8c"))
	if s.boss_alive(): draw_boss_bar(s.boss)
	elif s.round_number % 5 == 0 and s.round_phase == "combat" and s.round_time_left > s.round_length - 3.0:
		text_centered(SCREEN.x * 0.5, 170, "BOSS RIFT OPEN", 24, Color("ffcf77"))

# A boss carries the same 4px bar over its head as a husk does, which said
# nothing about a fight lasting half a minute. This is the whole width of the
# screen: the point of a boss is that you can see how far in you are.
func draw_boss_bar(boss: Enemy) -> void:
	var width := SCREEN.x * 0.52
	var box := Rect2(Vector2((SCREEN.x - width) * 0.5, 132.0), Vector2(width, 28.0))
	var ratio: float = clampf(boss.hp / maxf(boss.max_hp, 1.0), 0.0, 1.0)
	draw_rect(box.grow(4.0), Color(0.06, 0.03, 0.09, 0.85))
	draw_rect(box, Color("2a1230"))
	draw_rect(Rect2(box.position, Vector2(box.size.x * ratio, box.size.y)), Color("ff5d8f"))
	# A lighter cap on the leading edge, so the bar reads as draining rather
	# than as a static block that happens to be a different length.
	if ratio > 0.004:
		draw_rect(Rect2(box.position + Vector2(box.size.x * ratio - 5.0, 0.0), Vector2(5.0, box.size.y)),
			Color("ffd0e0"))
	draw_rect(box, Color("ff9ec4"), false, 2.0)
	var name: String = String(boss.definition.get("name", "BOSS"))
	text_centered(box.get_center().x, box.position.y - 9.0, name, 20, Color("ffd0e0"))
	# Inside the bar, not under it: under it lands on the boss itself, which is
	# standing directly below at the top of the arena.
	text_centered(box.get_center().x, box.get_center().y + 6.0,
		"%d / %d" % [int(round(boss.hp)), int(round(boss.max_hp))], 15, Color(0.16, 0.05, 0.12))

# Two players, two sets of vitals. Seat 0 reads from the left edge and seat 1
# from the right -- the same halves they get in the shop, so which corner is
# yours never has to be relearned.
func draw_coop_vitals(s: GameSession, bar_y: float) -> void:
	for i in range(s.seats()):
		var who := s.seat(i)
		var width := 520.0
		var left: float = MARGIN if i == 0 else SCREEN.x - MARGIN - width
		var tint := Color("ff5f7a") if i == 0 else Color("ffb15f")
		var hp: float = who.player.hp if is_instance_valid(who.player) else 0.0
		var top: float = who.player.max_hp if is_instance_valid(who.player) else 1.0
		draw_rect(Rect2(left, bar_y, width, 14), Color("3a2844"))
		if not who.downed:
			draw_rect(Rect2(left, bar_y, width * clampf(hp / maxf(top, 1.0), 0.0, 1.0), 14), tint)
		var label := "DOWN  —  back next wave" if who.downed else "HP %d / %d" % [hp, top]
		text_at(Vector2(left, bar_y - 10), "P%d   %s" % [i + 1, label], 16,
			Color("ff9aa8") if who.downed else Color("f2d8e0"))
		draw_rect(Rect2(left, bar_y - 44, width, 8), Color("1f3e4c"))
		draw_rect(Rect2(left, bar_y - 44, width * float(who.xp) / maxf(1.0, float(who.xp_to_next)), 8), Color("60e8d2"))
		var dash: float = who.player.dash_cooldown if is_instance_valid(who.player) else 0.0
		text_at(Vector2(left, bar_y - 52), "LVL %d   •   MATERIALS %d   •   DASH %s   •   NOVA %s" % [
			who.level, who.materials,
			"READY" if dash <= 0.0 else "%.0fs" % dash,
			"READY" if who.nova_cooldown <= 0.0 else "%.0fs" % who.nova_cooldown], 14, Color("d0fff7"))

# --- shop --------------------------------------------------------------------

func draw_shop() -> void:
	var s := game.session
	fill_screen(Color(0.02,0.03,0.08,0.94))
	for i in range(s.seats()):
		use_pane(i)
		draw_shop_pane(s, s.seat(i), i)
	use_pane(0)
	if not game.coop: return
	# A hairline between the boards, so it reads as two shops rather than one
	# very wide one.
	draw_rect(Rect2(SCREEN.x * 0.5 - 1.0, 90.0, 2.0, SCREEN.y - 180.0), Color(0.35, 0.45, 0.70, 0.35))

func draw_shop_pane(s: GameSession, who: Survivor, at_seat: int) -> void:
	var centre := pane.get_center().x
	var left := pane.position.x + MARGIN
	var title := "P%d  —  WAVE %d CLEARED" % [at_seat + 1, s.round_number] if game.coop else "WAVE %d CLEARED" % s.round_number
	heading(centre, 108 if game.coop else 120, title, 28 if game.coop else 34, Color("69f4d4"))
	if not game.coop:
		text_centered(centre, 158, "Spend materials, then head back in", 18, Color("aabce1"))
	text_at(Vector2(left, 148 if game.coop else 130), "MATERIALS  %d" % who.materials, 24, Color("8cffd1"))
	for i in range(SHOP_CARDS):
		draw_offer_card(i, s, who, at_seat)
	var reroll_cost: int = who.shop.reroll_cost()
	draw_menu_button(reroll_rect(), "REROLL  %d" % reroll_cost, "reroll",
		Color("82b7ff") if who.materials >= reroll_cost else Color("54617d"), at_seat)
	# Both seats have to press it, so the button says which of them already has.
	draw_menu_button(go_rect(), "WAITING  ..." if who.ready else "NEXT WAVE", "go",
		Color("54617d") if who.ready else Color("69f4d4"), at_seat)
	# Sits in the gap between the two buttons, which is empty on every layout
	# because they are pinned to the outer edges of the offer block.
	var hints: Array = [["nav", "ARROWS", "MOVE"], ["confirm", "ENTER", "SELECT"],
		["alt", "L", "PIN"], ["special", "R", "REROLL"], ["ready", "SPACE", "NEXT WAVE"]]
	if not game.coop:
		draw_hint_row(centre, button_top() + 34.0, hints, 15)
	elif at_seat == 0:
		# Half a pane leaves no room between REROLL and NEXT WAVE, so the
		# prompts move to the top centre and are drawn once for both boards.
		draw_hint_row(SCREEN.x * 0.5, 44.0, hints, 15)
	draw_class_bonuses(s, who)
	draw_weapon_slots(s, who, at_seat)
	draw_owned_items(who)
	draw_stat_strip(who)

func draw_offer_card(index: int, s: GameSession, who: Survivor, at_seat: int) -> void:
	var rect := card_rect(index)
	var offer: Dictionary = who.shop.offers[index] if index < who.shop.offers.size() else {}
	if offer.is_empty():
		draw_panel(rect, Color(0.06,0.08,0.15,0.7), Color("2b3550"), 1.5)
		text_centered(rect.get_center().x, rect.get_center().y, "SOLD", 22, Color("54617d"))
		return
	var affordable: bool = who.materials >= int(offer.price)
	var hovered := is_focused("buy_%d" % index, at_seat)
	var pinned: bool = who.shop.is_locked(index)
	var edge: Color = offer.color if affordable else Color("54617d")
	if pinned: edge = Color("ffe09b")
	if hovered: draw_focus_ring(rect, Color("ffe9a8"))
	draw_panel(rect, Color(0.16,0.21,0.36,0.98) if hovered else Color("151d35"), edge, 3.0 if (hovered or pinned) else 2.0)
	text_at(rect.position + Vector2(20, 38), "%s  (%d)" % ["WEAPON" if offer.kind == "weapon" else "ITEM", index + 1], 13, Color("8ea4cb"))
	if offer.kind == "weapon": Icons.weapon(self, String(offer.id), rect.position + Vector2(rect.size.x - 52, 56), 30.0, edge)
	else: Icons.item(self, String(offer.id), rect.position + Vector2(rect.size.x - 52, 56), 26.0, edge)
	text_at(rect.position + Vector2(20, 74), String(offer.name), 21, edge)
	draw_wrapped(rect.position + Vector2(20, 112), String(offer.text), 15, Color("c8d3ed"), rect.size.x - 40.0)
	if offer.kind == "weapon":
		var def: Dictionary = WeaponCatalog.get_weapon(String(offer.id))
		var dps: float = WeaponCatalog.damage_at(String(offer.id), int(offer.tier)) * float(def.shots) / WeaponCatalog.cooldown_at(String(offer.id), int(offer.tier))
		draw_class_chips(rect.position + Vector2(20, 156), def.get("classes", []), s, who)
		text_at(rect.position + Vector2(20, 192), "%.0f dps  •  %d range  •  %s" % [dps, int(def.range), String(def.kind).to_upper()], 14, Color("9fb3d9"))
	text_at(rect.position + Vector2(20, 226), "%d MATERIALS" % int(offer.price), 18, Color("8cffd1") if affordable else Color("ff718b"))
	draw_lock_chip(card_lock_rect(index), pinned, is_focused("lock_%d" % index, at_seat))

# A chip per weapon class, brightened when that class is already contributing
# a set bonus, so the shop shows what a purchase would build toward.
func draw_class_chips(at: Vector2, classes: Array, s: GameSession, who: Survivor) -> void:
	var counts := s.class_counts(who)
	var x := at.x
	for id in classes:
		var spec: Dictionary = WeaponCatalog.CLASSES[id]
		var held := int(counts.get(id, 0))
		var live := s.class_steps(held) > 0
		var label: String = "%s %d" % [spec.name, held] if held > 0 else String(spec.name)
		var width := text_width(label, 12) + 16.0
		var tint: Color = spec.color
		draw_panel(Rect2(x, at.y - 14, width, 20), Color(tint.r, tint.g, tint.b, 0.22 if live else 0.08), tint if live else Color(tint.r, tint.g, tint.b, 0.4), 1.0)
		text_at(Vector2(x + 8, at.y + 1), label, 12, tint if live else Color("7f8db0"))
		x += width + 6.0

func draw_class_bonuses(s: GameSession, who: Survivor) -> void:
	var counts := s.class_counts(who)
	var live: Array = counts.keys().filter(func(id) -> bool: return s.class_steps(int(counts[id])) > 0)
	var left := slot_rect(0).position.x
	var y := slot_rect(0).position.y - (34.0 if game.coop else 46.0)
	text_at(Vector2(left, y), "SET BONUSES", 15, Color("8ea4cb"))
	if live.is_empty():
		text_at(Vector2(left + 130, y), "hold two weapons of a class to start one", 14, Color("54617d"))
		return
	var x := left + 130.0
	for id in live:
		var spec: Dictionary = WeaponCatalog.CLASSES[id]
		var steps := s.class_steps(int(counts[id]))
		var label: String = "%s x%d  %s" % [spec.name, int(counts[id]), scaled_bonus(spec, steps)]
		var width := text_width(label, 13) + 18.0
		draw_panel(Rect2(x, y - 15, width, 22), Color(spec.color.r, spec.color.g, spec.color.b, 0.16), spec.color, 1.0)
		text_at(Vector2(x + 9, y + 1), label, 13, spec.color)
		x += width + 8.0

# The class text is written per step, so it is multiplied out for display.
func scaled_bonus(spec: Dictionary, steps: int) -> String:
	var parts: Array[String] = []
	for stat in spec.per_step:
		var amount: float = float(spec.per_step[stat]) * float(steps)
		var suffix := "%" if String(stat) in Stats.PERCENT else ""
		parts.append("%s%s%s %s" % ["+" if amount > 0.0 else "", ItemCatalog._trim(amount), suffix, Stats.LABELS.get(String(stat), stat)])
	return ", ".join(parts)

func draw_weapon_slots(s: GameSession, who: Survivor, at_seat: int) -> void:
	var caption := "WEAPONS  %d / %d" % [who.weapons.size(), slot_count()]
	if not game.coop: caption += "  —  click to sell, or COMBINE two of a kind"
	text_at(Vector2(slot_rect(0).position.x, slot_rect(0).position.y - 14.0), caption, 15, Color("8ea4cb"))
	for i in range(slot_count()):
		var rect := slot_rect(i)
		if i >= who.weapons.size():
			draw_panel(rect, Color(0.06,0.08,0.15,0.6), Color("2b3550"), 1.0)
			text_centered(rect.get_center().x, rect.get_center().y + 6, "EMPTY", 14, Color("46526e"))
			continue
		var weapon: Weapon = who.weapons[i]
		var selling := is_focused("sell_%d" % i, at_seat)
		var merging := is_focused("combine_%d" % i, at_seat)
		if selling or merging: draw_focus_ring(rect, Color("ffe9a8"))
		draw_panel(rect, Color(0.20,0.15,0.20,0.98) if selling else Color("1a2440"), weapon.def().color, 2.0 if selling or merging else 1.5)
		Icons.weapon(self, weapon.id, rect.position + Vector2(26, 31), 17.0, weapon.def().color)
		text_at(rect.position + Vector2(50, 26), weapon.display_name(), 15, weapon.def().color)
		# The line under the name says what the focused action would actually do.
		var note := "%.0f dmg" % WeaponCatalog.damage_at(weapon.id, weapon.tier)
		var tint := Color("9fb3d9")
		if merging:
			note = "combine → %s" % WeaponCatalog.tier_label(weapon.tier + 1)
			tint = Color("ffe09b")
		elif selling and who.weapons.size() > 1:
			note = "sell +%d" % weapon.sell_value()
			tint = Color("ff9aa8")
		text_at(rect.position + Vector2(50, 50), note, 13, tint)
		if s.can_combine(i, at_seat): draw_combine_chip(slot_combine_rect(i), merging)

# Drawn on any weapon that has a twin in the rack rather than only on hover:
# a duplicate is an opportunity, and it should be visible before you go looking.
# A pinned offer survives a reroll. Drawn on every card rather than on hover,
# because a reroll you cannot see the cost of is a gamble either way.
func draw_lock_chip(rect: Rect2, pinned: bool, focused: bool) -> void:
	var accent := Color("ffe09b") if pinned else Color("6d84b4")
	draw_panel(rect, Color(accent.r, accent.g, accent.b, 0.22) if (pinned or focused) else Color(0.08, 0.11, 0.20, 0.9),
		accent, 2.0 if focused else 1.0)
	draw_padlock(Vector2(rect.position.x + 17.0, rect.get_center().y), 13.0, pinned, accent)
	text_at(Vector2(rect.position.x + 30.0, rect.get_center().y + 5.0), "KEEP" if pinned else "PIN", 12, accent)

# Neither bundled font has a padlock, so it is drawn: a shut one sits closed on
# the body, an open one is lifted and tilted off it.
func draw_padlock(centre: Vector2, size: float, shut: bool, tint: Color) -> void:
	var body := Rect2(centre.x - size * 0.42, centre.y - size * 0.08, size * 0.84, size * 0.56)
	draw_rect(body, tint, shut)
	if not shut: draw_rect(body, tint, false, 1.3)
	var shackle := Vector2(centre.x + (0.0 if shut else size * 0.22), body.position.y - (0.0 if shut else size * 0.14))
	draw_arc(shackle, size * 0.27, PI, TAU, 12, tint, 1.6)

func draw_combine_chip(rect: Rect2, focused: bool) -> void:
	var accent := Color("ffe09b")
	draw_panel(rect, Color(accent.r, accent.g, accent.b, 0.22) if focused else Color(0.10, 0.14, 0.25, 0.95), accent, 2.0 if focused else 1.0)
	text_centered(rect.get_center().x, rect.get_center().y + 5.0, "COMBINE", 12, accent)

func draw_owned_items(who: Survivor) -> void:
	var top := slots_bottom() + (34.0 if game.coop else 40.0)
	var left := slot_rect(0).position.x
	text_at(Vector2(left, top), "ITEMS", 15, Color("8ea4cb"))
	if who.items.is_empty():
		text_at(Vector2(left + 78, top), "none yet", 15, Color("54617d"))
		return
	var x := left + 84.0
	for id in who.items:
		var def := ItemCatalog.get_item(id)
		var width := text_width(String(def.name), 14) + 40.0
		if x + width > pane.end.x - MARGIN: break
		draw_panel(Rect2(x, top - 22, width, 30), Color(0.09,0.13,0.24,0.8), def.color, 1.0)
		Icons.item(self, id, Vector2(x + 16, top - 7), 11.0, def.color)
		text_at(Vector2(x + 31, top), String(def.name), 14, Color("c8d3ed"))
		x += width + 8.0

func draw_stat_strip(who: Survivor) -> void:
	var left := slot_rect(0).position.x
	var y := slots_bottom() + 62.0 if game.coop else SCREEN.y - 60.0
	var parts: Array[String] = []
	for stat in ["damage", "attack_speed", "crit_chance", "armor", "dodge", "speed", "lifesteal", "hp_regen", "harvesting", "pickup_radius"]:
		if is_zero_approx(who.stats.get_stat(stat)): continue
		parts.append("%s %s" % [Stats.LABELS[stat], who.stats.format(stat)])
	var hp: float = who.player.hp if is_instance_valid(who.player) else 0.0
	var top: float = who.player.max_hp if is_instance_valid(who.player) else 1.0
	text_at(Vector2(left, y), "HP %d/%d" % [hp, top], 15, Color("f2d8e0"))
	if not parts.is_empty():
		draw_wrapped(Vector2(left + 140, y), "  •  ".join(parts), 15, Color("9fb3d9"),
			pane.end.x - MARGIN - left - 140.0)

# Wraps on spaces against a pixel width, since draw_string has no wrapping.
func draw_wrapped(at: Vector2, text: String, size: int, color: Color, width: float) -> void:
	var line := ""
	var y := at.y
	for word in text.split(" "):
		var candidate: String = word if line == "" else line + " " + word
		if text_width(candidate, size) > width and line != "":
			text_at(Vector2(at.x, y), line, size, color)
			y += size + 6
			line = word
		else:
			line = candidate
	if line != "": text_at(Vector2(at.x, y), line, size, color)

# --- overlays ----------------------------------------------------------------

func draw_upgrades() -> void:
	fill_screen(Color(0.02,0.03,0.08,0.82))
	var s := game.session
	for i in range(s.seats()):
		use_pane(i)
		draw_upgrade_pane(s.seat(i), i)
	use_pane(0)
	if game.coop:
		draw_rect(Rect2(SCREEN.x * 0.5 - 1.0, 200.0, 2.0, 520.0), Color(0.35, 0.45, 0.70, 0.35))

func draw_upgrade_pane(who: Survivor, at_seat: int) -> void:
	var centre := pane.get_center().x
	var title := "P%d  —  RIFT EVOLUTION" % (at_seat + 1) if game.coop else "RIFT EVOLUTION"
	heading(centre, 220 if game.coop else 300, title, 30 if game.coop else 38, Color("ffe09b"))
	var choices: Array[Dictionary] = who.upgrades
	if choices.is_empty():
		# The overlay stays up while the other player is still choosing, so this
		# side has to say why it is waiting rather than sit empty.
		text_centered(centre, 262 if game.coop else 340, "no level this time  —  waiting for the other player", 18, Color("7f8db0"))
		return
	text_centered(centre, 262 if game.coop else 340, "Choose one upgrade", 20, Color("c8d3ed"))
	var rarity_colors := {"COMMON": Color("b7c5d9"), "RARE": Color("82b7ff"), "LEGENDARY": Color("ffcf77")}
	for i in range(choices.size()):
		var rect := upgrade_rect(i, at_seat)
		var edge: Color = rarity_colors[choices[i].rarity]
		var focused := is_focused("upgrade_%d" % i, at_seat)
		# The focused card grows and brightens, the same way a menu button
		# does, so a controller has something to steer.
		if focused:
			rect = rect.grow(6.0)
			draw_focus_ring(rect, Color("ffe9a8"))
		draw_panel(rect, Color(0.18, 0.24, 0.42, 0.99) if focused else Color("202b4a"), edge, 5.0 if focused else 3.0)
		text_at(rect.position + Vector2(24, 52), "%d" % (i + 1), 28, Color("ffe09b"))
		text_at(rect.position + Vector2(24, 88), String(choices[i].rarity), 14, edge)
		var granted: Array = choices[i].stats.keys()
		if not granted.is_empty():
			Icons.stat(self, String(granted[0]), rect.position + Vector2(rect.size.x - 52, 58), 28.0, edge)
		text_at(rect.position + Vector2(24, 124), String(choices[i].title), 21, Color("f1f5ff"))
		draw_wrapped(rect.position + Vector2(24, 162), UpgradeCatalog.describe(choices[i]), 16, Color("a9bbde"), rect.size.x - 48.0)
		# "Press 3" means nothing to someone holding a pad, so on a pad only the
		# focused card says anything at all.
		var prompt := "" if on_pad() else "Press %d" % (i + 1)
		text_at(rect.position + Vector2(24, 228), "TAKE" if focused else prompt, 15, Color("ffe09b"))
	var footer := upgrade_rect(choices.size() - 1, at_seat).end.y + 54.0
	draw_hint_row(pane.get_center().x, footer, [["nav", "ARROWS", "PICK"], ["confirm", "ENTER", "TAKE"]])

func draw_pause() -> void:
	fill_screen(Color(0.02,0.03,0.08,0.80))
	heading(SCREEN.x * 0.5, 380, "PAUSED", 44, Color("eaf1ff"))
	var rows := [["CONTINUE", "resume", Color("69f4d4")], ["SETTINGS", "settings", Color("82b7ff")], ["MAIN MENU", "menu", Color("ff718b")]]
	for i in range(rows.size()):
		draw_menu_button(pause_row_rect(i), rows[i][0], rows[i][1], rows[i][2])
	draw_hint_row(SCREEN.x * 0.5, pause_row_rect(rows.size() - 1).end.y + 62,
		[["nav", "ARROWS", "MOVE"], ["confirm", "ENTER", "SELECT"], ["back", "ESC", "RESUME"]])

# Leaving mid-run throws the run away: unlike dying, an abandoned run pays no
# coins at all, so it is worth one question.
func draw_confirm_quit() -> void:
	var s := game.session
	fill_screen(Color(0.02, 0.03, 0.08, 0.88))
	heading(SCREEN.x * 0.5, 386, "LEAVE THIS RUN?", 40, Color("ffd166"))
	text_centered(SCREEN.x * 0.5, 432, "Wave %d  •  Level %d  •  %d kills" % [s.round_number, s.level, s.kills], 20, Color("c8d3ed"))
	text_centered(SCREEN.x * 0.5, 466, "The run ends here and pays no coins.", 18, Color("ff9aa8"))
	var rows := [["LEAVE RUN", "quit_run", Color("ff718b")], ["KEEP PLAYING", "keep_playing", Color("69f4d4")]]
	for i in range(rows.size()):
		draw_menu_button(confirm_row_rect(i), rows[i][0], rows[i][1], rows[i][2])
	draw_hint_row(SCREEN.x * 0.5, confirm_row_rect(rows.size() - 1).end.y + 62,
		[["nav", "ARROWS", "MOVE"], ["confirm", "ENTER", "SELECT"], ["back", "ESC", "KEEP PLAYING"]])

func draw_settings(title: String, footer: String) -> void:
	fill_screen(Color("0b1020"))
	heading(SCREEN.x * 0.5, 226, title, 40, Color("eaf1ff"))
	var rows := [
		{"action": "sfx", "key": "", "label": "Sound Volume", "level": game.audio.volume},
		{"action": "music", "key": "", "label": "Music Volume", "level": game.audio.music_volume},
		{"action": "window", "key": "", "label": "Window Mode",
			"value": DisplaySettings.WINDOW_MODES[game.profile.choice("window_mode")]},
		# Only a window has a size worth setting; both fullscreen modes take the
		# monitor. Greyed rather than hidden, so the row does not move about.
		{"action": "resolution", "key": "", "label": "Resolution",
			"value": DisplaySettings.resolution_label(game.profile.choice("resolution")),
			"dim": game.profile.choice("window_mode") != 0},
		{"action": "quality", "key": "", "label": "Quality",
			"value": DisplaySettings.QUALITY[game.profile.choice("quality")]},
		{"action": "fps", "key": "", "label": "Frame Rate Cap",
			"value": DisplaySettings.fps_label(game.profile.choice("fps_cap"))},
		{"action": "showfps", "key": "", "label": "Show FPS", "on": game.profile.setting("show_fps")},
		{"action": "rift", "key": "V", "label": "Rift Effects", "on": game.rift_effects_enabled},
	]
	for i in range(rows.size()):
		if rows[i].has("level"): draw_slider_row(i, rows[i])
		elif rows[i].has("value"): draw_choice_row(settings_row_rect(i), rows[i])
		else: draw_toggle_row(settings_row_rect(i), rows[i])
	draw_menu_button(settings_row_rect(rows.size()), "CONTROLS", "controls", Color("82b7ff"))
	draw_menu_button(settings_row_rect(rows.size() + 1), "BACK", "back", Color("aabce1"))
	var last := settings_row_rect(rows.size() + 1)
	draw_hint_row(SCREEN.x * 0.5, last.end.y + 62,
		[["nav", "ARROWS", "PICK / ADJUST"], ["confirm", "ENTER", "TOGGLE"], ["back", "ESC", "BACK"]])
	if not on_pad(): text_centered(SCREEN.x * 0.5, last.end.y + 106, "or drag a bar with the mouse  •  %s" % footer, 15, Color("8ea4cb"))

# Every binding, both devices side by side. The pad column comes from asking
# pad_verb about each button rather than from a second list, so it cannot claim
# a binding the game does not actually have.
func draw_controls() -> void:
	fill_screen(Color("0b1020"))
	heading(SCREEN.x * 0.5, 132, "CONTROLS", 40, Color("eaf1ff"))
	var rows: Array = game.CONTROL_ROWS
	var width := 1180.0
	var left := (SCREEN.x - width) * 0.5
	var top := 196.0
	var row_h := 52.0
	var key_x := left + 520.0
	var pad_x := left + 852.0
	text_at(Vector2(left + 24.0, top - 14.0), "ACTION", 15, Color("7f8db0"))
	text_at(Vector2(key_x, top - 14.0), "KEYBOARD / MOUSE", 15, Color("7f8db0"))
	text_at(Vector2(pad_x, top - 14.0), "GAMEPAD  (%s)" % Gamepad.brand().to_upper(), 15, Color("7f8db0"))
	for i in range(rows.size()):
		var row: Dictionary = rows[i]
		var box := Rect2(Vector2(left, top + float(i) * row_h), Vector2(width, row_h - 6.0))
		# Banded, because eleven rows of three columns is a table and a table
		# without banding is where the eye loses its place.
		if i % 2 == 0: draw_rect(box, Color(0.09, 0.12, 0.22, 0.75))
		text_at(Vector2(box.position.x + 24.0, box.get_center().y + 6.0), String(row.label), 19, Color("e8efff"))
		text_at(Vector2(key_x, box.get_center().y + 6.0), String(row.key), 18, Color("9fd8ff"))
		var pad: String = String(row.pad) if row.has("pad") else game.pad_button_for(String(row.verb))
		text_at(Vector2(pad_x, box.get_center().y + 6.0), pad if pad != "" else "—", 18, Color("ffd8a8"))
	var back := controls_back_rect()
	draw_menu_button(back, "BACK", "back", Color("aabce1"))
	draw_hint_row(SCREEN.x * 0.5, back.end.y + 52.0,
		[["back", "ESC", "BACK"], ["confirm", "ENTER", "BACK"]])

# A value between two arrows, so it reads as a thing you step through rather
# than a thing you switch on. The arrows are drawn even when dimmed: the row is
# still selectable, it just will not do anything visible until you leave
# fullscreen, and hiding them would make it look broken instead of inactive.
func draw_choice_row(rect: Rect2, row: Dictionary) -> void:
	var focused := is_focused(String(row.action))
	var dim: bool = bool(row.get("dim", false))
	draw_panel(rect, Color(0.10,0.15,0.27,0.95) if focused else Color("182441"),
		Color("d6e2fa") if focused else Color("3d527d"), 3.0 if focused else 1.5)
	if focused: draw_rect(Rect2(rect.position, Vector2(6, rect.size.y)), Color("ffe09b"))
	var label_tint := Color("6f7fa4") if dim else Color("e8efff")
	var value_tint := Color("5c6b8c") if dim else Color("9fd8ff")
	text_at(Vector2(rect.position.x + 28.0, rect.get_center().y + 8.0), String(row.label), 21, label_tint)
	var mid := rect.end.x - 150.0
	text_centered(mid, rect.get_center().y + 8.0, String(row.value), 20, value_tint)
	text_at(Vector2(mid - 120.0, rect.get_center().y + 8.0), "<", 22, value_tint)
	text_at(Vector2(mid + 108.0, rect.get_center().y + 8.0), ">", 22, value_tint)

func draw_slider_row(index: int, row: Dictionary) -> void:
	var rect := settings_row_rect(index)
	var focused := is_focused(String(row.action))
	var level: float = row.level
	draw_panel(rect, Color(0.10,0.15,0.27,0.95) if focused else Color("182441"), Color("d6e2fa") if focused else Color("3d527d"), 3.0 if focused else 1.5)
	if focused: draw_rect(Rect2(rect.position, Vector2(6, rect.size.y)), Color("ffe09b"))
	text_at(rect.position + Vector2(28, 44), String(row.label), 24, Color("e9f0ff"))
	var bar := settings_bar_rect(index)
	draw_rect(bar, Color("101a30"), true)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * level, bar.size.y)), Color("69f4d4") if level > 0.0 else Color("54617d"), true)
	draw_rect(bar, Color("3d527d"), false, 1.5)
	# The handle makes it read as draggable rather than as a progress bar.
	draw_rect(Rect2(bar.position.x + bar.size.x * level - 4.0, bar.position.y - 5.0, 8.0, bar.size.y + 10.0), Color("e8efff"), true)
	text_right(rect.end.x - 28, rect.position.y + 44, "OFF" if level <= 0.0 else "%d%%" % int(round(level * 100.0)), 22, Color("ff718b") if level <= 0.0 else Color("69f4d4"))

func draw_toggle_row(rect: Rect2, row: Dictionary) -> void:
	var focused := is_focused(String(row.action))
	var accent: Color = Color("69f4d4") if row.on else Color("ff718b")
	draw_panel(rect, Color(0.10,0.15,0.27,0.95) if focused else Color("182441"), Color("d6e2fa") if focused else Color("3d527d"), 3.0 if focused else 1.5)
	# A bright edge on the focused row, so the selection is obvious without
	# relying on the border weight alone.
	if focused: draw_rect(Rect2(rect.position, Vector2(6, rect.size.y)), Color("ffe09b"))
	text_at(rect.position + Vector2(28, 44), String(row.key), 18, Color("8ea4cb"))
	text_at(rect.position + Vector2(120, 44), String(row.label), 24, Color("e9f0ff"))
	text_right(rect.end.x - 28, rect.position.y + 44, "ON" if row.on else "OFF", 24, accent)

func draw_game_over() -> void:
	fill_screen(Color(0.03,0.01,0.07,0.82))
	heading(SCREEN.x * 0.5, 200, "THE RIFT CONSUMES YOU", 38, Color("ff7590"))
	draw_run_summary(250.0)
	draw_earned_banner(922)
	draw_hint_row(SCREEN.x * 0.5, 966, [["confirm", "SPACE", "RUN AGAIN"], ["back", "ESC", "MAIN MENU"]], 18)

func draw_victory() -> void:
	fill_screen(Color(0.02,0.05,0.06,0.86))
	var pulse := (sin(Time.get_ticks_msec() * 0.004) + 1.0) * 0.5
	heading(SCREEN.x * 0.5, 190, "THE RIFT HOLDS", 44, Color("69f4d4").lerp(Color("ffe09b"), pulse))
	text_centered(SCREEN.x * 0.5, 232, "All %d waves cleared at danger %d" % [Balance.FINAL_WAVE, game.danger], 20, Color("dbe8ff"))
	draw_run_summary(268.0)
	var next_danger: int = game.danger + 1
	if next_danger < Balance.DANGER_LEVELS and game.profile.max_danger() >= next_danger:
		text_centered(SCREEN.x * 0.5, 920, "DANGER %d UNLOCKED" % next_danger, 24, Color("ffcf77"))
	draw_hint_row(SCREEN.x * 0.5, 966, [["confirm", "SPACE", "BACK TO TITLE"]], 18)

# What this run earned, on the screen that ends it: an achievement nobody is
# told about is not one.
func draw_earned_banner(y: float) -> void:
	if game.last_earned.is_empty(): return
	var names: Array[String] = []
	for id in game.last_earned: names.append(String(AchievementCatalog.get_achievement(String(id)).name))
	text_centered(SCREEN.x * 0.5, y, "UNLOCKED:  %s" % "   •   ".join(names), 20, Color("ffcf77"))

# Shared by the death and victory screens: what the run actually was, since a
# number on its own says nothing about the build that produced it.
func draw_run_summary(top: float) -> void:
	var s := game.session
	var panel := Rect2((SCREEN.x - 1100.0) * 0.5, top, 1100, 600)
	draw_panel(panel, Color(0.06,0.09,0.17,0.92), Color("3d527d"), 2.0)
	var left := panel.position.x + 48.0
	var headline := "WAVE %d / %d      %02d:%02d      %d KILLS      LEVEL %d      +%d COINS" % [
		s.round_number, Balance.FINAL_WAVE, int(s.run_time) / 60, int(s.run_time) % 60,
		s.kills, s.level, game.last_reward]
	text_centered(SCREEN.x * 0.5, top + 62, headline, 22, Color("ffcf77"))

	text_at(Vector2(left, top + 130), "WEAPONS", 15, Color("8ea4cb"))
	for i in range(s.weapons.size()):
		var weapon: Weapon = s.weapons[i]
		var slot := Rect2(left + float(i % 3) * 340.0, top + 152.0 + float(i / 3) * 66.0, 320, 54)
		draw_panel(slot, Color("1a2440"), weapon.def().color, 1.5)
		Icons.weapon(self, weapon.id, slot.position + Vector2(30, 27), 17.0, weapon.def().color)
		text_at(slot.position + Vector2(58, 24), weapon.display_name(), 16, weapon.def().color)
		text_at(slot.position + Vector2(58, 45), "%.0f dmg" % WeaponCatalog.damage_at(weapon.id, weapon.tier), 13, Color("9fb3d9"))

	# Placed under however many rows the rack actually took, not at a fixed
	# offset that assumes two. Same trap as the title screen's footer: a list
	# drawn from real data with a layout around it that guesses the count.
	var racks := maxi(2, int(ceil(float(s.weapons.size()) / 3.0)))
	var items_top := top + 178.0 + float(racks) * 66.0
	text_at(Vector2(left, items_top), "ITEMS", 15, Color("8ea4cb"))
	if s.items.is_empty():
		text_at(Vector2(left + 80, items_top), "none", 15, Color("54617d"))
	var x := left
	var y := items_top + 24.0
	for id in s.items:
		var def := ItemCatalog.get_item(id)
		var width := text_width(String(def.name), 13) + 38.0
		if x + width > panel.end.x - 48.0:
			x = left
			y += 36.0
		draw_panel(Rect2(x, y, width, 28), Color(0.09,0.13,0.24,0.85), def.color, 1.0)
		Icons.item(self, id, Vector2(x + 15, y + 14), 10.0, def.color)
		text_at(Vector2(x + 29, y + 19), String(def.name), 13, Color("c8d3ed"))
		x += width + 8.0

	text_at(Vector2(left, items_top + 182.0), "FINAL STATS", 15, Color("8ea4cb"))
	var parts: Array[String] = []
	for stat in ["max_hp", "hp_regen", "damage", "attack_speed", "crit_chance", "armor", "dodge", "speed", "lifesteal", "attack_range", "harvesting", "luck"]:
		if is_zero_approx(s.stats.get_stat(stat)): continue
		parts.append("%s %s" % [Stats.LABELS[stat], s.stats.format(stat)])
	draw_wrapped(Vector2(left, items_top + 210.0), "   •   ".join(parts), 15, Color("c8d3ed"), panel.size.x - 96.0)
