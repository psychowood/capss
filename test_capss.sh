#!/bin/bash
# ============================================================
# test_capss.sh - Test suite for CAPSS
# ============================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASSED=0
FAILED=0
TEST_DIR="test_output"

# ── Helper Functions ─────────────────────────────────────
pass() {
  echo -e "${GREEN}✓${NC} $1"
  ((PASSED++)) || true
}

fail() {
  echo -e "${RED}✗${NC} $1"
  ((FAILED++)) || true
}

info() {
  echo -e "${YELLOW}→${NC} $1"
}

cleanup() {
  if [ -d "$TEST_DIR" ]; then
    rm -rf "$TEST_DIR"
  fi
}

assert_exit_code() {
  local expected=$1
  local actual=$2
  local test_name=$3
  
  if [ "$actual" -eq "$expected" ]; then
    pass "$test_name (exit code: $actual)"
  else
    fail "$test_name (expected: $expected, got: $actual)"
  fi
}

assert_file_exists() {
  local file=$1
  local test_name=$2
  
  if [ -f "$file" ]; then
    pass "$test_name"
  else
    fail "$test_name - file not found: $file"
  fi
}

assert_file_count() {
  local pattern=$1
  local expected=$2
  local test_name=$3
  
  local count=$(find $pattern 2>/dev/null | wc -l | tr -d ' ')
  
  if [ "$count" -eq "$expected" ]; then
    pass "$test_name (count: $count)"
  else
    fail "$test_name (expected: $expected, got: $count)"
  fi
}

assert_pdf_pages() {
  local pdf=$1
  local expected=$2
  local test_name=$3
  
  if [ ! -f "$pdf" ]; then
    fail "$test_name - PDF not found"
    return
  fi
  
  local pages=$(identify "$pdf" 2>/dev/null | wc -l | tr -d ' ')
  
  if [ "$pages" -eq "$expected" ]; then
    pass "$test_name (pages: $pages)"
  else
    fail "$test_name (expected: $expected, got: $pages)"
  fi
}

assert_image_width() {
  local image=$1
  local expected=$2
  local test_name=$3
  
  if [ ! -f "$image" ]; then
    fail "$test_name - image not found"
    return
  fi
  
  local width=$(identify -format "%w" "$image" 2>/dev/null)
  
  if [ "$width" -eq "$expected" ]; then
    pass "$test_name (width: ${width}px)"
  else
    fail "$test_name (expected: ${expected}px, got: ${width}px)"
  fi
}

# ── Test Setup ───────────────────────────────────────────
setup_test_images() {
  mkdir -p "$TEST_DIR/input"
  
  # Create 2 test images with known dimensions (3888x1440)
  magick -size 1544x1440 gradient:white-gray \
    -background lightgray -gravity west -splice 400x0 left.png
  magick -size 1544x1440 gradient:gray-white \
    -background lightgray -gravity east -splice 400x0 right.png
  magick left.png right.png +append "$TEST_DIR/input/test_01.jpg"
  
  magick -size 1544x1440 plasma:fractal \
    -background darkgray -gravity west -splice 400x0 left.png
  magick -size 1544x1440 plasma:fractal \
    -background darkgray -gravity east -splice 400x0 right.png
  magick left.png right.png +append "$TEST_DIR/input/test_02.jpg"
  
  rm left.png right.png
}

# ── Tests ────────────────────────────────────────────────
echo "========================================"
echo "CAPSS Test Suite"
echo "========================================"
echo ""

# Test 1: Script exists and is executable
info "Test 1: Script validation"
if [ -f "./capss.sh" ] && [ -x "./capss.sh" ]; then
  pass "Script exists and is executable"
else
  fail "Script not found or not executable"
fi

# Test 2: Invalid option handling
info "Test 2: Invalid option handling"
set +e
./capss.sh --invalid-option 2>/dev/null
exit_code=$?
set -e
assert_exit_code 1 $exit_code "Rejects invalid options"

# Test 3: Setup test environment
info "Test 3: Setting up test images"
cleanup
setup_test_images
assert_file_count "$TEST_DIR/input/test_*.jpg" 2 "Created test images"

# Test 4: Basic execution (default options)
info "Test 4: Basic execution with defaults"
set +e
./capss.sh "$TEST_DIR/input" "$TEST_DIR/output1" >/dev/null 2>&1
exit_code=$?
set -e
assert_exit_code 0 $exit_code "Script executes successfully"

# Count cropped files (excluding _L and _R files)
cropped_count=$(find "$TEST_DIR/output1" -name "test_*.jpg" -type f | grep -v "_[LR]\.jpg" | wc -l | tr -d ' ')
if [ "$cropped_count" -eq 2 ]; then
  pass "Cropped images created (count: $cropped_count)"
else
  fail "Cropped images created (expected: 2, got: $cropped_count)"
fi

assert_file_count "$TEST_DIR/output1/test_*_L.jpg" 2 "Left half images created"
assert_file_count "$TEST_DIR/output1/test_*_R.jpg" 2 "Right half images created"
assert_file_exists "$TEST_DIR/output1/pages_sequence.pdf" "Default PDF created"
assert_pdf_pages "$TEST_DIR/output1/pages_sequence.pdf" 4 "PDF has correct page count"

# Test 5: Custom chop values
info "Test 5: Custom chop values"
set +e
./capss.sh --chop-left 300 --chop-right 300 "$TEST_DIR/input" "$TEST_DIR/output2" >/dev/null 2>&1
exit_code=$?
set -e
assert_exit_code 0 $exit_code "Script executes with custom chop values"
assert_image_width "$TEST_DIR/output2/test_01.jpg" 3288 "Cropped width correct (3888-300-300=3288)"
assert_image_width "$TEST_DIR/output2/test_01_L.jpg" 1644 "Split width correct (3288/2=1644)"

# Test 6: Custom PDF name
info "Test 6: Custom PDF name"
set +e
./capss.sh --pdf-name "custom_book.pdf" "$TEST_DIR/input" "$TEST_DIR/output3" >/dev/null 2>&1
exit_code=$?
set -e
assert_exit_code 0 $exit_code "Script executes with custom PDF name"
assert_file_exists "$TEST_DIR/output3/custom_book.pdf" "Custom PDF name applied"

# Test 7: Combined options
info "Test 7: Combined options"
set +e
./capss.sh --chop-left 500 --chop-right 450 --pdf-name "combined.pdf" "$TEST_DIR/input" "$TEST_DIR/output4" >/dev/null 2>&1
exit_code=$?
set -e
assert_exit_code 0 $exit_code "Script executes with combined options"
assert_image_width "$TEST_DIR/output4/test_01.jpg" 2938 "Combined chop values work (3888-500-450=2938)"
assert_file_exists "$TEST_DIR/output4/combined.pdf" "Combined options PDF created"
assert_pdf_pages "$TEST_DIR/output4/combined.pdf" 4 "Combined options PDF has correct pages"

# Test 8: Non-existent input folder
info "Test 8: Error handling - non-existent folder"
set +e
./capss.sh "nonexistent_folder" 2>/dev/null
exit_code=$?
set -e
assert_exit_code 1 $exit_code "Rejects non-existent input folder"

# Test 9: Empty input folder
info "Test 9: Empty input folder"
mkdir -p "$TEST_DIR/empty"
set +e
./capss.sh "$TEST_DIR/empty" "$TEST_DIR/output5" 2>/dev/null
exit_code=$?
set -e
assert_exit_code 0 $exit_code "Handles empty folder gracefully"

# Test 10: Verify split dimensions are exactly half
info "Test 10: Verify exact half-split dimensions"
cropped_width=$(identify -format "%w" "$TEST_DIR/output1/test_01.jpg" 2>/dev/null)
left_width=$(identify -format "%w" "$TEST_DIR/output1/test_01_L.jpg" 2>/dev/null)
right_width=$(identify -format "%w" "$TEST_DIR/output1/test_01_R.jpg" 2>/dev/null)
expected_half=$((cropped_width / 2))

if [ "$left_width" -eq "$expected_half" ] && [ "$right_width" -eq "$expected_half" ]; then
  pass "Split pages are exactly half of cropped width"
else
  fail "Split dimensions incorrect (cropped: $cropped_width, left: $left_width, right: $right_width)"
fi

# ── Cleanup ──────────────────────────────────────────────
info "Cleanup"
cleanup
pass "Test artifacts cleaned up"

# ── Summary ──────────────────────────────────────────────
echo ""
echo "========================================"
echo "Test Summary"
echo "========================================"
echo -e "${GREEN}Passed: $PASSED${NC}"
[ $FAILED -gt 0 ] && echo -e "${RED}Failed: $FAILED${NC}" || echo -e "Failed: 0"
echo ""

if [ $FAILED -eq 0 ]; then
  echo -e "${GREEN}All tests passed!${NC}"
  exit 0
else
  echo -e "${RED}Some tests failed.${NC}"
  exit 1
fi
