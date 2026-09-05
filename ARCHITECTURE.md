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
- `scripts/game/arena.gd` / `arena_trim.gd`: bounds, walls, border and rifts.
- `scripts/actors/`: one script per actor scene.
- `scripts/ui/game_ui.gd`: menus, HUD, upgrade overlay.
- `scripts/data/`: gun, character, upgrade and enemy catalogs, plus
  `balance.gd` -- every number the difficulty curve depends on.
- `scripts/lib/layers.gd`: physics layer bits.
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
  single `run_ended` on death, boss rounds, and profile sanitizing.
- `tests/screenshot.gd` plays a short run and writes frames to a directory, so a
  visual change can be checked without sitting at the game. Needs a real
  (non-headless) run because it reads the viewport texture.

```
godot --headless --script res://tests/integration_test.gd
godot --script res://tests/screenshot.gd -- <output_dir>
```

Next additions belong in focused modules: new mechanics in `scripts/game`,
definitions in `scripts/data`, screens and widgets in `scripts/ui`.
