#!/usr/bin/env bash
# acquire_batch.sh — Capture N replicate frames of one multi-piece "batch" paper.
#
# A "batch" is several fabric pieces staged together on one paper and
# photographed in a single frame. Pieces are identified by sample ID + sub ID
# (e.g. C205-1 = piece 1 of combustion test C205); each piece also declares
# its own treatment and stage, so mixed states on one paper are allowed.
# Pieces are declared in READING ORDER:
#
#     top-left → right, row-major, piece tops up,
#     ColorChecker at the right edge of the sheet.
#
# The per-position identity table is the only link between pixels and piece
# identity, so it is echoed back for operator confirmation before the first
# frame fires and written into batch_manifest.json afterwards.
#
# Batch frames are captured at 0° only (no 180° rotation pass) — decided
# 2026-07-13, see status.md D9. Single-sample cases keep the locked n = 4
# rotation protocol via acquire_case.sh.
#
# Usage:
#   acquire_batch.sh \
#     --sample C205-1:as_exposed:post_exposure \
#     --sample C205-2:PER:post_treatment \
#     --sample C205-3:env_aging_7d:post_treatment \
#     [--reps N]        # frames to capture, all at 0° (default 2)
#     [--name SLUG]     # batch folder/label slug (default batch_<sampleID(s)>)
#     [--paper NAME]    # paper/sheet identifier for the manifest (default a3)
#     [--self-test]     # dry-run; print the plan, do not capture
#     [--help | -h]
#
# Each --sample is <pieceID>:<treatment>:<stage> — ONE shell word, no spaces
# around the colons — where
#   pieceID   C<test>-<sub>, e.g. C205-1 (sub is a positive integer)
#   treatment as_exposed | env_aging_<N>d | PER | advanced_cleaning | none
#   stage     pre_exposure | post_exposure | post_exposure_aged | post_treatment
# Allowed stage:treatment pairs (same pairing rules as acquire_case.sh; the
# coupon axis does not apply to batch pieces):
#   pre_exposure       <- none
#   post_exposure      <- as_exposed
#   post_exposure_aged <- env_aging_<N>d
#   post_treatment     <- as_exposed | env_aging_<N>d | PER | advanced_cleaning
#
# Output:
#   data/raw/camera_sessions/YYYY-MM-DD/
#     <batch_slug>_<HHMMSS>/
#       <YYYY-MM-DD-HHMMSS>-<batch_slug>_r01.{cr3,jpg,log}
#       <YYYY-MM-DD-HHMMSS>-<batch_slug>_r02.{cr3,jpg,log}
#       batch_manifest.json
#
# Prerequisites:
#   - gphoto2 installed (brew install gphoto2)
#   - Canon EOS RP powered on and connected via USB-C
#   - EOS Utility 3 NOT running
#   - preflight_camera.sh already run this session
#   - All pieces staged on the BWblue substrate in the declared reading
#     order, tops up, ColorChecker at the right edge of the sheet

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUTPUT_ROOT="${CAMERA_OUTPUT_ROOT:-$PROJECT_ROOT/data/raw/camera_sessions}"
CAPTURE="$SCRIPT_DIR/capture.sh"

REPS=2
SELF_TEST=0
BATCH_NAME=""
PAPER="a3"
SAMPLES=()

usage() { sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sample)    SAMPLES+=("$2"); shift 2 ;;
    --reps)      REPS="$2"; shift 2 ;;
    --name)      BATCH_NAME="$2"; shift 2 ;;
    --paper)     PAPER="$2"; shift 2 ;;
    --self-test) SELF_TEST=1; shift ;;
    -h|--help)   usage ;;
    *)           echo "unknown argument: $1" >&2
                 echo "hint: each --sample tuple is one word with no spaces around the colons," >&2
                 echo "      e.g. --sample C205-1:as_exposed:post_exposure" >&2
                 echo "      and multi-line commands need a space before each trailing '\\'." >&2
                 usage ;;
  esac
done

[[ ${#SAMPLES[@]} -ge 2 ]] || { echo "need at least two --sample entries (for a single specimen use acquire_case.sh)" >&2; exit 1; }
[[ "$REPS" =~ ^[1-9][0-9]*$ ]] || { echo "--reps must be a positive integer" >&2; exit 1; }

# Validate each --sample tuple. Treatment/stage vocabulary and the
# stage-treatment pairing rules mirror acquire_case.sh (keep them in sync);
# the coupon axis is replaced by the piece sub-ID for batch papers.
validate_sample() {
  local raw="$1" pos="$2"
  IFS=':' read -r piece treatment stage extra <<< "$raw"
  # Reject a 4th field (even an empty one from a trailing colon) and any
  # empty field — the manifest writer splits on ':' and expects exactly 3.
  [[ "$raw" != *:*:*:* && -n "${piece:-}" && -n "${treatment:-}" && -n "${stage:-}" ]] \
                                             || { echo "pos $pos: --sample must be <pieceID>:<treatment>:<stage> (got '$raw')" >&2; exit 1; }
  [[ "$piece" =~ ^C[0-9]+-[0-9]+$ ]]         || { echo "pos $pos: piece ID '$piece' must match C<test>-<sub> (e.g. C205-1)" >&2; exit 1; }
  [[ "$treatment" =~ ^(as_exposed|env_aging_[0-9]+d|PER|advanced_cleaning|none)$ ]] \
                                             || { echo "pos $pos: treatment '$treatment' not in controlled vocabulary" >&2; exit 1; }
  [[ "$stage" =~ ^(pre_exposure|post_exposure|post_exposure_aged|post_treatment)$ ]] \
                                             || { echo "pos $pos: stage '$stage' not in controlled vocabulary" >&2; exit 1; }
  if [[ "$stage" == "pre_exposure" && "$treatment" != "none" ]]; then
    echo "pos $pos: pre_exposure stage requires treatment=none" >&2; exit 1
  fi
  if [[ "$stage" == "post_exposure" && "$treatment" != "as_exposed" ]]; then
    echo "pos $pos: post_exposure stage uses treatment=as_exposed" >&2; exit 1
  fi
  if [[ "$stage" == "post_exposure_aged" && ! "$treatment" =~ ^env_aging_[0-9]+d$ ]]; then
    echo "pos $pos: post_exposure_aged stage requires treatment=env_aging_<N>d" >&2; exit 1
  fi
  if [[ "$stage" == "post_treatment" && "$treatment" == "none" ]]; then
    echo "pos $pos: post_treatment stage requires a real treatment" >&2; exit 1
  fi
}

pos=0
for s in "${SAMPLES[@]}"; do
  pos=$((pos + 1))
  validate_sample "$s" "$pos"
done

# Reject the same piece declared twice.
seen_ids=""
for s in "${SAMPLES[@]}"; do
  id="${s%%:*}"
  if [[ " $seen_ids " == *" $id "* ]]; then
    echo "duplicate piece on one paper: '$id' declared twice" >&2; exit 1
  fi
  seen_ids="$seen_ids $id"
done

# Batch slug: batch_<sampleID> when every piece comes from the same sample,
# else batch_<firstSample>-<lastSample> in reading order.
if [[ -n "$BATCH_NAME" ]]; then
  BATCH_SLUG="$BATCH_NAME"
else
  parents=""
  for s in "${SAMPLES[@]}"; do
    pid="${s%%:*}"
    parent="${pid%-*}"
    [[ " $parents " == *" $parent "* ]] || parents="$parents $parent"
  done
  parents="${parents# }"
  if [[ "$parents" != *" "* ]]; then
    BATCH_SLUG="batch_${parents}"
  else
    BATCH_SLUG="batch_${parents%% *}-${parents##* }"
  fi
fi
# The slug feeds capture.sh labels, which allow only [A-Za-z0-9._-].
[[ "$BATCH_SLUG" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "--name may contain only letters, numbers, dot, underscore, and dash" >&2; exit 1; }

DATE=$(date +%Y-%m-%d)
SESSION_TS=$(date +%H%M%S)
BATCH_DIR="$OUTPUT_ROOT/$DATE/${BATCH_SLUG}_${SESSION_TS}"

echo "[acquire_batch] batch_slug  : $BATCH_SLUG"
echo "[acquire_batch] batch_dir   : $BATCH_DIR"
echo "[acquire_batch] paper       : $PAPER"
echo "[acquire_batch] reps (0°)   : $REPS"
echo "[acquire_batch] pieces      : ${#SAMPLES[@]}"
echo ""
echo "[acquire_batch] layout — reading order: top-left → right, row-major, tops up,"
echo "[acquire_batch]          ColorChecker at the right edge of the sheet"
printf '[acquire_batch]   %-4s %-10s %-18s %s\n' "pos" "piece" "treatment" "stage"
pos=0
for s in "${SAMPLES[@]}"; do
  pos=$((pos + 1))
  IFS=':' read -r piece treatment stage <<< "$s"
  printf '[acquire_batch]   %-4s %-10s %-18s %s\n' "$pos" "$piece" "$treatment" "$stage"
done
echo ""

if [[ "$SELF_TEST" -eq 1 ]]; then
  echo "[acquire_batch] --self-test : printing plan only, no captures fired"
  for r in $(seq 1 "$REPS"); do
    rr=$(printf "%02d" "$r")
    echo "  would capture: ${BATCH_SLUG}_r${rr}"
  done
  echo "  would write  : $BATCH_DIR/batch_manifest.json"
  exit 0
fi

echo "[acquire_batch] ============================================================"
echo "[acquire_batch]   CONFIRM ── the physical placement on the paper matches the"
echo "[acquire_batch]             layout table above (this confirmation is the only"
echo "[acquire_batch]             check that positions and identities agree)."
echo "[acquire_batch]   Press <enter> to start capturing, Ctrl-C to abort."
echo "[acquire_batch] ============================================================"
if [[ ! -t 0 ]]; then
  echo "[acquire_batch] stdin is not a TTY — operator confirmation of the layout is required; aborting." >&2
  exit 1
fi
read -r _ || { echo "[acquire_batch] no confirmation received — aborting." >&2; exit 1; }

mkdir -p "$BATCH_DIR"

for r in $(seq 1 "$REPS"); do
  rr=$(printf "%02d" "$r")
  label="${BATCH_SLUG}_r${rr}"
  echo ""
  echo "[acquire_batch] >>> capture rep ${rr}/${REPS} : label = $label"
  CAMERA_OUTPUT_ROOT="$BATCH_DIR" CAMERA_SKIP_DATE_SUBDIR=1 "$CAPTURE" "$label"
done

# Write the position→identity manifest at the batch-folder level.
MANIFEST="$BATCH_DIR/batch_manifest.json"
python3 - "$BATCH_DIR" "$BATCH_SLUG" "$DATE" "$SESSION_TS" "$PAPER" "$REPS" "$MANIFEST" "${SAMPLES[@]}" <<'PY'
import json, sys
from pathlib import Path
batch_dir, slug, date, ts, paper, reps, manifest = sys.argv[1:8]
tuples = sys.argv[8:]
batch_dir = Path(batch_dir)
positions = []
for i, t in enumerate(tuples, start=1):
    piece, treatment, stage = t.split(":")
    sample, sub = piece.rsplit("-", 1)
    positions.append({"pos": i, "piece_id": piece, "sample": sample,
                      "sub": int(sub), "treatment": treatment, "stage": stage})
frames = []
cr3s = sorted(set(batch_dir.rglob("*.cr3")) | set(batch_dir.rglob("*.CR3")))
for p in cr3s:
    frames.append({"basename": p.stem, "cr3": str(p.relative_to(batch_dir))})
payload = {
    "batch_slug": slug,
    "date": date,
    "session_start_local": ts,
    "background": "BWblue",
    "paper": paper,
    "reading_order": "row-major-tops-up",
    "rotations_deg": [0],
    "reps": int(reps),
    "positions": positions,
    "frames": frames,
}
Path(manifest).write_text(json.dumps(payload, indent=2) + "\n")
print(f"[acquire_batch] manifest    : {manifest}")
PY

echo ""
echo "[acquire_batch] ============================================================"
echo "[acquire_batch]   BATCH COMPLETE"
echo "[acquire_batch]   slug : $BATCH_SLUG"
echo "[acquire_batch]   dir  : $BATCH_DIR"
echo "[acquire_batch]   next : stage the next paper and re-run"
echo "[acquire_batch] ============================================================"
