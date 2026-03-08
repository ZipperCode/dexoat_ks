#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
CSS="$ROOT_DIR/webroot/css/style.css"

assert_contains() {
  pattern="$1"
  name="$2"
  if ! grep -Fq -- "$pattern" "$CSS"; then
    echo "[FAIL] $name"
    exit 1
  fi
  echo "[PASS] $name"
}

assert_contains "scroll-snap-type: x mandatory;" "tabs mobile horizontal snap"
assert_contains "-webkit-overflow-scrolling: touch;" "tabs mobile momentum scroll"
assert_contains "min-width: 0;" "mobile input shrink fix"
assert_contains "flex-wrap: wrap;" "mobile wrapped bars"
assert_contains "@media (max-width: 480px)" "small phone breakpoint"
assert_contains "font-size: 16px;" "prevent iOS zoom on inputs"
assert_contains "overflow-wrap: anywhere;" "log and package text wrap"

echo "[PASS] webui_mobile_test"
