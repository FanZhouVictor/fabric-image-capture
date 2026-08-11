# Decontamination image capture

Scripts for photographing fabric pieces in the **decontamination workflow**. Same camera, same jig, same 4-frame protocol as the main study (`acquire_case.sh`) — only the specimens and the naming system are different.

## The physical pipeline

1. **Contaminate the parent** exactly as in the main study (nothing changes there — parent pre/post exposure captures still use the existing `../acquire_case.sh`).
2. **Trim** the contaminated parent at all four edge sides.
3. **Cut into four pieces**, numbered `piece1` → `piece4` from **LEFT to RIGHT** (viewed with the parent's `C###-top` label up).
4. The decon team assigns each piece a **decon ID** (e.g. `EM4P2P`). Record the piece-position → decon-ID mapping the moment the pieces are cut — the filenames are the only durable link.
5. **Photograph every piece one by one** (`--stage pre_wash`), each piece alone in the frame.
6. **Photograph the baseline piece** (`--stage pre_wash`). The baseline is pure, never-contaminated fabric cut to the same size as the pieces; it has a decon ID (e.g. `EM4P1P`) but no C-number and no piece position. It goes into the wash together with the contaminated pieces to show how the wash alone affects clean fabric.
7. **Run the decontamination wash.** Pieces marked as unwashed controls stay out of the wash.
8. **Photograph every washed piece and the baseline again** (`--stage post_wash`). Unwashed controls are *not* re-photographed — they have no after-wash state.

Repeat for each aging condition (this round is `0d`; later rounds will use other day counts).

## The naming system

Every capture is identified by six axes, all baked into the case slug and recorded in `decon_case_manifest.json`:

| Axis | Flag | Allowed values | Meaning |
|---|---|---|---|
| Source sample | `--test` *or* `--baseline` | `C###` / `--baseline` | Combustion test the piece was cut from; `--baseline` = pure fabric, no C-number |
| Piece position | `--piece` | `piece1`…`piece4` | Cut position, LEFT to RIGHT. Does not apply to `--baseline` |
| Decon ID | `--decon-id` | letters + digits, e.g. `EM4P2P` | ID assigned by the decon team |
| Aging condition | `--aging` | `<N>d`, e.g. `0d`, `7d` | Aging condition of this wash set |
| Washed or not | `--decon` | `yes` / `no` | `yes` = goes through the decontamination wash; `no` = unwashed control. Baseline is always `yes` |
| Wash stage | `--stage` | `pre_wash` / `post_wash` | Before / after the decontamination wash |

Watch the `--baseline` spelling — it differs between the two scripts: in `acquire_decon_case.sh` it is a bare flag and the ID goes in `--decon-id` (`--baseline --decon-id EM4P1P`); in `acquire_decon_set.sh` it takes the ID directly (`--baseline EM4P1P`).

Case slugs come out as:

```
C205_piece1_EM4P2P_aging_0d_decon_pre_wash        <- contaminated piece
baseline_EM4P1P_aging_0d_decon_pre_wash           <- baseline piece
```

The scripts reject invalid combinations, in particular `--stage post_wash` with `--decon no` (an unwashed control has no after-wash state) and `--piece` combined with `--baseline`.

## Which script do I use?

| Situation | Script |
|---|---|
| One piece (or the baseline) alone, one capture | `acquire_decon_case.sh` |
| A whole wash set — all four pieces + baseline at one stage, back to back | `acquire_decon_set.sh` (calls `acquire_decon_case.sh` for you, prompting between pieces) |

Both capture the locked 4-frame protocol per piece: 2 frames at 0°, you rotate the piece 180° in-plane, 2 more frames. Add `--self-test` to either script to print the plan without firing the camera.

## Before you start — per-session setup (unchanged from the main workflow)

The decon scripts use the same camera, profile, and jig as the main study, so the session setup is identical (full detail in the repo [README](../../../README.md)):

1. Warm up the light-box LEDs for at least 20 minutes.
2. Check the camera per [`docs/camera_setup_checklist.md`](../../../docs/camera_setup_checklist.md) (MF, IS off, mode dial M, zoom taped at 50 mm).
3. Plug in the camera while it is off, power it on, keep EOS Utility 3 **closed**.
4. **Run the preflight once per session** — required before any decon capture (from the repo root):

   ```bash
   cd fabric-image-capture
   ./scripts/camera/preflight_camera.sh
   ```

   Every parameter line in the banner should end in `OK`.

Then stage each piece on the BWblue substrate, top edge up, ColorChecker at the right edge of the A3 sheet.

## Quick start — worked example (C205 / EM4, 0-day aging)

C205 was contaminated and cut into four pieces. Left to right the decon team named them `EM4P2P`, `EM4P3P`, `EM4P2C`, `EM4P3C`. The baseline piece is `EM4P1P`. All five go through the wash.

### Before washing — one command per piece

```bash
cd fabric-image-capture

# Once per session, before any capture:
./scripts/camera/preflight_camera.sh

# The four contaminated pieces, left to right
./scripts/camera/decon_related/acquire_decon_case.sh \
    --test C205 --piece piece1 --decon-id EM4P2P --aging 0d --decon yes --stage pre_wash
./scripts/camera/decon_related/acquire_decon_case.sh \
    --test C205 --piece piece2 --decon-id EM4P3P --aging 0d --decon yes --stage pre_wash
./scripts/camera/decon_related/acquire_decon_case.sh \
    --test C205 --piece piece3 --decon-id EM4P2C --aging 0d --decon yes --stage pre_wash
./scripts/camera/decon_related/acquire_decon_case.sh \
    --test C205 --piece piece4 --decon-id EM4P3C --aging 0d --decon yes --stage pre_wash

# The baseline piece (pure fabric — no --test, no --piece)
./scripts/camera/decon_related/acquire_decon_case.sh \
    --baseline --decon-id EM4P1P --aging 0d --stage pre_wash
```

Keep a space before each trailing `\` — it tells the shell the command continues on the next line.

### Before washing — the same five captures in one command

```bash
./scripts/camera/decon_related/acquire_decon_set.sh \
    --test C205 --aging 0d --stage pre_wash \
    --piece piece1:EM4P2P:decon \
    --piece piece2:EM4P3P:decon \
    --piece piece3:EM4P2C:decon \
    --piece piece4:EM4P3C:decon \
    --baseline EM4P1P
```

Each `--piece` tuple is one shell word — no spaces around the colons. The script prompts you to stage each piece in turn, so you never have to retype identities between pieces.

### After washing

Wash the pieces, dry them per protocol, then repeat with `--stage post_wash`:

```bash
./scripts/camera/decon_related/acquire_decon_set.sh \
    --test C205 --aging 0d --stage post_wash \
    --piece piece1:EM4P2P:decon \
    --piece piece2:EM4P3P:decon \
    --piece piece3:EM4P2C:decon \
    --piece piece4:EM4P3C:decon \
    --baseline EM4P1P
```

### Unwashed control piece

If a piece is held back from the wash, mark it as an unwashed control — `--decon no` in the single-case script, `:no_decon` in a set tuple (the manifest records it as `"goes_through_decon": false`). It is photographed at `pre_wash` and skipped automatically at `post_wash`:

```bash
# pre_wash: captured, recorded as an unwashed control
./scripts/camera/decon_related/acquire_decon_case.sh \
    --test C206 --piece piece4 --decon-id EM5P4X --aging 0d --decon no --stage pre_wash

# post_wash: acquire_decon_set.sh skips no_decon tuples; the single-case
# script refuses them outright:
#   post_wash stage requires --decon yes
```

### Later aging conditions

Only the `--aging` value changes, e.g. a 7-day set:

```bash
./scripts/camera/decon_related/acquire_decon_set.sh \
    --test C210 --aging 7d --stage pre_wash \
    --piece piece1:EM6P2P:decon \
    --piece piece2:EM6P3P:decon \
    --piece piece3:EM6P2C:decon \
    --piece piece4:EM6P3C:decon \
    --baseline EM6P1P
```

### Not sure? Dry-run first

Append `--self-test` to any command above to print the exact plan (slugs, frame labels, skips) without touching the camera.

## Output layout

Each piece × stage gets its own case folder:

```
data/raw/camera_sessions/YYYY-MM-DD/
  C205_piece1_EM4P2P_aging_0d_decon_pre_wash_<HHMMSS>/
    decon_case_manifest.json     <- full identity + frame list
    rot_0deg/    2 frames (.cr3 + .jpg + .log each)
    rot_180deg/  2 frames (.cr3 + .jpg + .log each)
  ...
  baseline_EM4P1P_aging_0d_decon_pre_wash_<HHMMSS>/
    ...
```

A complete C205/EM4 wash set at one aging condition therefore produces 10 case folders (5 pieces × 2 stages) and 40 frames.

End-of-session handling is unchanged: copy the day's `data/raw/camera_sessions/YYYY-MM-DD/` folder to the lab storage drive and message Fan.
