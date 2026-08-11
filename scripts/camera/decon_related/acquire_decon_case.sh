#!/usr/bin/env bash
# acquire_decon_case.sh — Capture all replicate frames for one decontamination "case".
#
# A decon "case" is one (piece × wash stage) pair from the decontamination
# workflow. The parent specimen is contaminated exactly as in the main study;
# afterwards the trim is cut off all four edges and the parent is cut into
# FOUR pieces, numbered piece1..piece4 from LEFT to RIGHT (viewed with the
# parent's C###-top label up). The decon team assigns each piece its own
# decon ID (e.g. EM4P2P). Each piece is photographed ALONE, one piece per
# case, before the decontamination wash (pre_wash) and again after it
# (post_wash), using the same frame protocol as acquire_case.sh:
# 2 frames at 0°, operator rotates the piece 180° in-plane, 2 more frames.
#
# Baseline pieces are pure, never-contaminated fabric cut to the same size
# as piece1..piece4. A baseline piece is washed together with the
# contaminated pieces to see how the wash alone affects clean fabric. It has
# a decon ID (e.g. EM4P1P) but NO C-number and NO piece position — identify
# it with --baseline instead of --test/--piece. Baseline pieces are also
# photographed before and after the wash.
#
# Filenames follow:
#
#   data/raw/camera_sessions/YYYY-MM-DD/
#     <case_slug>_<HHMMSS>/
#       decon_case_manifest.json
#       rot_0deg/   <ts>_<case_slug>_0deg_r01.{cr3,jpg,log}
#                   <ts>_<case_slug>_0deg_r02.{cr3,jpg,log}
#       rot_180deg/ <ts>_<case_slug>_180deg_r01.{cr3,jpg,log}
#                   <ts>_<case_slug>_180deg_r02.{cr3,jpg,log}
#
# where <case_slug> encodes the six naming axes:
#
#   contaminated piece: <test>_<piece>_<deconID>_aging_<N>d_<decon|no_decon>_<stage>
#   baseline piece:     baseline_<deconID>_aging_<N>d_decon_<stage>
#
#   test      Cxxx                 combustion-test ID of the contaminated parent
#   piece     piece1..piece4       cut position, LEFT to RIGHT
#   deconID   e.g. EM4P2P          ID assigned by the decon team (letters/digits)
#   aging     <N>d, e.g. 0d, 7d    aging condition of this wash set
#   decon     yes -> "decon"       piece goes through the decontamination wash
#             no  -> "no_decon"    piece is held back as an unwashed control
#   stage     pre_wash | post_wash before / after the decontamination wash
#
# Examples (see README.md in this folder for the full pipeline):
#
#   acquire_decon_case.sh --test C205 --piece piece1 --decon-id EM4P2P --aging 0d --decon yes --stage pre_wash
#   acquire_decon_case.sh --test C205 --piece piece1 --decon-id EM4P2P --aging 0d --decon yes --stage post_wash
#   acquire_decon_case.sh --baseline --decon-id EM4P1P --aging 0d --stage pre_wash
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
#   - Piece staged on the BWblue substrate with the ColorChecker at the right
#     edge of the A3 sheet, viewed with the piece's top edge up

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
OUTPUT_ROOT="${CAMERA_OUTPUT_ROOT:-$PROJECT_ROOT/data/raw/camera_sessions}"
CAPTURE="$SCRIPT_DIR/../capture.sh"

REPS_PER_ROTATION=2
ROTATIONS=(0 180)
SELF_TEST=0
TEST=""
BASELINE=0
PIECE=""
DECON_ID=""
AGING=""
DECON=""
STAGE=""

usage() { sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --test)              TEST="$2"; shift 2 ;;
    --baseline)          BASELINE=1; shift ;;
    --piece)             PIECE="$2"; shift 2 ;;
    --decon-id)          DECON_ID="$2"; shift 2 ;;
    --aging)             AGING="$2"; shift 2 ;;
    --decon)             DECON="$2"; shift 2 ;;
    --stage)             STAGE="$2"; shift 2 ;;
    --reps-per-rotation) REPS_PER_ROTATION="$2"; shift 2 ;;
    --rotations)         IFS=' ' read -ra ROTATIONS <<< "$2"; shift 2 ;;
    --self-test)         SELF_TEST=1; shift ;;
    -h|--help)           usage ;;
    *)                   echo "unknown argument: $1" >&2; usage ;;
  esac
done

# ── Validate identity ────────────────────────────────────────────────────────
# Exactly one of --test (contaminated piece) or --baseline (pure fabric).
if [[ "$BASELINE" -eq 1 && -n "$TEST" ]]; then
  echo "--baseline and --test are mutually exclusive (a baseline piece has no C-number)" >&2; exit 1
fi
if [[ "$BASELINE" -eq 0 && -z "$TEST" ]]; then
  echo "identify the piece: --test Cxxx --piece pieceN for a contaminated piece, or --baseline for pure fabric" >&2; exit 1
fi

if [[ "$BASELINE" -eq 1 ]]; then
  # Baseline: no piece position; it exists only to be washed with the set.
  [[ -z "$PIECE" ]] || { echo "--piece does not apply to --baseline (pure fabric has no cut position)" >&2; exit 1; }
  [[ -z "$DECON" || "$DECON" == "yes" ]] \
                    || { echo "--baseline implies --decon yes (its purpose is to be washed with the set)" >&2; exit 1; }
  DECON="yes"
else
  [[ "$TEST" =~ ^C[0-9]+$ ]]                 || { echo "--test must match Cxxx (e.g. C205)" >&2; exit 1; }
  [[ "$PIECE" =~ ^piece[1-4]$ ]]             || { echo "--piece: piece1|piece2|piece3|piece4 (LEFT to RIGHT)" >&2; exit 1; }
  [[ "$DECON" =~ ^(yes|no)$ ]]               || { echo "--decon: yes (goes through the wash) | no (unwashed control)" >&2; exit 1; }
fi

[[ "$DECON_ID" =~ ^[A-Za-z0-9]+$ ]]          || { echo "--decon-id required, letters and digits only (e.g. EM4P2P)" >&2; exit 1; }
[[ "$AGING" =~ ^[0-9]+d$ ]]                  || { echo "--aging required, format <N>d (e.g. 0d, 7d)" >&2; exit 1; }
[[ "$STAGE" =~ ^(pre_wash|post_wash)$ ]]     || { echo "--stage: pre_wash|post_wash" >&2; exit 1; }

# Cross-axis validity: a piece that never goes through the wash has no
# "after washing" state to photograph.
if [[ "$STAGE" == "post_wash" && "$DECON" == "no" ]]; then
  echo "post_wash stage requires --decon yes (an unwashed control has no after-wash state)" >&2; exit 1
fi

[[ "$DECON" == "yes" ]] && DECON_TOKEN="decon" || DECON_TOKEN="no_decon"

if [[ "$BASELINE" -eq 1 ]]; then
  CASE_SLUG="baseline_${DECON_ID}_aging_${AGING}_${DECON_TOKEN}_${STAGE}"
else
  CASE_SLUG="${TEST}_${PIECE}_${DECON_ID}_aging_${AGING}_${DECON_TOKEN}_${STAGE}"
fi

DATE=$(date +%Y-%m-%d)
SESSION_TS=$(date +%H%M%S)
CASE_DIR="$OUTPUT_ROOT/$DATE/${CASE_SLUG}_${SESSION_TS}"

echo "[acquire_decon_case] case_slug   : $CASE_SLUG"
echo "[acquire_decon_case] case_dir    : $CASE_DIR"
echo "[acquire_decon_case] rotations   : ${ROTATIONS[*]}"
echo "[acquire_decon_case] reps each   : $REPS_PER_ROTATION"
echo "[acquire_decon_case] total frames: $(( REPS_PER_ROTATION * ${#ROTATIONS[@]} ))"
echo ""

if [[ "$SELF_TEST" -eq 1 ]]; then
  echo "[acquire_decon_case] --self-test : printing plan only, no captures fired"
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
    echo "[acquire_decon_case] ============================================================"
    echo "[acquire_decon_case]   PAUSE  ── rotate the piece 180° (in-plane), keep the "
    echo "[acquire_decon_case]            ColorChecker at the right edge of the A3 sheet."
    echo "[acquire_decon_case]   After the rotation, press <enter> to continue."
    echo "[acquire_decon_case] ============================================================"
    read -r _
  fi
  for r in $(seq 1 "$REPS_PER_ROTATION"); do
    rr=$(printf "%02d" "$r")
    label="${CASE_SLUG}_${rot}deg_r${rr}"
    echo ""
    echo "[acquire_decon_case] >>> capture rot ${rot}° rep ${rr} : label = $label"
    CAMERA_OUTPUT_ROOT="$rot_dir" CAMERA_SKIP_DATE_SUBDIR=1 "$CAPTURE" "$label"
  done
done

# Write a summary manifest at the case-folder level.
MANIFEST="$CASE_DIR/decon_case_manifest.json"
python3 - "$CASE_DIR" "$CASE_SLUG" "$TEST" "$BASELINE" "$PIECE" "$DECON_ID" "$AGING" "$DECON" "$STAGE" \
        "$DATE" "$SESSION_TS" "${ROTATIONS[*]}" "$REPS_PER_ROTATION" "$MANIFEST" <<'PY'
import json, sys
from pathlib import Path
(case_dir, slug, test, baseline, piece, decon_id, aging, decon, stage,
 date, ts, rots_str, reps, manifest) = sys.argv[1:15]
rots = [int(x) for x in rots_str.split()]
case_dir = Path(case_dir)
frames = []
for rot in rots:
    rot_dir = case_dir / f"rot_{rot}deg"
    if not rot_dir.is_dir():
        continue
    cr3s = sorted(set(rot_dir.rglob("*.cr3")) | set(rot_dir.rglob("*.CR3")))
    for p in cr3s:
        frames.append({"rotation_deg": rot, "basename": p.stem,
                       "cr3": str(p.relative_to(case_dir))})
is_baseline = baseline == "1"
payload = {
    "case_slug": slug,
    "workflow": "decontamination",
    "source_test": None if is_baseline else test,
    "baseline": is_baseline,
    "piece": None if is_baseline else piece,
    "piece_index": None if is_baseline else int(piece.replace("piece", "")),
    "piece_order": "left-to-right",
    "decon_id": decon_id,
    "aging": aging,
    "aging_days": int(aging[:-1]),
    "goes_through_decon": decon == "yes",
    "stage": stage,
    "date": date,
    "session_start_local": ts,
    "rotations_deg": rots,
    "reps_per_rotation": int(reps),
    "background": "BWblue",
    "frames": frames,
}
Path(manifest).write_text(json.dumps(payload, indent=2) + "\n")
print(f"[acquire_decon_case] manifest    : {manifest}")
PY

echo ""
echo "[acquire_decon_case] ============================================================"
echo "[acquire_decon_case]   CASE COMPLETE"
echo "[acquire_decon_case]   slug : $CASE_SLUG"
echo "[acquire_decon_case]   dir  : $CASE_DIR"
echo "[acquire_decon_case]   next : stage the next piece on the jig and re-run"
echo "[acquire_decon_case] ============================================================"
