#!/usr/bin/env bash
# Turns the recorded video into a small looping GIF.
#   tools/screenshots/make-gif.sh <video.webm> <out.gif> [skip-seconds]
set -euo pipefail
in="$1"; out="$2"; skip="${3:-0}"
pal="$(mktemp --suffix=.png)"
ffmpeg -loglevel error -y -ss "$skip" -i "$in" -vf "fps=10,scale=300:-1:flags=lanczos,palettegen=max_colors=96" "$pal"
ffmpeg -loglevel error -y -ss "$skip" -i "$in" -i "$pal" -lavfi "fps=10,scale=300:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=4" "$out"
rm -f "$pal"
