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
# The dome is the whole design language: a plain rounded body with the character's
# identity sitting on top of it as one accessory. The first pass asked for a
# "slime blob monster" and got creatures with tentacles and limbs -- busy
# silhouettes where the accessory had to compete with the body for attention.
STYLE="smooth rounded dome shape with a flat wide bottom, two small black dot eyes, one white gloss highlight, no arms, no legs, no feet, no tentacles, flat solid colors, no gradients, thick black outline, cute game mascot sprite, plain background"

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

gen char_runner   "a plain pale teal slime blob, friendly calm face"
gen char_warden   "a purple slime blob wearing a tall pointed purple wizard hat with a star on it"
gen char_revenant "a dark orange slime blob wearing a grey iron knight helmet with a visor slit"
gen char_dancer   "a pink slime blob wearing a red ninja headband with the ends trailing, angry eyes"
gen char_siege    "a wide fat yellow slime blob with a short grey metal cannon barrel mounted on top"
gen char_scav     "a mint green slime blob wearing a gold monocle over one eye and a tiny brown top hat"
echo "now run --import, or Godot keeps serving the old textures"
