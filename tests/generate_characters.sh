#!/usr/bin/env bash
# The six survivors, as generated. Needs a PixelLab API key in $PIXELLAB_KEY.
#
# STYLE is deliberately one string applied to all six: generated art drifts in
# style between calls, and six characters each rolled with their own wording is
# exactly how a roster ends up looking like six different games.
#
# 32x32 is not arbitrary either -- it is PixelLab's minimum canvas area, and it
# is as close as the API can get to the 16px Kenney tiles the enemies use. At 48
# the results came back with 1px detail and gradients that read as imported from
# a higher-resolution game. Check anything new with tests/compare_sheet.gd.
set -euo pipefail
STYLE="flat solid colors, no gradients, no shading, thick black outline, chunky retro 16-bit dungeon tileset sprite, centered, no shadow, no ground, plain background"

gen () {
  jq -n --arg d "$2, $STYLE" '{
    description: $d, image_size: {width: 32, height: 32}, no_background: true,
    outline: "single color black outline", shading: "flat shading",
    detail: "low detail", view: "low top-down", direction: "south",
    text_guidance_scale: 9 }' > /tmp/req.json
  curl -s -X POST "https://api.pixellab.ai/v1/generate-image-pixflux" \
    -H "Authorization: Bearer $PIXELLAB_KEY" -H "Content-Type: application/json" \
    --data-binary @/tmp/req.json \
  | python -c "import json,sys,base64;d=json.load(sys.stdin);open('assets/sprites/$1.png','wb').write(base64.b64decode(d['image']['base64']))"
  echo "wrote assets/sprites/$1.png"
}

gen char_runner   "a cute round teal slime blob monster with two simple dark eyes, friendly and plain"
gen char_warden   "a purple slime blob monster wearing a tall pointed wizard hat, holding a small glowing staff"
gen char_revenant "a dark orange slime blob monster wearing a heavy grey iron knight helmet with a visor"
gen char_dancer   "a pink slime blob monster wearing a red headband, holding a small silver dagger"
gen char_siege    "a large fat yellow slime blob monster with a big metal cannon barrel mounted on its back"
gen char_scav     "a mint green slime blob monster wearing a gold monocle, carrying a brown coin pouch"
echo "now run --import, or Godot keeps serving the old textures"
