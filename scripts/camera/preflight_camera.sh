#!/usr/bin/env bash
# preflight_camera.sh
# -----------------------------------------------------------------------------
# Canon EOS RP session preflight for the smoke-contaminated fabric imaging
# study. Applies all scriptable camera parameters via gphoto2 before each
# shooting session and prints a manual checklist for the items that cannot
# be reached programmatically on macOS.
#
# Usage:
#   ./preflight_camera.sh            # apply settings (WB done in post via ColorChecker N5)
#   ./preflight_camera.sh --dry-run  # read current values only; no writes
#   ./preflight_camera.sh --help
#
# Prerequisites:
#   - gphoto2 installed (brew install gphoto2)
#   - Canon EOS RP powered on and connected to the Mac by USB-C
#   - Mode dial at M; lens AF/MF = MF; lens IS = OFF; zoom locked at 50 mm
#   - EOS Utility 3 NOT running (only one app can own the USB at a time)
#   - macOS PTPCamera service NOT holding the camera
#
# Written for: scripts/camera/
# -----------------------------------------------------------------------------

set -euo pipefail

# ============================================================================
# SESSION PROFILE — edit these for your calibrated values
# ============================================================================
ISO="100"
APERTURE="8"
SHUTTER="1/125"                     # calibrated at first session; keep constant
WHITEBALANCE="Manual"               # "Manual" == Canon's "Custom" in gphoto2
COLORSPACE="AdobeRGB"
PICTURESTYLE="Neutral"
IMAGEFORMAT="RAW + Large Fine JPEG"
EXPCOMP="0"
METERING="Spot"
DRIVEMODE="Timer 2 sec"
AUTOPOWEROFF="0"                    # 0 = disabled
CAPTURETARGET="Memory card"         # save to SD; EOS Utility dual-write later
AUTOLIGHTINGOPTIMIZER="Off"

# ============================================================================
# CLI parsing
# ============================================================================
DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --help|-h)
      sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Unknown arg: $arg"; exit 1 ;;
  esac
done

# ============================================================================
# Logging
# ============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RUN_DATE="$(date +%Y-%m-%d)"
RUN_TIMESTAMP="$(date +%Y-%m-%d-%H%M%S)"
LOGDIR="$PROJECT_ROOT/data/raw/camera_sessions/$RUN_DATE"
mkdir -p "$LOGDIR"
LOGFILE="$LOGDIR/preflight_${RUN_TIMESTAMP}.log"

log()  { printf '%s %s\n' "$(date +%H:%M:%S)" "$*" | tee -a "$LOGFILE"; }
fail() { log "ERROR: $*"; exit 1; }

if [[ "$DRY_RUN" -eq 1 ]]; then
  MODE_LABEL="DRY-RUN (read-only, no writes)"
else
  MODE_LABEL="APPLY settings"
fi

log "========================================================="
log " EOS RP preflight — $(date '+%Y-%m-%d %H:%M:%S')"
log " Mode: $MODE_LABEL"
log " WB:   post-processing via ColorChecker N5 patch (Camera Raw)"
log " Log:  $LOGFILE"
log "========================================================="

# ============================================================================
# Environment checks
# ============================================================================
command -v gphoto2 >/dev/null 2>&1 || fail "gphoto2 not found. brew install gphoto2"

if pgrep -x "EOS Utility" >/dev/null 2>&1; then
  fail "EOS Utility 3 is running. Quit it first (only one app may own the USB)."
fi

# Release the camera USB from macOS's PTPCamera daemon. A one-shot `killall` is
# not enough — `ptpcamerad` is a per-user LaunchAgent that launchd respawns the
# instant a USB-camera event fires, which then loses the race against gphoto2
# and produces -53 ('Could not claim the USB device'). `launchctl bootout`
# removes the agent for the current login session so it stops respawning;
# `killall` is the immediate-effect fallback if bootout is denied.
release_camera_usb() {
  launchctl bootout "gui/$(id -u)/com.apple.ptpcamerad" >/dev/null 2>&1 || true
  killall -9 ptpcamerad 2>/dev/null || true
  killall -9 PTPCamera  2>/dev/null || true
}

# Run one gphoto2 invocation, retrying on USB-claim races. Output is appended
# to the session log; callers that need stdout should use `gphoto2_capture`.
gphoto2_with_retry() {
  local attempt
  for attempt in 1 2 3; do
    if gphoto2 "$@" >>"$LOGFILE" 2>&1; then
      return 0
    fi
    release_camera_usb
    sleep 1
  done
  return 1
}

# Like gphoto2_with_retry but echoes stdout (for --get-config read-back).
gphoto2_capture() {
  local attempt out
  for attempt in 1 2 3; do
    if out="$(gphoto2 "$@" 2>/dev/null)" && [[ -n "$out" ]]; then
      printf '%s' "$out"
      return 0
    fi
    release_camera_usb
    sleep 1
  done
  return 1
}

release_camera_usb
sleep 1

log "Detecting camera over USB..."
CAMERA_LIST="$(gphoto2 --auto-detect 2>&1 || true)"
if ! echo "$CAMERA_LIST" | grep -qi "Canon EOS RP"; then
  log "Auto-detect output:"
  echo "$CAMERA_LIST" | tee -a "$LOGFILE"
  fail "Canon EOS RP not found. Check cable, camera power, and that no other app owns the USB."
fi
log "Camera OK — $(echo "$CAMERA_LIST" | grep -i "Canon EOS RP" | head -1)"

# ============================================================================
# Helper: set one gphoto2 config with defensive fallback
# ============================================================================
set_cfg() {
  local path="$1"  value="$2"  label="$3"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    local cur
    cur="$(gphoto2_capture --get-config "$path" | awk -F': ' '/^Current/ {print $2}')" || cur="(unavailable)"
    log "[DRY] $label ($path) — current='${cur:-(unavailable)}' target='$value'"
    return 0
  fi
  if gphoto2_with_retry --set-config-value "$path=$value"; then
    log "  OK    $label = $value"
  else
    log "  WARN  $label ($path='$value') — not supported on this body or rejected; continuing"
  fi
}

# ============================================================================
# Apply session profile
# ============================================================================
log ""
log "Applying session profile..."
set_cfg "/main/imgsettings/iso"                       "$ISO"                    "ISO speed"
set_cfg "/main/capturesettings/aperture"              "$APERTURE"               "Aperture (f/)"
set_cfg "/main/capturesettings/shutterspeed"          "$SHUTTER"                "Shutter speed"
set_cfg "/main/imgsettings/whitebalance"              "$WHITEBALANCE"           "White balance mode (Manual = Custom)"
set_cfg "/main/imgsettings/colorspace"                "$COLORSPACE"             "Color space"
set_cfg "/main/imgsettings/picturestyle"              "$PICTURESTYLE"           "Picture Style"
set_cfg "/main/capturesettings/imageformat"           "$IMAGEFORMAT"            "Image quality"
set_cfg "/main/capturesettings/exposurecompensation"  "$EXPCOMP"                "Exposure compensation"
set_cfg "/main/capturesettings/meteringmode"          "$METERING"               "Metering mode"
set_cfg "/main/capturesettings/drivemode"             "$DRIVEMODE"              "Drive mode"
set_cfg "/main/settings/autopoweroff"                 "$AUTOPOWEROFF"           "Auto power off (s)"
set_cfg "/main/settings/capturetarget"                "$CAPTURETARGET"          "Capture target"
set_cfg "/main/capturesettings/autolightingoptimizer" "$AUTOLIGHTINGOPTIMIZER"  "Auto Lighting Optimizer"
set_cfg "/main/imgsettings/whitebalanceadjusta"       "0"                       "WB shift A-B"
set_cfg "/main/imgsettings/whitebalanceadjustb"       "0"                       "WB shift G-M"

# ============================================================================
# Read-back verification
# ============================================================================
log ""
log "Verifying (read-back)..."
for pair in \
  "/main/imgsettings/iso|ISO" \
  "/main/capturesettings/aperture|Aperture" \
  "/main/capturesettings/shutterspeed|Shutter" \
  "/main/imgsettings/whitebalance|WB mode" \
  "/main/imgsettings/colorspace|Color space" \
  "/main/imgsettings/picturestyle|Picture Style" \
  "/main/capturesettings/imageformat|Image quality" \
  "/main/capturesettings/meteringmode|Metering" \
  "/main/capturesettings/drivemode|Drive mode" \
  "/main/capturesettings/autolightingoptimizer|ALO"
do
  path="${pair%|*}"; label="${pair#*|}"
  cur="$(gphoto2_capture --get-config "$path" | awk -F': ' '/^Current/ {print $2}')" || cur="(unavailable)"
  log "  $label = ${cur:-(unavailable)}"
done

# ============================================================================
# White balance reminder
# ============================================================================
log ""
log " WB: set in post-processing — open Camera Raw, click the WB eyedropper"
log "     on the ColorChecker N5 patch (3rd from right, bottom neutral row),"
log "     record K + tint, and sync to all frames in the session."
log ""

# ============================================================================
# Manual-only reminder (items the script cannot reach)
# ============================================================================
log ""
log "MANUAL CHECKLIST — the script cannot set these; confirm on the camera:"
cat <<'EOF' | tee -a "$LOGFILE"
  [ ] Mode dial                            = M                  (hardware dial)
  [ ] Focus mode                           = MF                 (camera menu) + lens ring switch → Focus (not Control)
  [ ] Lens IS switch                       = OFF                (lens barrel STABILIZER switch)
  [ ] Lens zoom ring                       = locked at 50 mm    (gaffer tape — no zoom lock switch on this lens)
  [ ] Anti-flicker shooting                = Enable             (SHOOT3)
  [ ] Shutter mode                         = Elec. 1st-curtain  (SHOOT3; if not visible, EFCS is already default)
  [ ] Picture Style detail (Strength/Contrast/Saturation/Color Tone) = 0  (SHOOT2 → INFO)
  [ ] Highlight Tone Priority              = Disable            (SHOOT1)
  [ ] Long exp. noise reduction            = OFF                (SHOOT3)
  [ ] High ISO speed NR                    = Disable            (SHOOT3)
  [ ] Lens aberration correction           = all OFF            (SHOOT1)
  [ ] Dual Pixel RAW                       = N/A on EOS RP      (skip)
  [ ] HDR / Multi-exposure / Focus bracket = all Disable        (SHOOT3)
  [ ] Wi-Fi / Bluetooth                    = Disable            (wireless menu; optional if using USB tether)
  [ ] Copyright EXIF fields                = lab + project ID   (SET UP4)
  [ ] WB                                   = set in post via ColorChecker N5 patch
EOF

log ""
log "========================================================="
log " PREFLIGHT SUMMARY"
log "========================================================="
log " Mode:     $MODE_LABEL"
log " WB:       set in post via ColorChecker N5 patch (Camera Raw)"
log " Log file: $LOGFILE"
log "========================================================="
log "Settings applied. Run scripts/camera/capture.sh to shoot frames."
