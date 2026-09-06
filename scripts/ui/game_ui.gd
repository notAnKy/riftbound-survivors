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

const ROW_SIZE := Vector2(700, 66)
const ROW_GAP := 12.0
const SETTINGS_TOP := 380.0
const PAUSE_TOP := 450.0

const MENU_BUTTON := Vector2(440, 64)
const MENU_TOP := 520.0
const MENU_STEP := 84.0

var game: GameController
var font: Font
var display: Font

func _ready() -> void:
	game = get_parent() as GameController
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
	elif game.state == "armory": draw_armory()
	elif game.state == "settings": draw_settings("SETTINGS", "ESC: back to title")
	else:
		# These three are full screens with their own headers and panels, so the
		# combat HUD under them just shows doubled numbers through the overlay.
		if not (game.state in ["shop", "victory", "game_over"]): draw_hud()
		if game.state == "level_up": draw_upgrades()
		elif game.state == "shop": draw_shop()
		elif game.state == "paused": draw_pause()
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
	return Rect2(Vector2((SCREEN.x - total) * 0.5 + index * (size.x + gap), top), size)

func card_rect(index: int) -> Rect2:
	return row_rect(index, SHOP_CARDS, CARD_SIZE, CARD_TOP, CARD_GAP)

func slot_count() -> int:
	return game.session.weapon_slots

func slot_rect(index: int) -> Rect2:
	return row_rect(index, slot_count(), SLOT_SIZE, SLOT_TOP, SLOT_GAP)

func reroll_rect() -> Rect2:
	return Rect2(Vector2(card_rect(0).position.x, BUTTON_TOP), BUTTON_SIZE)

func go_rect() -> Rect2:
	return Rect2(Vector2(card_rect(SHOP_CARDS - 1).end.x - BUTTON_SIZE.x, BUTTON_TOP), BUTTON_SIZE)

func menu_button_rect(index: int) -> Rect2:
	return Rect2(Vector2((SCREEN.x - MENU_BUTTON.x) * 0.5, MENU_TOP + index * MENU_STEP), MENU_BUTTON)

func danger_rect(index: int) -> Rect2:
	return row_rect(index, Balance.DANGER_LEVELS, Vector2(80, 46), 776.0, 12.0)

func armory_back_rect() -> Rect2:
	return Rect2(60, 60, 170, 52)

# The draggable part of a slider row, and the click position expressed as a
# 0..1 ratio along it.
func settings_bar_rect(index: int) -> Rect2:
	var row := settings_row_rect(index)
	return Rect2(row.position.x + 300.0, row.position.y + 24.0, row.size.x - 400.0, 18.0)

func slider_ratio_at(index: int, point: Vector2) -> float:
	var bar := settings_bar_rect(index)
	return clampf((point.x - bar.position.x) / maxf(bar.size.x, 1.0), 0.0, 1.0)

func settings_row_rect(index: int) -> Rect2:
	return Rect2(Vector2((SCREEN.x - ROW_SIZE.x) * 0.5, SETTINGS_TOP + index * (ROW_SIZE.y + ROW_GAP)), ROW_SIZE)

func pause_row_rect(index: int) -> Rect2:
	return Rect2(Vector2((SCREEN.x - ROW_SIZE.x) * 0.5, PAUSE_TOP + index * (ROW_SIZE.y + ROW_GAP)), ROW_SIZE)

# A row is lit either because the mouse is over it or because the keyboard
# cursor is on it; the controller keeps those two in step.
func is_focused(action: String) -> bool:
	if game.menu_hover == action: return true
	var items := game.menu_items()
	return game.menu_index >= 0 and game.menu_index < items.size() and items[game.menu_index] == action

func gun_rect(index: int) -> Rect2:
	return row_rect(index, 3, Vector2(400, 240), 280.0, 40.0)

func menu_action_at(point: Vector2) -> String:
	if game.state == "title":
		var actions := ["play", "armory", "settings", "quit"]
		for i in range(actions.size()):
			if menu_button_rect(i).has_point(point): return actions[i]
	elif game.state == "armory":
		if armory_back_rect().has_point(point): return "back"
		for i in range(Balance.DANGER_LEVELS):
			if danger_rect(i).has_point(point): return "danger_%d" % i
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
	elif game.state == "shop":
		for i in range(SHOP_CARDS):
			if card_rect(i).has_point(point): return "buy_%d" % i
		for i in range(game.session.weapons.size()):
			if slot_rect(i).has_point(point): return "sell_%d" % i
		if reroll_rect().has_point(point): return "reroll"
		if go_rect().has_point(point): return "go"
	return ""

func draw_panel(rect: Rect2, fill: Color, edge: Color, width: float = 2.0) -> void:
	draw_rect(rect, fill, true)
	draw_rect(rect, edge, false, width)

func fill_screen(color: Color) -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN), color)

# --- title and armory --------------------------------------------------------

func draw_title() -> void:
	draw_menu_background()
	heading(SCREEN.x * 0.5, 300, "RIFTBOUND", 68, Color("e8efff"))
	heading(SCREEN.x * 0.5, 378, "SURVIVORS", 68, Color("ffcf77"))
	text_centered(SCREEN.x * 0.5, 424, "An arcade survival run", 20, Color("aabce1"))
	var buttons := [["PLAY", "play", Color("69f4d4")], ["ARMORY", "armory", Color("bf8cff")], ["SETTINGS", "settings", Color("82b7ff")], ["QUIT GAME", "quit", Color("ff718b")]]
	for i in range(buttons.size()):
		draw_menu_button(menu_button_rect(i), buttons[i][0], buttons[i][1], buttons[i][2])
	text_centered(SCREEN.x * 0.5, 912, "COINS  %d" % game.profile.coins(), 20, Color("ffcf77"))
	text_centered(SCREEN.x * 0.5, 952, "Mouse or keyboard: P  A  S  Q", 15, Color("8ea4cb"))

func draw_armory() -> void:
	draw_menu_background()
	draw_menu_button(armory_back_rect(), "BACK", "back", Color("aabce1"))
	heading(SCREEN.x * 0.5, 150, "ARMORY", 44, Color("e8efff"))
	text_centered(SCREEN.x * 0.5, 196, "Choose a starting weapon and survivor", 18, Color("aabce1"))
	var guns := GunCatalog.all()
	for i in range(guns.size()):
		var box := gun_rect(i)
		var selected := i == game.selected_gun
		draw_panel(box, Color("263452") if selected else Color("151d35"), guns[i].color, 4.0 if selected else 2.0)
		text_at(box.position + Vector2(26,52), "%d  %s" % [i+1, guns[i].name], 20, guns[i].color)
		text_at(box.position + Vector2(26,96), guns[i].description, 16, Color("d1dcf5"))
		var unlocked := game.profile.is_gun_unlocked(i)
		text_at(box.position + Vector2(26,158), "EQUIPPED" if selected and unlocked else ("UNLOCK  %d COINS" % guns[i].cost if not unlocked else "Press %d" % (i+1)), 16, Color("ffcf77"))
	var character := CharacterCatalog.get_character(game.selected_character)
	var panel := Rect2((SCREEN.x - 1000.0) * 0.5, 580, 1000, 150)
	draw_panel(panel, Color("182441"), character.color)
	text_at(panel.position + Vector2(40, 52), "C  %s" % character.name, 24, character.color)
	text_at(panel.position + Vector2(40, 90), "%s  •  HP %d  •  SPEED %d" % [character.description, character.hp, character.speed], 17, Color("d1dcf5"))
	var perks := ItemCatalog.describe(character)
	var kinds: Array = character.get("kinds", [])
	var shape := "%d weapon slots" % int(character.get("slots", 6))
	if not kinds.is_empty(): shape += "  •  %s weapons only" % String(kinds[0]).to_upper()
	text_at(panel.position + Vector2(40, 122), shape, 15, Color("ffcf77"))
	text_at(panel.position + Vector2(320, 122), perks if perks != "" else "No stat modifiers", 15, Color("9fb3d9"))
	text_right(panel.end.x - 40, panel.position.y + 122, "READY" if game.profile.is_character_unlocked(game.selected_character) else "UNLOCK  %d COINS" % character.cost, 15, Color("ffcf77"))
	text_centered(SCREEN.x * 0.5, 762, "DANGER  —  arrows or click", 15, Color("8ea4cb"))
	for i in range(Balance.DANGER_LEVELS):
		var chip := danger_rect(i)
		var unlocked := i <= game.profile.max_danger()
		var picked := i == game.danger
		var accent := Color("ffcf77").lerp(Color("ff718b"), float(i) / float(Balance.DANGER_LEVELS - 1))
		draw_panel(chip, Color("263452") if picked else Color("141c31"), accent if unlocked else Color("2b3550"), 3.0 if picked else 1.5)
		text_centered(chip.get_center().x, chip.get_center().y + 8, str(i) if unlocked else "-", 22, accent if unlocked else Color("46526e"))
	text_centered(SCREEN.x * 0.5, 880, "Press PLAY from the main menu to begin", 18, Color("aabce1"))

func draw_menu_background() -> void:
	fill_screen(Color("0b1020"))
	for i in range(60):
		var star := Vector2(float((i * 197) % int(SCREEN.x)), float((i * 131) % int(SCREEN.y)))
		draw_circle(star, 1.0 + float(i % 3), Color(0.35,0.70,1.0,0.22))
	draw_arc(Vector2(SCREEN.x * 0.5, 300), 150.0, 0.2, TAU - 0.2, 32, Color(0.62,0.42,1.0,0.25), 10.0)
	draw_arc(Vector2(SCREEN.x * 0.5, 300), 108.0, 0.0, TAU, 28, Color(0.27,0.88,0.94,0.16), 5.0)

func draw_menu_button(rect: Rect2, label: String, action: String, color: Color) -> void:
	var hovered := is_focused(action)
	var pulse := (sin(Time.get_ticks_msec() * 0.008) + 1.0) * 0.5
	var shown_rect := rect.grow(4.0 + pulse * 2.0) if hovered else rect
	draw_panel(shown_rect, Color(color.r, color.g, color.b, 0.16) if hovered else Color("17233e"), color, 3.0 if hovered else 1.5)
	text_centered(shown_rect.get_center().x, shown_rect.get_center().y + 8.0, label, 21, Color("ffffff") if hovered else Color("d6e2fa"))

# --- combat HUD --------------------------------------------------------------

func draw_hud() -> void:
	var s := game.session
	var right := SCREEN.x - MARGIN
	text_at(Vector2(MARGIN, 48), "RIFTBOUND SURVIVORS", 26, Color("e8efff"))
	text_at(Vector2(MARGIN, 84), "MATERIALS  %d" % s.materials, 20, Color("8cffd1"))
	# Weapon rack, so the effect of a shop purchase is visible in the fight.
	var x := MARGIN + 300.0
	for weapon in s.weapons:
		var label: String = weapon.display_name()
		var width := text_width(label, 14) + 42.0
		draw_panel(Rect2(x, 62, width, 30), Color(0.09,0.13,0.24,0.85), weapon.def().color, 1.0)
		Icons.weapon(self, weapon.id, Vector2(x + 15, 77), 11.0, weapon.def().color)
		text_at(Vector2(x + 30, 84), label, 14, weapon.def().color)
		x += width + 9.0
	var round_status := "CLEAR HOSTILES" if s.round_phase == "cleanup" else ("SHOP" if s.round_phase == "shop" else "FIGHT")
	heading_right(right, 50, "WAVE %d / %d  %02d" % [s.round_number, Balance.FINAL_WAVE, int(ceil(s.round_time_left))], 28, Color("ffd166"))
	text_right(right, 80, "%s  •  KILLS %d" % [round_status, s.kills], 16, Color("ffcf77") if s.round_phase != "combat" else Color("b6c6e8"))
	text_right(right, 106, "Q DASH %s    E NOVA %s" % ["READY" if s.dash_cooldown <= 0.0 else "%.1fs" % s.dash_cooldown, "READY" if s.nova_cooldown <= 0.0 else "%.1fs" % s.nova_cooldown], 15, Color("b6c6e8"))
	var bar_y := SCREEN.y - 34.0
	draw_rect(Rect2(MARGIN, bar_y, 520, 14), Color("3a2844"))
	draw_rect(Rect2(MARGIN, bar_y, 520 * s.player_hp / s.player_max_hp, 14), Color("ff5f7a"))
	text_at(Vector2(MARGIN, bar_y - 10), "HP %d / %d" % [s.player_hp, s.player_max_hp], 16, Color("f2d8e0"))
	draw_rect(Rect2(right - 520, bar_y, 520, 14), Color("1f3e4c"))
	draw_rect(Rect2(right - 520, bar_y, 520 * float(s.xp) / maxf(1.0, float(s.xp_to_next)), 14), Color("60e8d2"))
	text_at(Vector2(right - 520, bar_y - 10), "LEVEL %d  •  XP %d / %d" % [s.level, s.xp, s.xp_to_next], 16, Color("d0fff7"))
	if s.round_number % 5 == 0 and s.round_phase == "combat" and s.round_time_left > s.round_length - 3.0:
		text_centered(SCREEN.x * 0.5, 170, "BOSS RIFT OPEN", 24, Color("ffcf77"))

# --- shop --------------------------------------------------------------------

func draw_shop() -> void:
	var s := game.session
	fill_screen(Color(0.02,0.03,0.08,0.94))
	heading(SCREEN.x * 0.5, 120, "WAVE %d CLEARED" % s.round_number, 34, Color("69f4d4"))
	text_centered(SCREEN.x * 0.5, 158, "Spend materials, then head back in", 18, Color("aabce1"))
	text_at(Vector2(MARGIN, 130), "MATERIALS  %d" % s.materials, 26, Color("8cffd1"))
	for i in range(SHOP_CARDS):
		draw_offer_card(i, s)
	var reroll_cost: int = s.shop.reroll_cost()
	draw_menu_button(reroll_rect(), "REROLL  %d  (R)" % reroll_cost, "reroll", Color("82b7ff") if s.materials >= reroll_cost else Color("54617d"))
	draw_menu_button(go_rect(), "NEXT WAVE  (SPACE)", "go", Color("69f4d4"))
	draw_class_bonuses(s)
	draw_weapon_slots(s)
	draw_owned_items(s)
	draw_stat_strip(s)

func draw_offer_card(index: int, s: GameSession) -> void:
	var rect := card_rect(index)
	var offer: Dictionary = s.shop.offers[index] if index < s.shop.offers.size() else {}
	if offer.is_empty():
		draw_panel(rect, Color(0.06,0.08,0.15,0.7), Color("2b3550"), 1.5)
		text_centered(rect.get_center().x, rect.get_center().y, "SOLD", 22, Color("54617d"))
		return
	var affordable: bool = s.materials >= int(offer.price)
	var hovered := game.menu_hover == "buy_%d" % index
	var edge: Color = offer.color if affordable else Color("54617d")
	draw_panel(rect, Color(0.12,0.16,0.28,0.95) if hovered else Color("151d35"), edge, 3.0 if hovered else 2.0)
	text_at(rect.position + Vector2(20, 38), "WEAPON" if offer.kind == "weapon" else "ITEM", 13, Color("8ea4cb"))
	if offer.kind == "weapon": Icons.weapon(self, String(offer.id), rect.position + Vector2(rect.size.x - 52, 56), 30.0, edge)
	else: Icons.item(self, String(offer.id), rect.position + Vector2(rect.size.x - 52, 56), 26.0, edge)
	text_at(rect.position + Vector2(20, 74), String(offer.name), 21, edge)
	draw_wrapped(rect.position + Vector2(20, 112), String(offer.text), 15, Color("c8d3ed"), rect.size.x - 40.0)
	if offer.kind == "weapon":
		var def: Dictionary = WeaponCatalog.get_weapon(String(offer.id))
		var dps: float = WeaponCatalog.damage_at(String(offer.id), int(offer.tier)) * float(def.shots) / WeaponCatalog.cooldown_at(String(offer.id), int(offer.tier))
		draw_class_chips(rect.position + Vector2(20, 156), def.get("classes", []), s)
		text_at(rect.position + Vector2(20, 192), "%.0f dps  •  %d range  •  %s" % [dps, int(def.range), String(def.kind).to_upper()], 14, Color("9fb3d9"))
	text_at(rect.position + Vector2(20, 226), "%d MATERIALS" % int(offer.price), 18, Color("8cffd1") if affordable else Color("ff718b"))
	text_right(rect.end.x - 18, rect.position.y + 226, "(%d)" % (index + 1), 15, Color("ffe09b"))

# A chip per weapon class, brightened when that class is already contributing
# a set bonus, so the shop shows what a purchase would build toward.
func draw_class_chips(at: Vector2, classes: Array, s: GameSession) -> void:
	var counts := s.class_counts()
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

func draw_class_bonuses(s: GameSession) -> void:
	var counts := s.class_counts()
	var live: Array = counts.keys().filter(func(id) -> bool: return s.class_steps(int(counts[id])) > 0)
	var left := slot_rect(0).position.x
	var y := SLOT_TOP - 46.0
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

func draw_weapon_slots(s: GameSession) -> void:
	text_at(Vector2(slot_rect(0).position.x, SLOT_TOP - 14), "WEAPONS  %d / %d  —  click to sell" % [s.weapons.size(), slot_count()], 15, Color("8ea4cb"))
	for i in range(slot_count()):
		var rect := slot_rect(i)
		if i >= s.weapons.size():
			draw_panel(rect, Color(0.06,0.08,0.15,0.6), Color("2b3550"), 1.0)
			text_centered(rect.get_center().x, rect.get_center().y + 6, "EMPTY", 14, Color("46526e"))
			continue
		var weapon: Weapon = s.weapons[i]
		var hovered := game.menu_hover == "sell_%d" % i
		draw_panel(rect, Color(0.14,0.10,0.14,0.95) if hovered else Color("1a2440"), weapon.def().color, 2.0 if hovered else 1.5)
		Icons.weapon(self, weapon.id, rect.position + Vector2(26, 31), 17.0, weapon.def().color)
		text_at(rect.position + Vector2(50, 26), weapon.display_name(), 15, weapon.def().color)
		var note := "sell +%d" % weapon.sell_value() if hovered and s.weapons.size() > 1 else "%.0f dmg" % WeaponCatalog.damage_at(weapon.id, weapon.tier)
		text_at(rect.position + Vector2(50, 50), note, 13, Color("ff9aa8") if hovered else Color("9fb3d9"))

func draw_owned_items(s: GameSession) -> void:
	var top := SLOT_TOP + SLOT_SIZE.y + 40.0
	var left := slot_rect(0).position.x
	text_at(Vector2(left, top), "ITEMS", 15, Color("8ea4cb"))
	if s.items.is_empty():
		text_at(Vector2(left + 78, top), "none yet", 15, Color("54617d"))
		return
	var x := left + 84.0
	for id in s.items:
		var def := ItemCatalog.get_item(id)
		var width := text_width(String(def.name), 14) + 40.0
		if x + width > SCREEN.x - left: break
		draw_panel(Rect2(x, top - 22, width, 30), Color(0.09,0.13,0.24,0.8), def.color, 1.0)
		Icons.item(self, id, Vector2(x + 16, top - 7), 11.0, def.color)
		text_at(Vector2(x + 31, top), String(def.name), 14, Color("c8d3ed"))
		x += width + 8.0

func draw_stat_strip(s: GameSession) -> void:
	var left := slot_rect(0).position.x
	var y := SCREEN.y - 60.0
	var parts: Array[String] = []
	for stat in ["damage", "attack_speed", "crit_chance", "armor", "dodge", "speed", "lifesteal", "harvesting", "pickup_radius"]:
		if is_zero_approx(s.stats.get_stat(stat)): continue
		parts.append("%s %s" % [Stats.LABELS[stat], s.stats.format(stat)])
	text_at(Vector2(left, y), "HP %d/%d" % [s.player_hp, s.player_max_hp], 15, Color("f2d8e0"))
	if not parts.is_empty():
		draw_wrapped(Vector2(left + 140, y), "  •  ".join(parts), 15, Color("9fb3d9"), SCREEN.x - left * 2.0 - 140.0)

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
	heading(SCREEN.x * 0.5, 300, "RIFT EVOLUTION", 38, Color("ffe09b"))
	text_centered(SCREEN.x * 0.5, 340, "Choose one upgrade", 20, Color("c8d3ed"))
	var choices: Array[Dictionary] = game.session.upgrades
	var rarity_colors := {"COMMON": Color("b7c5d9"), "RARE": Color("82b7ff"), "LEGENDARY": Color("ffcf77")}
	for i in range(choices.size()):
		var rect := row_rect(i, choices.size(), CARD_SIZE, 400.0, CARD_GAP)
		var edge: Color = rarity_colors[choices[i].rarity]
		draw_panel(rect, Color("202b4a"), edge, 3.0)
		text_at(rect.position + Vector2(24, 52), "%d" % (i + 1), 28, Color("ffe09b"))
		text_at(rect.position + Vector2(24, 88), String(choices[i].rarity), 14, edge)
		var granted: Array = choices[i].stats.keys()
		if not granted.is_empty():
			Icons.stat(self, String(granted[0]), rect.position + Vector2(rect.size.x - 52, 58), 28.0, edge)
		text_at(rect.position + Vector2(24, 124), String(choices[i].title), 21, Color("f1f5ff"))
		draw_wrapped(rect.position + Vector2(24, 162), UpgradeCatalog.describe(choices[i]), 16, Color("a9bbde"), rect.size.x - 48.0)
		text_at(rect.position + Vector2(24, 228), "Press %d" % (i + 1), 15, Color("ffe09b"))

func draw_pause() -> void:
	fill_screen(Color(0.02,0.03,0.08,0.80))
	heading(SCREEN.x * 0.5, 380, "PAUSED", 44, Color("eaf1ff"))
	var rows := [["CONTINUE", "resume", Color("69f4d4")], ["SETTINGS", "settings", Color("82b7ff")], ["MAIN MENU", "menu", Color("ff718b")]]
	for i in range(rows.size()):
		draw_menu_button(pause_row_rect(i), rows[i][0], rows[i][1], rows[i][2])
	text_centered(SCREEN.x * 0.5, pause_row_rect(rows.size() - 1).end.y + 56, "Arrows + Enter, or click  •  ESC continues", 16, Color("8ea4cb"))

func draw_settings(title: String, footer: String) -> void:
	fill_screen(Color("0b1020"))
	heading(SCREEN.x * 0.5, 300, title, 40, Color("eaf1ff"))
	var rows := [
		{"action": "sfx", "key": "", "label": "Sound Volume", "level": game.audio.volume},
		{"action": "music", "key": "", "label": "Music Volume", "level": game.audio.music_volume},
		{"action": "rift", "key": "V", "label": "Rift Effects", "on": game.rift_effects_enabled},
		{"action": "fullscreen", "key": "F11", "label": "Fullscreen", "on": game.is_fullscreen()},
	]
	for i in range(rows.size()):
		if rows[i].has("level"): draw_slider_row(i, rows[i])
		else: draw_toggle_row(settings_row_rect(i), rows[i])
	draw_menu_button(settings_row_rect(rows.size()), "BACK", "back", Color("aabce1"))
	text_centered(SCREEN.x * 0.5, settings_row_rect(rows.size()).end.y + 56, "Up/Down to pick  •  Left/Right to adjust  •  click a bar to set  •  %s" % footer, 16, Color("8ea4cb"))

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
	text_centered(SCREEN.x * 0.5, 960, "SPACE: run again   •   ESC: main menu", 21, Color("ffe09b"))

func draw_victory() -> void:
	fill_screen(Color(0.02,0.05,0.06,0.86))
	var pulse := (sin(Time.get_ticks_msec() * 0.004) + 1.0) * 0.5
	heading(SCREEN.x * 0.5, 190, "THE RIFT HOLDS", 44, Color("69f4d4").lerp(Color("ffe09b"), pulse))
	text_centered(SCREEN.x * 0.5, 232, "All %d waves cleared at danger %d" % [Balance.FINAL_WAVE, game.danger], 20, Color("dbe8ff"))
	draw_run_summary(268.0)
	var next_danger: int = game.danger + 1
	if next_danger < Balance.DANGER_LEVELS and game.profile.max_danger() >= next_danger:
		text_centered(SCREEN.x * 0.5, 920, "DANGER %d UNLOCKED" % next_danger, 24, Color("ffcf77"))
	text_centered(SCREEN.x * 0.5, 960, "SPACE: back to the title screen", 21, Color("ffe09b"))

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

	text_at(Vector2(left, top + 312), "ITEMS", 15, Color("8ea4cb"))
	if s.items.is_empty():
		text_at(Vector2(left + 80, top + 312), "none", 15, Color("54617d"))
	var x := left
	var y := top + 336.0
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

	text_at(Vector2(left, top + 494), "FINAL STATS", 15, Color("8ea4cb"))
	var parts: Array[String] = []
	for stat in ["max_hp", "damage", "attack_speed", "crit_chance", "armor", "dodge", "speed", "lifesteal", "attack_range", "harvesting", "luck"]:
		if is_zero_approx(s.stats.get_stat(stat)): continue
		parts.append("%s %s" % [Stats.LABELS[stat], s.stats.format(stat)])
	draw_wrapped(Vector2(left, top + 522), "   •   ".join(parts), 15, Color("c8d3ed"), panel.size.x - 96.0)
