# Project architecture

The simulation runs on real Godot nodes and the physics server. Everything used
to be dictionaries in arrays moved by hand and painted in one `_draw`; that is
gone. What is left of the old shape is the state machine and the menu drawing.

## Layout

- `main.gd`: application state, input routing, and the tree pause.
- `Main.tscn`: the only autoloaded scene. Session, audio and UI hang off it.
- `scenes/Arena.tscn`: tiled floor, wall bodies, decorative trim.
- `scenes/actors/`: `Player`, `Enemy`, `Projectile`, `Pickup`.
- `scripts/game/game_session.gd`: wave clock, spawning, weapons, wiring.
- `scripts/game/weapon.gd`: one equipped weapon; every number comes from Stats.
- `scripts/game/shop.gd`: the between-wave board, pure data and testable alone.
- `scripts/game/arena.gd` / `arena_trim.gd`: bounds, walls, border and rifts.
- `scripts/actors/`: one script per actor scene.
- `scripts/ui/game_ui.gd`: menus, HUD, upgrade overlay.
- `scripts/data/`: gun, character, upgrade, enemy, weapon and item catalogs,
  plus `stats.gd` (the character sheet) and `balance.gd` (the curve).
- `scripts/lib/layers.gd`: physics layer bits.
- `scripts/lib/gamepad.gd`: pad bindings, brand detection and button glyphs.
- `scripts/lib/controls.gd`: per-device movement actions, for two on one machine.
- `scripts/game/survivor.gd`: one player's half of a run; a session holds one or two.
- `scripts/lib/gamepad.gd`: pad bindings, brand detection and button glyphs.
- `scripts/save/profile_manager.gd`: persistent coins and unlocks.
- `assets/sprites/`: the sprites the game loads, cut from the Kenney pack in
  `assets/kenney/`.
- `tests/`: headless harnesses, see below.

## How the pieces move

`GameSession` no longer simulates anything. It owns the wave clock, decides what
to spawn and where, fires the equipped weapon, and connects the signals. Each
actor drives itself from its own `_physics_process`.

That split is why **pausing is `get_tree().paused`**, set from `main.gd` off the
application state. `GameController`, `GameUI` and `AudioSfx` are
`PROCESS_MODE_ALWAYS` so the menus still draw, input still routes and the audio
generator keeps its buffer fed while everything else is frozen.

**`GameSession` must then be set back to `PROCESS_MODE_PAUSABLE` by hand.** A
node defaults to `PROCESS_MODE_INHERIT`, which takes the *parent effective*
mode, so marking the controller `ALWAYS` quietly made every descendant
unpausable too. The symptom is subtle: the menus look right, but enemies keep
walking and killing behind the pause and level-up overlays.

The UI still reads the player vitals as `session.player_hp` and friends, but
those are now **property getters that forward to the player node** rather than
copies that could drift out of sync.

## Screen and arena

The game is designed at **1920x1080** and `stretch/mode = canvas_items` with
`aspect = keep` scales that whole area into whatever the window happens to be,
letterboxing rather than distorting or cropping.

**The design size and the window size are separate settings, and the window
must be smaller.** `window_*_override` opened the window at exactly 1920x1080
once, which on a 1080p desktop meant the title bar pushed the bottom of the UI
-- the HP and XP bars -- off the screen. It now opens at 1600x900 and scales
up. `tests/screenshot.gd` prints window size, design size and whether anything
is cropped on every run.

**F11 (or Alt+Enter) toggles borderless fullscreen**, handled in `main.gd`
before any per-state key mapping so it works from every screen. It is *also* a
row in Settings, because F11 sits on the Fn layer of many laptop keyboards and
simply never arrives -- a single key is not a reliable way to offer fullscreen.

## Menus

The list screens (title, settings, pause) are driven by `menu_items()` in
`main.gd`: one array per screen, in the order they are drawn. `menu_index` is
the keyboard cursor, `menu_hover` the mouse, and **`sync_hover` pulls the
cursor onto whatever the mouse is over** so the two can never disagree about
which row Enter would activate. Assigning `state` resets the cursor to the
first row, via the setter rather than at every call site.

`GameUI.is_focused(action)` is what lights a row, and it answers for both input
methods. The tests assert that every row hit-tests to its own action, so a
layout edit cannot silently make a click land on the wrong setting.

**`GameUI.SCREEN` is the one source of screen size** and every menu rectangle
comes from a helper (`menu_button_rect`, `card_rect`, `slot_rect`, ...) that
`menu_action_at` hit-tests against the same helper. Nothing in the UI should
carry a raw 1920 or 1080.

**`Arena.BOUNDS` is the one source of arena size.** The floor sprite is
stretched to it in `arena.gd::_ready` rather than in the `.tscn`, because a
`region_rect` authored in the scene silently kept covering the old rectangle
when the arena grew and left most of the field bare.

## The run loop

A run is `Balance.FINAL_WAVE` waves long. Clearing the last one sets
`round_phase = "won"` and emits `run_won`, which is a different signal from
`wave_cleared` precisely so the shop is not opened on the final wave. Both the
victory and death screens draw the same `draw_run_summary`, because a bare
number says nothing about the build that produced it.

**Danger levels are applied after `configure`, not inside it** — `apply_danger`
scales whatever the round curve and the elite roll already produced, rather
than being a fourth thing fighting over the same numbers. Beating a level
unlocks the next and only ever moves upward.

**`ProfileManager.persist` must be false in any harness.** A run that ends
awards coins and saves; the suite drives real runs, so with it left on every
test pass quietly topped up the player's real profile.

A wave ends into the **shop**, not a timer. `finish_wave()` sets
`round_phase = "shop"` and emits `wave_cleared`; `main.gd` puts the app in the
`shop` state, which pauses the tree like any other menu. `begin_round()` only
runs when the player leaves. That is the whole Brotato shape: fight, spend,
fight.

**Materials are both the currency and the level track.** One pickup pays into
each, so choosing to chase a drop is simultaneously an XP and a shopping
decision.

Healing comes from two places on purpose: a **bandage** that rolls on some
kills (nudged by Luck, so the stat pays off outside the shop too) and a flat
heal **every `HEAL_EVERY_KILLS` kills**, so a long clean wave still repays the
player when no bandage happens to drop.

**Rift Nova** damages and knocks back everything within `NOVA_RADIUS`, with
falloff by distance. The ring is a separate `NovaBlast` node rather than
something drawn inside the session, so the visual can outlive the single frame
the damage lands on -- which is the whole difference between reading as an
attack and reading as a silent stat tick.

### Economy and healing

**Healing must not scale with the kill count.** It did, and the kill count
explodes: by round 7 the passive drip out-healed a whole crowd, so standing
still was the strongest play. All three sources are now scarce (a 2% bandage
roll, a trickle every 50 kills), and **lifesteal is capped per hit** at a
fraction of max HP — a piercing weapon reports one hit per enemy and a crit
multiplies the amount, so an uncapped percentage refilled the bar from a
single shot into a crowd.

**Shop prices climb per wave** (`SHOP_INFLATION_PER_WAVE`). Material income
grows much faster than a shallow curve, so without this the shop stops
mattering by the midgame.

### Stats

`Stats` is a flat dictionary of named modifiers plus the helpers that read it.
Percent stats are stored as whole points (`damage = 25` means +25%), and
nothing outside `stats.gd` should be dividing by 100.

Two shapes are deliberate:

- **Armor uses `1 - armor / (armor + 30)`.** Flat reduction goes negative and
  percentage reduction reaches immunity; this approaches 100% without ever
  arriving. 30 armor is exactly half.
- **Dodge is capped at 60%**, because it is a reroll on every hit and an
  uncapped version makes a run unloseable rather than merely strong.

Everything downstream reads the sheet, so one item bought in the shop changes
health, movement, all six weapons and survivability at once.

### Weapon classes

Every weapon belongs to one or two **classes**, and holding several of a class
pays an escalating bonus: one step per weapon past the first, capped at five.
Most bonuses carry a cost -- BRUTAL trades speed for damage, VOID trades armor
for lifesteal -- so stacking a class is a decision rather than free value. A
weapon in two classes counts for both, which is what makes those weapons worth
more than their raw numbers.

The bonuses are folded into `rebuild_stats()` after the items, so a class bonus
and a per-item bonus can both land on the same stat.

**The shop leans toward classes already held** (`CLASS_MATCH_CHANCE`). Without
it a run never converges on a strategy; with it too high the shop stops
surprising. Measured at 0.4, an owned class shows up in about 56% of weapon
offers against 27% by chance.

### Item synergies

An item may carry a `per` block -- `+5% damage per weapon held`, `+13% damage
per empty slot`. Because the count changes whenever the inventory does, **the
stat sheet is rebuilt from scratch** in `rebuild_stats()` rather than added to
once at purchase: character base, then accumulated level-up grants
(`upgrade_totals`, kept separately precisely so they survive the rebuild), then
every item. Selling a weapon therefore takes an Arsenal Link bonus with it.

Anything that changes the inventory must call it: `add_item`, `add_weapon`,
`sell_weapon` and `choose_upgrade` all do.

### Weapon archetypes

`kind` on a weapon definition is the verb, and it is what stops every weapon
being the same thing with different numbers:

| kind | behaviour |
| --- | --- |
| `ranged` | fires a projectile at the nearest target in reach |
| `homing` | same, but the shot steers after the target it was fired at |
| `melee` | no projectile: sweeps an arc, damages and knocks back everything inside it |
| `orbital` | a shard circling the player, grinding whatever it passes over |

`fire()` dispatches on it. An **orbital never waits for a target** -- it is
handled before the cooldown check in `fire_weapons`, because it is always out
there rather than firing when something comes into range. A **homing shot does
not re-acquire**: a dart that loses its target flies straight, which keeps a
miss possible.

### Characters

`slots` and `kinds` on a character are what make it a strategy rather than a
stat block. `kinds` restricts which verbs it may carry (empty means all), and
it is enforced in three places that must agree: the starting weapon falls back
to the character's own if the armory pick is not allowed, `Shop` only rolls
weapons of those kinds, and `buy()` refuses one anyway.

### Weapons

Up to `GameSession.MAX_WEAPONS` (6). **Each has its own cooldown and picks its
own target inside its own reach**, so a short-range shotgun and a long rifle
behave differently on the same frame instead of sharing one timer.

Weapons are authored once at tier 1 and scaled: tier multiplies damage by
`TIER_DAMAGE` and shortens the cooldown by `TIER_COOLDOWN`. **Three of the same
weapon at the same tier merge into one of the next tier**, which is why a full
rack does not block a purchase that would combine -- see `would_combine`.

Projectile lifetime is derived from reach rather than authored, so the range
printed on a shop card is the range actually fired, Range stat included.

## Icons

Weapon and item icons come from **game-icons.net** (CC BY 3.0, credited per
artist in `assets/ATTRIBUTION.md`) via `scripts/ui/icons.gd`.
The UI is immediate-mode anyway, the Kenney pack has no inventory art, and a
drawn glyph takes each weapon's colour for free and stays sharp at any size.
Every shape is authored in a -1..1 box and multiplied by a `size`, so one
definition serves the shop card, the weapon rack, the HUD chip and the run
summary.

**`draw_colored_polygon` needs a *simple* polygon.** Concave is fine,
self-intersecting is not: the lance icon's spear head wound back across itself
and every draw printed `Invalid polygon data, triangulation failed`. Split a
shape like that into triangles rather than trying to trace it in one loop.

## Audio

`AudioSfx` holds a pool of `AudioStreamPlayer` voices and round-robins
through them, so a shotgun volley, a kill and a pickup can ring at once. The
previous version was a single generated sine: every sound cut off the one
before it, which in a busy wave is one voice fighting itself.

`BANKS` maps a name to how many numbered variations exist on disk, and `play`
picks one at random and detunes it slightly. That is what stops a fast weapon
sounding like a stuck loop. Weapons name their bank (`light`/`medium`/`heavy`)
in the catalog, and fast weapons are mixed quieter or an SMG drowns the rest.

Music is one looping `AudioStreamPlayer` alongside the voice pool, with its
own volume. `main.gd` calls `play_music(music_for_state())` every frame and
`play_music` is a no-op when the track has not changed, so the state machine
does not have to remember what is playing. Combat gets one track, every menu
and the shop share another, which is what makes leaving the shop feel like
going back in.

## Type

Orbitron for headings, Rajdhani for everything else. `GameUI.heading()` draws
with the display face; `text_at` and friends stay on the UI face. Orbitron is
a **variable** font, so it is wrapped in a `FontVariation` with `wght` 800 --
loaded raw it renders at its thinnest weight, which is useless for a title.

## Feel

Three things sell a hit, and each is deliberately cheap:

- **Damage numbers** are one `Node2D` per hit that draws a string and frees
  itself. They are added with a plain `add_child`, *not* deferred: a
  `DamageNumber` carries no collision shape so the physics server has no
  objection, and deferring made the `MAX_NUMBERS` cap read a stale child count
  and let every hit through.
- **Screen shake** offsets `GameSession.position`, which carries the arena and
  every actor but not the HUD -- that lives on a sibling node and has to stay
  still. It decays in `_process`, so it keeps moving between wave ticks.
- **Hit stop** drops `Engine.time_scale` for a few tens of milliseconds on a
  boss death or a nova. **It is restored in `main.gd`, not the session**,
  because the controller keeps processing while the tree is paused: pausing
  mid hit-stop would otherwise strand the whole game at 6% speed with nothing
  left running to undo it. The deadline is real time (`Time.get_ticks_msec`),
  since scaled delta would stretch with the effect.

**Weapons are drawn orbiting the player**, each turned toward its own target
and flashing when it fires. The rack is drawn in `Player._draw`, which renders
*before* the `Sprite2D` child, so the weapons sit behind the character instead
of covering it. `Weapon.aim` and `Weapon.flash` exist purely for this.

**Elites** are any enemy with every dimension scaled at once -- health, size,
speed, material value -- and a gold ring drawn round them. No separate art, no
separate catalog entry, and the chance ramps by round to a cap.

## Physics

Layer bits live in `scripts/lib/layers.gd` and are mirrored by name in
`project.godot`:

| Bit | Layer | Who is on it | What it collides with |
| --- | --- | --- | --- |
| 1 | World | arena walls | nothing (static) |
| 2 | Player | the player body | walls |
| 4 | Enemy | enemy bodies | walls, **and each other** |
| 8 | PlayerShot | player projectiles | walls, enemies |
| 16 | Pickup | dropped materials | nothing; the player magnet reads it |
| 32 | EnemyShot | gunner projectiles | walls, the player |

**Enemies collide with each other on purpose.** That mutual pressure is what
makes a crowd spread out instead of stacking into a single sprite, and it costs
nothing beyond putting them on each other's mask.

**Enemies spawn just inside the arena, never outside it.** The old sim had no
walls and started them 20px beyond the border; with real wall bodies that would
seal them out permanently. `spawn_point()` picks along an inner band and retries
if the roll lands too near the player.

**A pickup is added with `add_child.call_deferred`.** It is spawned from the
enemy death signal, which fires inside the projectile collision callback, and
the physics server refuses to have an `Area2D` added while it is flushing
queries. It reports this as an error and skips the node.

**Collision shapes are duplicated before they are resized.** A `.tscn`
sub-resource is shared by every instance of that scene, so setting a radius on
the shape straight out of `Enemy.tscn` would resize every other enemy too.

## Sprites

The Kenney top-down characters are drawn **facing +X**, so `rotation` is just
the angle to the target and no offset is needed. Only the `Sprite2D` child
rotates, never the body, which keeps each enemy health bar upright.

The floor is one `Sprite2D` with `texture_repeat` and an oversized
`region_rect`, not a TileMap: a single seamless 64px tile covers the arena. It
is modulated dark so the panel pattern stays behind the actors rather than
competing with them.

## Tests

Both are headless Godot scripts, run from the project root:

- `tests/integration_test.gd` boots the real scene and asserts against it:
  spawning inside the walls, crowd separation, walls containing the player
  (driven with real `Input.action_press`), projectile damage, pickup collection,
  single `run_ended` on death, the pause actually pausing, boss rounds, shop
  transactions, weapon combining and rack limits, multi-weapon output, the stat
  formulas, and profile sanitizing.

  It ends by asserting `EXPECTED_CHECKS` assertions ran. **A GDScript runtime
  error aborts only the function it happens in**, so a broken test simply stops
  asserting and the suite still reads as green -- which it did, for three tests
  at once, until this was added. Update the constant when adding assertions.
- `tests/screenshot.gd` plays a short run and writes frames to a directory, so a
  visual change can be checked without sitting at the game. Needs a real
  (non-headless) run because it reads the viewport texture.

```
godot --headless --script res://tests/integration_test.gd
godot --script res://tests/screenshot.gd -- <output_dir>
```

Next additions belong in focused modules: new mechanics in `scripts/game`,
definitions in `scripts/data`, screens and widgets in `scripts/ui`.
