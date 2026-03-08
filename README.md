# CAPSS

**Crop And Pdf Screenshot Splitter**

Convert landscape mobile phone screenshots of book pages into a clean, readable PDF.

## What it does

When photographing books with your phone in landscape mode, you often capture both pages of an open book in a single wide screenshot. This script:

1. **Crops** borders (removes 400px from left and right edges by default)
2. **Splits** each cropped image vertically into two separate pages
3. **Generates** a single PDF with all pages in sequence

Perfect for creating digital copies of books from mobile screenshots.

## Requirements

- Bash shell (macOS/Linux)
- ImageMagick: `brew install imagemagick` (macOS) or `apt install imagemagick` (Linux)

## Usage

```bash
# Process images in current directory
./capss.sh

# Specify input folder
./capss.sh /path/to/screenshots

# Specify both input and output folders
./capss.sh /path/to/screenshots /path/to/output
```

## Output

- **Cropped images**: `output/<filename>.jpg`
- **Split pages**: `output/<filename>_L.jpg` and `output/<filename>_R.jpg`
- **Final PDF**: `output/pages_sequence.pdf`

## Configuration

Edit the script to adjust crop amounts:

```bash
CHOP_LEFT=400   # pixels to remove from left edge
CHOP_RIGHT=400  # pixels to remove from right edge
```

## Supported formats

JPG, JPEG, PNG, TIFF, TIF, BMP, WEBP
