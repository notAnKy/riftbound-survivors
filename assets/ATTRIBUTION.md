# Assets and licences

Two lists. What ships in the build, and what used to and no longer does — the
second matters because a licence that lapsed by removing the art comes straight
back if the art ever returns.

## Made in this project

All of it original, generated from shapes by scripts checked in beside it. No
licence obligation, no attribution owed, nothing to keep track of.

| What | Count | Generator |
| --- | --- | --- |
| Characters, enemies, bosses | 17 | `tests/draw_actors.gd` |
| Props and floor tiles | 4 | `tests/draw_actors.gd` |
| Weapon and item icons | 32 | `tests/draw_icons.gd` |

**Every image in the game is in this table.** `assets/sprites/` and
`assets/icons/` contain nothing else.

## Still third-party, and still shipping

**This is what stops the build being entirely original work.** It is all
audio and typefaces; none of it is art.

## Fonts

- **Orbitron** (headings) and **Rajdhani** (UI text), both from Google Fonts.
- License: **SIL Open Font License 1.1** — full text kept beside the fonts in
  `assets/fonts/OFL-Orbitron.txt` and `assets/fonts/OFL-Rajdhani.txt`.


**The OFL is not optional.** Unlike CC0, the SIL Open Font License *requires*
that the licence and copyright notice travel with the font wherever it goes. The
two `OFL-*.txt` files in `assets/fonts/` are that notice. Deleting them while
still shipping the `.ttf` files would breach the licence — so they stay for as
long as the fonts do. Replacing the fonts is the only way to remove them.

## Kenney — sound effects

- Packs: Interface Sounds, Impact Sounds, Sci-Fi Sounds
- Source: https://kenney.nl/  (obtained via community mirrors of the same
  CC0 packs: Calinou/kenney-interface-sounds,
  Boyquotes/kenney-impact-sounds-for-godot,
  Boyquotes/kenney-sci-fi-sounds-for-godot)
- License: **CC0 1.0** — attribution not required, retained as a courtesy.

## Music

- `combat.mp3` — freesound.org user **theojt**, "retro-electro" (569777)
- `menu.mp3` — freesound.org user **benderhover**, "retro game beat" (689169)
- Obtained via the SoundSafari/CC0-1.0-Music aggregation on GitHub, which is
  published under **CC0 1.0**. Both tracks carry their original freesound IDs,
  so provenance can be checked at the source.
- Note: that repository is a third-party aggregation. Its CC0 claim is only as
  good as the aggregator's diligence — verify each track at freesound.org
  before any commercial release.


## No longer used

- **Kenney — Tiny Dungeon** (CC0): every actor, prop and floor tile until they
  were redrawn. Source: https://kenney.nl/assets/tiny-dungeon
- **Kenney — Topdown Shooter** (CC0): the sprites before that.
- **game-icons.net** (CC BY 3.0): the weapon and item icons. This one carried a
  real attribution *requirement*, which no longer applies because none of the
  art remains. If any of it is reintroduced, the credit must come back with it.
- **PixelLab.ai**: the six characters were briefly generated
  (`tests/generate_characters.sh` records the prompts) before being drawn.
  Nothing generated ships, so their vendor terms no longer bear on the build.
