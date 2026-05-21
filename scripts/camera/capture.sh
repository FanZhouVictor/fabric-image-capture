#!/usr/bin/env bash
# capture.sh — Trigger one frame and download it to the study data folder.
#
# The script writes to data/raw/camera_sessions/YYYY-MM-DD/ by default.
# Each capture log is stored next to the downloaded image files with the
# same basename, so image/log pairs are directly matchable.
#
# Usage:
#   /path/to/capture.sh before      # before contamination
#   /path/to/capture.sh after       # after contamination
#   /path/to/capture.sh <label>     # any short label: ref, wb, test ...
#   /path/to/capture.sh --help
#
# Output:
#   data/raw/camera_sessions/<YYYY-MM-DD>/<YYYY-MM-DD-HHMMSS>-<label>.cr3
#   data/raw/camera_sessions/<YYYY-MM-DD>/<YYYY-MM-DD-HHMMSS>-<label>.jpg
#   data/raw/camera_sessions/<YYYY-MM-DD>/<YYYY-MM-DD-HHMMSS>-<label>.log
#
# Prerequisites:
#   - gphoto2 installed (brew install gphoto2)
#   - Canon EOS RP powered on and connected via USB-C
#   - EOS Utility 3 NOT running
#   - preflight_camera.sh already run this session

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUTPUT_ROOT="${CAMERA_OUTPUT_ROOT:-$PROJECT_ROOT/data/raw/camera_sessions}"
# When called from a driver that already encodes the date in its output path
# (e.g. acquire_case.sh writes to data/raw/camera_sessions/YYYY-MM-DD/<case_slug>_HHMMSS/rot_*deg/),
# set CAMERA_SKIP_DATE_SUBDIR=1 to skip the extra YYYY-MM-DD/ nesting below.
SKIP_DATE_SUBDIR="${CAMERA_SKIP_DATE_SUBDIR:-0}"

# ============================================================================
# Help
# ============================================================================
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
fi

# ============================================================================
# Label argument
# ============================================================================
LABEL="${1:-}"
if [[ -z "$LABEL" ]]; then
  echo "Usage: $(basename "$0") <label>   (e.g. before, after, ref)"
  exit 1
fi
if [[ ! "$LABEL" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "Label may contain only letters, numbers, dot, underscore, and dash."
  exit 1
fi

# ============================================================================
# Output path and matching capture log
# ============================================================================
DATE=$(date +%Y-%m-%d)
TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)
if [[ "$SKIP_DATE_SUBDIR" == "1" ]]; then
  OUTDIR="$OUTPUT_ROOT"
else
  OUTDIR="$OUTPUT_ROOT/$DATE"
fi
BASENAME="${TIMESTAMP}-${LABEL}"
mkdir -p "$OUTDIR"
LOGFILE="$OUTDIR/${BASENAME}.log"

log()  { printf '%s %s\n' "$(date +%H:%M:%S)" "$*" | tee -a "$LOGFILE"; }
fail() { log "ERROR: $*"; exit 1; }

# ============================================================================
# Checks
# ============================================================================
command -v gphoto2 >/dev/null 2>&1 || fail "gphoto2 not found. Run: brew install gphoto2"

if pgrep -x "EOS Utility" >/dev/null 2>&1; then
  fail "EOS Utility 3 is running — quit it first (only one app may own the USB)."
fi

# See preflight_camera.sh for the full rationale. macOS's PTPCamera LaunchAgent
# respawns instantly after `killall`, racing gphoto2 for the USB interface and
# producing -53 ('Could not claim the USB device'). `launchctl bootout` removes
# the agent for the current login session; `killall` is the immediate fallback.
release_camera_usb() {
  launchctl bootout "gui/$(id -u)/com.apple.ptpcamerad" >/dev/null 2>&1 || true
  killall -9 ptpcamerad 2>/dev/null || true
  killall -9 PTPCamera  2>/dev/null || true
}

release_camera_usb
sleep 1

log "Detecting camera..."
CAMERA_LIST="$(gphoto2 --auto-detect 2>&1 || true)"
if ! echo "$CAMERA_LIST" | grep -qi "Canon EOS RP"; then
  log "Auto-detect output:"
  echo "$CAMERA_LIST" | tee -a "$LOGFILE"
  fail "Canon EOS RP not found. Check USB cable and camera power."
fi
log "Camera OK"

log "Output folder : $OUTDIR"
log "Filename base : $BASENAME"
log "Capture log   : $LOGFILE"

# ============================================================================
# Capture (with USB-claim retry)
# ============================================================================
log "Firing shutter (drive mode: 2 s self-timer — stand clear)..."
capture_ok=0
for attempt in 1 2 3; do
  if gphoto2 --capture-image-and-download \
             --filename "${OUTDIR}/${BASENAME}.%C" \
             --force-overwrite \
             >> "$LOGFILE" 2>&1; then
    capture_ok=1
    break
  fi
  log "  capture attempt $attempt/3 failed — releasing USB and retrying"
  release_camera_usb
  sleep 2
done

if [[ "$capture_ok" -ne 1 ]]; then
  log "Capture failed after 3 attempts."
  log "If the error is 'Could not claim the USB device', the macOS PTPCamera"
  log "daemon is winning the USB race. Try: unplug the USB cable, wait 3 s,"
  log "replug, and re-run. To make the fix permanent for this user account:"
  log "  launchctl disable gui/\$(id -u)/com.apple.ptpcamerad"
  log "  launchctl bootout  gui/\$(id -u)/com.apple.ptpcamerad"
  fail "No image file was saved for $BASENAME."
fi

log "========================================================="
log " CAPTURE COMPLETE"
log " Label   : $LABEL"
log " Saved to: $OUTDIR/${BASENAME}.*"
log " Log     : $LOGFILE"
log "========================================================="
