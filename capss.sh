#!/bin/bash
# ============================================================
# capss.sh - Crop And Pdf Screenshot Splitter
# Process images from a folder:
#   - removes CHOP_LEFT px from the left
#   - removes CHOP_RIGHT px from the right
#   - splits each cropped image into 2 equal halves (left/right)
#   - creates a PDF with all pages in sequence
#
# Usage: ./capss.sh [OPTIONS] [input_folder] [output_folder]
#
# Options:
#   --chop-left NUM    Pixels to remove from left edge (default: 400)
#   --chop-right NUM   Pixels to remove from right edge (default: 400)
#   --pdf-name NAME    Output PDF filename (default: pages_sequence.pdf)
#
# If output_folder is not specified, defaults to "output" inside input_folder
# ============================================================

set -euo pipefail

# ── Default Values ───────────────────────────────────────
CHOP_LEFT=400
CHOP_RIGHT=400
PDF_NAME="pages_sequence.pdf"

# ── Parse Options ────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --chop-left)
      CHOP_LEFT="$2"
      shift 2
      ;;
    --chop-right)
      CHOP_RIGHT="$2"
      shift 2
      ;;
    --pdf-name)
      PDF_NAME="$2"
      shift 2
      ;;
    -*)
      echo "❌ Unknown option: $1"
      exit 1
      ;;
    *)
      break
      ;;
  esac
done

# ── Positional Arguments ─────────────────────────────────
INPUT_DIR="${1:-.}"
OUTPUT_DIR="${2:-$INPUT_DIR/output}"

# ── Checks ───────────────────────────────────────────────
if command -v magick &>/dev/null; then
  IM_CONVERT=(magick)
  IM_IDENTIFY=(magick identify)
elif command -v convert &>/dev/null && command -v identify &>/dev/null; then
  IM_CONVERT=(convert)
  IM_IDENTIFY=(identify)
else
  echo "❌ ImageMagick not found. Install it (e.g., brew install imagemagick)"
  exit 1
fi

if [ ! -d "$INPUT_DIR" ]; then
  echo "❌ Folder not found: $INPUT_DIR"
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

# ── Processing ───────────────────────────────────────────
shopt -s nullglob
FILES=("$INPUT_DIR"/*.{jpg,jpeg,png,tiff,tif,bmp,webp,JPG,JPEG,PNG,TIFF,TIF,BMP,WEBP})
shopt -u nullglob

TOTAL=${#FILES[@]}

if [ "$TOTAL" -eq 0 ]; then
  echo "⚠️  No images found in: $INPUT_DIR"
  exit 0
fi

echo "📁 Input folder:   $INPUT_DIR"
echo "📂 Output folder:  $OUTPUT_DIR"
echo "✂️  Removing:       ${CHOP_LEFT}px left | ${CHOP_RIGHT}px right"
echo "🖼️  Images found:   $TOTAL"
echo "📄 Final PDF:      $OUTPUT_DIR/$PDF_NAME"
echo "────────────────────────────────────────"

COUNT=0
ERRORS=0
SPLIT_PAGES=0
PDF_PAGES=()

for FILE in "${FILES[@]}"; do
  BASENAME=$(basename "$FILE")
  OUTPUT="$OUTPUT_DIR/$BASENAME"
  NAME_NO_EXT="${BASENAME%.*}"
  EXT="${BASENAME##*.}"

  # Read original width
  WIDTH=$("${IM_IDENTIFY[@]}" -format "%w" "$FILE" 2>/dev/null || echo 0)

  if [ "$WIDTH" -eq 0 ]; then
    echo "  ⚠️  Skipped (cannot read): $BASENAME"
    ((ERRORS++)) || true
    continue
  fi

  NEW_WIDTH=$(( WIDTH - CHOP_LEFT - CHOP_RIGHT ))

  if [ "$NEW_WIDTH" -le 0 ]; then
    echo "  ❌ Skipped (image too narrow, width=${WIDTH}px): $BASENAME"
    ((ERRORS++)) || true
    continue
  fi

  # Crop: first remove left, then remove right
  "${IM_CONVERT[@]}" "$FILE" \
    -gravity West  -chop "${CHOP_LEFT}x0" \
    -gravity East  -chop "${CHOP_RIGHT}x0" \
    "$OUTPUT"

  # Split the cropped image into two equal halves (left/right).
  CROPPED_WIDTH=$("${IM_IDENTIFY[@]}" -format "%w" "$OUTPUT" 2>/dev/null || echo 0)
  CROPPED_HEIGHT=$("${IM_IDENTIFY[@]}" -format "%h" "$OUTPUT" 2>/dev/null || echo 0)

  if [ "$CROPPED_WIDTH" -eq 0 ] || [ "$CROPPED_HEIGHT" -eq 0 ]; then
    echo "  ⚠️  Skipped split (dimensions unreadable): $BASENAME"
    ((ERRORS++)) || true
    continue
  fi

  if [ $((CROPPED_WIDTH % 2)) -ne 0 ]; then
    EVEN_WIDTH=$((CROPPED_WIDTH - 1))
    "${IM_CONVERT[@]}" "$OUTPUT" -gravity West -crop "${EVEN_WIDTH}x${CROPPED_HEIGHT}+0+0" +repage "$OUTPUT"
    CROPPED_WIDTH=$EVEN_WIDTH
    echo "  ℹ️  Odd width detected, removed 1px for exact split: $BASENAME"
  fi

  HALF_WIDTH=$((CROPPED_WIDTH / 2))
  LEFT_HALF="$OUTPUT_DIR/${NAME_NO_EXT}_L.${EXT}"
  RIGHT_HALF="$OUTPUT_DIR/${NAME_NO_EXT}_R.${EXT}"

  "${IM_CONVERT[@]}" "$OUTPUT" -crop "${HALF_WIDTH}x${CROPPED_HEIGHT}+0+0" +repage "$LEFT_HALF"
  "${IM_CONVERT[@]}" "$OUTPUT" -crop "${HALF_WIDTH}x${CROPPED_HEIGHT}+${HALF_WIDTH}+0" +repage "$RIGHT_HALF"

  PDF_PAGES+=("$LEFT_HALF" "$RIGHT_HALF")
  SPLIT_PAGES=$((SPLIT_PAGES + 2))

  ((COUNT++)) || true
  echo "  ✅ [$COUNT/$TOTAL] $BASENAME  (${WIDTH}px → ${NEW_WIDTH}px, split in 2)"
done

PDF_OUTPUT="$OUTPUT_DIR/$PDF_NAME"

if [ "${#PDF_PAGES[@]}" -gt 0 ]; then
  "${IM_CONVERT[@]}" "${PDF_PAGES[@]}" "$PDF_OUTPUT"
fi

echo "────────────────────────────────────────"
echo "✅ Completed: $COUNT images cropped"
echo "📄 Pages generated: $SPLIT_PAGES"
[ "$ERRORS" -gt 0 ] && echo "⚠️  Errors/skipped: $ERRORS"
if [ "${#PDF_PAGES[@]}" -gt 0 ]; then
  echo "📕 PDF created: $PDF_OUTPUT"
else
  echo "⚠️  PDF not created: no valid pages"
fi
echo "📂 Output saved in: $OUTPUT_DIR"
