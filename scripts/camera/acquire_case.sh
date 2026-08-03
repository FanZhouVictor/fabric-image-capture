#!/usr/bin/env bash
# acquire_case.sh — Capture all four replicate frames for one "case".
#
# A "case" is one (specimen × imaging stage) pair, named per the three-axis
# encoding in docs/nomenclature.md (coupon × treatment × stage). Locked
# production policy (src/image_processing/config.py, 2026-05-15):
#
#     SELECTED_REPLICATES_PER_CASE     = 4
#     SELECTED_REPLICATES_PER_ROTATION = 2
#     SELECTED_BACKGROUND              = "BWblue"
#
# This script captures 2 frames at 0°, then pauses for the operator to
# physically rotate the specimen by 180°, then captures 2 more frames.
# All four go into a single case folder. Filenames follow:
#
#   data/raw/camera_sessions/YYYY-MM-DD/
#     <case_slug>_<HHMMSS>/
#       rot_0deg/   <ts>_<case_slug>_0deg_r01.{cr3,jpg,log}
#                   <ts>_<case_slug>_0deg_r02.{cr3,jpg,log}
#       rot_180deg/ <ts>_<case_slug>_180deg_r01.{cr3,jpg,log}
#                   <ts>_<case_slug>_180deg_r02.{cr3,jpg,log}
#
# where <case_slug> = <test>_<coupon>_<treatment>_<stage>
#   test      Cxxx          (combustion-test ID)
#   coupon    parent | left | center | right
#             | left_center | center_right | left_center_right
#               (combined uncut-adjacent coupon strips: two or three
#                length-adjacent positions left joined as a single piece)
#   treatment as_exposed | env_aging | PER | advanced_cleaning | none
#   stage     pre_exposure | post_exposure | post_treatment
#
# Examples (see docs/acquisition_workflow.md for the full operator pipeline):
#
#   acquire_case.sh --test C186 --coupon parent --treatment none          --stage pre_exposure
#   acquire_case.sh --test C186 --coupon parent --treatment as_exposed    --stage post_exposure
#   acquire_case.sh --test C186 --coupon parent --treatment env_aging_7d  --stage post_exposure_aged
#   acquire_case.sh --test C186 --coupon left        --treatment env_aging_3d  --stage post_treatment
#   acquire_case.sh --test C186 --coupon left         --treatment PER           --stage post_treatment
#   acquire_case.sh --test C194 --coupon left_center  --treatment env_aging_3d  --stage post_treatment   # left+center left joined (length cut skipped)
#
# Optional overrides:
#   --reps-per-rotation N    default 2; matches SELECTED_REPLICATES_PER_ROTATION
#   --rotations LIST         default "0 180"; allowed values "0" or "0 180"
#   --self-test              dry-run; print what would happen, do not capture
#   --help | -h
#
# Prerequisites:
#   - gphoto2 installed (brew install gphoto2)
#   - Canon EOS RP powered on and connected via USB-C
#   - EOS Utility 3 NOT running
#   - preflight_camera.sh already run this session
#   - Case staged on the BWblue substrate with the ColorChecker at the right
#     edge of the A3 sheet, viewed with the specimen's top edge up

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUTPUT_ROOT="${CAMERA_OUTPUT_ROOT:-$PROJECT_ROOT/data/raw/camera_sessions}"
CAPTURE="$SCRIPT_DIR/capture.sh"

REPS_PER_ROTATION=2
ROTATIONS=(0 180)
SELF_TEST=0
TEST=""
COUPON=""
TREATMENT=""
STAGE=""

usage() { sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --test)              TEST="$2"; shift 2 ;;
    --coupon)            COUPON="$2"; shift 2 ;;
    --treatment)         TREATMENT="$2"; shift 2 ;;
    --stage)             STAGE="$2"; shift 2 ;;
    --reps-per-rotation) REPS_PER_ROTATION="$2"; shift 2 ;;
    --rotations)         IFS=' ' read -ra ROTATIONS <<< "$2"; shift 2 ;;
    --self-test)         SELF_TEST=1; shift ;;
    -h|--help)           usage ;;
    *)                   echo "unknown argument: $1" >&2; usage ;;
  esac
done

# Validate the three-axis identity.
[[ -n "$TEST" && "$TEST" =~ ^C[0-9]+$ ]]                        || { echo "--test required, format Cxxx" >&2; exit 1; }
# coupon positions: single (parent|left|center|right) or a combined uncut-adjacent
# strip (left_center | center_right | left_center_right) when adjacent coupons were
# left joined rather than cut apart. Non-adjacent joins (e.g. left+right) are not valid.
[[ "$COUPON"    =~ ^(parent|left|center|right|left_center|center_right|left_center_right)$ ]] \
                                                                || { echo "--coupon: parent|left|center|right | left_center|center_right|left_center_right" >&2; exit 1; }
# treatment slugs: as_exposed | env_aging_<N>d (any positive integer N) | PER | advanced_cleaning | none
[[ "$TREATMENT" =~ ^(as_exposed|env_aging_[0-9]+d|PER|advanced_cleaning|none)$ ]] \
                                                                || { echo "--treatment: as_exposed | env_aging_<N>d | PER | advanced_cleaning | none" >&2; exit 1; }
[[ "$STAGE"     =~ ^(pre_exposure|post_exposure|post_exposure_aged|post_treatment)$ ]] \
                                                                || { echo "--stage: pre_exposure|post_exposure|post_exposure_aged|post_treatment" >&2; exit 1; }

# Cross-axis validity:
if [[ "$STAGE" == "pre_exposure" && "$TREATMENT" != "none" ]]; then
  echo "pre_exposure stage requires treatment=none" >&2; exit 1
fi
if [[ "$STAGE" == "post_exposure_aged" ]]; then
  [[ "$COUPON" == "parent" ]]                || { echo "post_exposure_aged stage requires --coupon parent" >&2; exit 1; }
  [[ "$TREATMENT" =~ ^env_aging_[0-9]+d$ ]]  || { echo "post_exposure_aged stage requires --treatment env_aging_<N>d" >&2; exit 1; }
fi
if [[ "$STAGE" == "post_exposure" && "$TREATMENT" != "as_exposed" ]]; then
  echo "post_exposure stage uses treatment=as_exposed (parent immediately out of the smoke chamber)" >&2; exit 1
fi
if [[ "$STAGE" == "post_treatment" && "$COUPON" == "parent" ]]; then
  echo "post_treatment stage applies to a coupon strip, not the parent" >&2; exit 1
fi
if [[ "$STAGE" == "post_treatment" && "$TREATMENT" == "none" ]]; then
  echo "post_treatment stage requires a real treatment (as_exposed | env_aging_<N>d | PER | advanced_cleaning)" >&2; exit 1
fi
if [[ "$COUPON" != "parent" && "$STAGE" != "post_treatment" ]]; then
  echo "non-parent coupons are only captured at stage=post_treatment" >&2; exit 1
fi

CASE_SLUG="${TEST}_${COUPON}_${TREATMENT}_${STAGE}"
DATE=$(date +%Y-%m-%d)
SESSION_TS=$(date +%H%M%S)
CASE_DIR="$OUTPUT_ROOT/$DATE/${CASE_SLUG}_${SESSION_TS}"

echo "[acquire_case] case_slug   : $CASE_SLUG"
echo "[acquire_case] case_dir    : $CASE_DIR"
echo "[acquire_case] rotations   : ${ROTATIONS[*]}"
echo "[acquire_case] reps each   : $REPS_PER_ROTATION"
echo "[acquire_case] total frames: $(( REPS_PER_ROTATION * ${#ROTATIONS[@]} ))"
echo ""

if [[ "$SELF_TEST" -eq 1 ]]; then
  echo "[acquire_case] --self-test : printing plan only, no captures fired"
  for rot in "${ROTATIONS[@]}"; do
    for r in $(seq 1 "$REPS_PER_ROTATION"); do
      rr=$(printf "%02d" "$r")
      label="${CASE_SLUG}_${rot}deg_r${rr}"
      echo "  would capture: rot_${rot}deg/${label}"
    done
  done
  exit 0
fi

mkdir -p "$CASE_DIR"

for rot in "${ROTATIONS[@]}"; do
  rot_dir="$CASE_DIR/rot_${rot}deg"
  mkdir -p "$rot_dir"
  if [[ "$rot" != "${ROTATIONS[0]}" ]]; then
    echo ""
    echo "[acquire_case] ============================================================"
    echo "[acquire_case]   PAUSE  ── rotate the specimen 180° (in-plane), keep the "
    echo "[acquire_case]            ColorChecker at the right edge of the A3 sheet."
    echo "[acquire_case]   After the rotation, press <enter> to continue."
    echo "[acquire_case] ============================================================"
    read -r _
  fi
  for r in $(seq 1 "$REPS_PER_ROTATION"); do
    rr=$(printf "%02d" "$r")
    label="${CASE_SLUG}_${rot}deg_r${rr}"
    echo ""
    echo "[acquire_case] >>> capture rot ${rot}° rep ${rr} : label = $label"
    CAMERA_OUTPUT_ROOT="$rot_dir" CAMERA_SKIP_DATE_SUBDIR=1 "$CAPTURE" "$label"
  done
done

# Write a summary manifest at the case-folder level.
MANIFEST="$CASE_DIR/case_manifest.json"
python3 - "$CASE_DIR" "$CASE_SLUG" "$TEST" "$COUPON" "$TREATMENT" "$STAGE" "$DATE" "$SESSION_TS" \
        "${ROTATIONS[*]}" "$REPS_PER_ROTATION" "$MANIFEST" <<'PY'
import json, sys
from pathlib import Path
case_dir, slug, test, coupon, treatment, stage, date, ts, rots_str, reps, manifest = sys.argv[1:12]
rots = [int(x) for x in rots_str.split()]
case_dir = Path(case_dir)
frames = []
for rot in rots:
    rot_dir = case_dir / f"rot_{rot}deg"
    if not rot_dir.is_dir():
        continue
    # rglob handles both layouts: files directly in rot_*deg/ (the canonical
    # location after the 2026-05-15 capture.sh fix) AND files in a legacy
    # rot_*deg/<DATE>/ subfolder (from captures taken before the fix).
    cr3s = sorted(set(rot_dir.rglob("*.cr3")) | set(rot_dir.rglob("*.CR3")))
    for p in cr3s:
        frames.append({"rotation_deg": rot, "basename": p.stem,
                       "cr3": str(p.relative_to(case_dir))})
payload = {
    "case_slug": slug,
    "test": test,
    "coupon": coupon,
    "treatment": treatment,
    "stage": stage,
    "date": date,
    "session_start_local": ts,
    "rotations_deg": rots,
    "reps_per_rotation": int(reps),
    "background": "BWblue",
    "frames": frames,
}
Path(manifest).write_text(json.dumps(payload, indent=2) + "\n")
print(f"[acquire_case] manifest    : {manifest}")
PY

echo ""
echo "[acquire_case] ============================================================"
echo "[acquire_case]   CASE COMPLETE"
echo "[acquire_case]   slug : $CASE_SLUG"
echo "[acquire_case]   dir  : $CASE_DIR"
echo "[acquire_case]   next : stage the next case on the jig and re-run"
echo "[acquire_case] ============================================================"
