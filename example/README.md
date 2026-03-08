# Example Test Images

This folder contains 3 dummy book screenshot images for testing the script.

## Image Details

- **Dimensions**: 3888x1440 pixels (landscape orientation)
- **Structure**: Each image has:
  - 400px gray border on left edge (to be cropped)
  - Left page (~1544px)
  - Right page (~1544px)
  - 400px gray border on right edge (to be cropped)

## Test the Script

From the parent directory, run:

```bash
./capss.sh example
```

This will:
1. Crop the 400px borders from each side
2. Split each image into left and right pages
3. Generate a PDF with 6 pages total (3 images × 2 pages each)

Output will be in `example/output/`
