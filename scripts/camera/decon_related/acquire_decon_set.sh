#!/usr/bin/env bash
# acquire_decon_set.sh — Capture one full decon wash set, one piece at a time.
#
# A wash "set" is the four pieces cut from one contaminated parent (left to
# right: piece1..piece4) plus, optionally, one pure-fabric baseline piece,
# all at the SAME wash stage (pre_wash or post_wash) and aging condition.
# This driver runs acquire_decon_case.sh once per piece, pausing between
# pieces so you can swap what is on the jig. Each piece still gets its own
# case folder, its own 4-frame rotation protocol, and its own manifest.
#
# Usage:
#   acquire_decon_set.sh \
#     --test C205 --aging 0d --stage pre_wash \
#     --piece piece1:EM4P2P:decon \
#     --piece piece2:EM4P3P:decon \
#     --piece piece3:EM4P2C:decon \
#     --piece piece4:EM4P3C:decon \
#     --baseline EM4P1P
#
# Each --piece is <position>:<deconID>:<decon|no_decon> — ONE shell word,
# no spaces around the colons — where
#   position  piece1..piece4 (cut position, LEFT to RIGHT)
#   deconID   ID assigned by the decon team, letters/digits (e.g. EM4P2P)
#   decon     "decon" if the piece goes through the decontamination wash,
#             "no_decon" if it is held back as an unwashed control
# --baseline <deconID> declares the pure-fabric baseline piece washed with
# the set (always in the washed group). Declare pieces in piece order; they
# are captured in the order given, baseline last.
#
# At --stage post_wash, pieces declared no_decon are skipped automatically —
# an unwashed control has no after-wash state to photograph.
#
# Optional overrides (forwarded to acquire_decon_case.sh):
#   --reps-per-rotation N    default 2
#   --rotations LIST         default "0 180"
#   --self-test              dry-run; print the plan, do not capture
#   --help | -h
#
# Prerequisites: same as acquire_decon_case.sh (preflight run, EOS Utility
# closed, camera connected, BWblue substrate + ColorChecker staged).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CASE_SCRIPT="$SCRIPT_DIR/acquire_decon_case.sh"

TEST=""
AGING=""
STAGE=""
BASELINE_ID=""
PIECES=()
FORWARD=()
SELF_TEST=0

usage() { sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --test)              TEST="$2"; shift 2 ;;
    --aging)             AGING="$2"; shift 2 ;;
    --stage)             STAGE="$2"; shift 2 ;;
    --piece)             PIECES+=("$2"); shift 2 ;;
    --baseline)          BASELINE_ID="$2"; shift 2 ;;
    --reps-per-rotation) FORWARD+=(--reps-per-rotation "$2"); shift 2 ;;
    --rotations)         FORWARD+=(--rotations "$2"); shift 2 ;;
    --self-test)         SELF_TEST=1; FORWARD+=(--self-test); shift ;;
    -h|--help)           usage ;;
    *)                   echo "unknown argument: $1" >&2
                         echo "hint: each --piece tuple is one word with no spaces around the colons," >&2
                         echo "      e.g. --piece piece1:EM4P2P:decon" >&2
                         usage ;;
  esac
done

[[ "$TEST" =~ ^C[0-9]+$ ]]               || { echo "--test required, format Cxxx (e.g. C205)" >&2; exit 1; }
[[ "$AGING" =~ ^[0-9]+d$ ]]              || { echo "--aging required, format <N>d (e.g. 0d, 7d)" >&2; exit 1; }
[[ "$STAGE" =~ ^(pre_wash|post_wash)$ ]] || { echo "--stage: pre_wash|post_wash" >&2; exit 1; }
[[ ${#PIECES[@]} -ge 1 || -n "$BASELINE_ID" ]] \
                                         || { echo "declare at least one --piece tuple or a --baseline" >&2; exit 1; }
if [[ -n "$BASELINE_ID" ]]; then
  [[ "$BASELINE_ID" =~ ^[A-Za-z0-9]+$ ]] || { echo "--baseline: decon ID with letters and digits only (e.g. EM4P1P)" >&2; exit 1; }
fi

# Validate tuples; reject duplicate positions or duplicate decon IDs.
# (macOS ships bash 3.2, where "${PIECES[@]}" on an empty array trips set -u,
# so every expansion of PIECES uses the ${arr[@]+...} guard.)
seen_pos=""
seen_ids=" $BASELINE_ID "
for tup in ${PIECES[@]+"${PIECES[@]}"}; do
  IFS=':' read -r pos id grp extra <<< "$tup"
  [[ "$tup" != *:*:*:* && -n "${pos:-}" && -n "${id:-}" && -n "${grp:-}" ]] \
                                     || { echo "--piece must be <position>:<deconID>:<decon|no_decon> (got '$tup')" >&2; exit 1; }
  [[ "$pos" =~ ^piece[1-4]$ ]]       || { echo "'$tup': position must be piece1..piece4" >&2; exit 1; }
  [[ "$id" =~ ^[A-Za-z0-9]+$ ]]      || { echo "'$tup': decon ID must be letters and digits only" >&2; exit 1; }
  [[ "$grp" =~ ^(decon|no_decon)$ ]] || { echo "'$tup': wash group must be decon or no_decon" >&2; exit 1; }
  [[ " $seen_pos " != *" $pos "* ]]  || { echo "duplicate position: '$pos' declared twice" >&2; exit 1; }
  [[ "$seen_ids" != *" $id "* ]]     || { echo "duplicate decon ID: '$id' declared twice" >&2; exit 1; }
  seen_pos="$seen_pos $pos"
  seen_ids="$seen_ids$id "
done

echo "[acquire_decon_set] test     : $TEST"
echo "[acquire_decon_set] aging    : $AGING"
echo "[acquire_decon_set] stage    : $STAGE"
echo "[acquire_decon_set] baseline : ${BASELINE_ID:-<none>}"
echo ""
echo "[acquire_decon_set] pieces (cut positions run LEFT to RIGHT):"
printf '[acquire_decon_set]   %-8s %-10s %s\n' "position" "decon_id" "wash_group"
for tup in ${PIECES[@]+"${PIECES[@]}"}; do
  IFS=':' read -r pos id grp <<< "$tup"
  note=""
  if [[ "$STAGE" == "post_wash" && "$grp" == "no_decon" ]]; then
    note="   <- SKIPPED at post_wash (unwashed control)"
  fi
  printf '[acquire_decon_set]   %-8s %-10s %s%s\n' "$pos" "$id" "$grp" "$note"
done
[[ -n "$BASELINE_ID" ]] && printf '[acquire_decon_set]   %-8s %-10s %s\n' "baseline" "$BASELINE_ID" "decon"
echo ""

if [[ "$SELF_TEST" -eq 0 && ! -t 0 ]]; then
  echo "[acquire_decon_set] stdin is not a TTY — the between-piece staging prompts need an operator; aborting." >&2
  exit 1
fi

first=1
run_case() {
  local what="$1"; shift
  if [[ "$SELF_TEST" -eq 0 ]]; then
    echo ""
    echo "[acquire_decon_set] ============================================================"
    if [[ "$first" -eq 1 ]]; then
      echo "[acquire_decon_set]   STAGE ── place $what on the jig (top edge up,"
      echo "[acquire_decon_set]           ColorChecker at the right edge of the A3 sheet)."
    else
      echo "[acquire_decon_set]   SWAP  ── remove the previous piece and place $what"
      echo "[acquire_decon_set]           on the jig (top edge up, ColorChecker at the right"
      echo "[acquire_decon_set]           edge of the A3 sheet)."
    fi
    echo "[acquire_decon_set]   Press <enter> to capture, Ctrl-C to abort."
    echo "[acquire_decon_set] ============================================================"
    read -r _ || { echo "[acquire_decon_set] no confirmation received — aborting." >&2; exit 1; }
  else
    echo ""
    echo "[acquire_decon_set] --self-test : plan for $what"
  fi
  first=0
  "$CASE_SCRIPT" "$@" ${FORWARD[@]+"${FORWARD[@]}"}
}

for tup in ${PIECES[@]+"${PIECES[@]}"}; do
  IFS=':' read -r pos id grp <<< "$tup"
  if [[ "$STAGE" == "post_wash" && "$grp" == "no_decon" ]]; then
    echo ""
    echo "[acquire_decon_set] skipping $pos ($id): no_decon control has no post_wash state"
    continue
  fi
  yn="yes"; [[ "$grp" == "no_decon" ]] && yn="no"
  run_case "$TEST $pos (decon ID $id)" \
    --test "$TEST" --piece "$pos" --decon-id "$id" \
    --aging "$AGING" --decon "$yn" --stage "$STAGE"
done

if [[ -n "$BASELINE_ID" ]]; then
  run_case "the BASELINE piece (decon ID $BASELINE_ID, pure fabric)" \
    --baseline --decon-id "$BASELINE_ID" --aging "$AGING" --stage "$STAGE"
fi

echo ""
echo "[acquire_decon_set] ============================================================"
echo "[acquire_decon_set]   SET COMPLETE ── $TEST / aging $AGING / $STAGE"
echo "[acquire_decon_set] ============================================================"
