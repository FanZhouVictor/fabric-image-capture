# Acquisition workflow

Step-by-step procedure for the operator. Read this once end-to-end before your first session. After that, you only need to keep this open as a checklist.

A **case** is one (specimen, imaging stage) pair — for example: the parent specimen C187 before exposure, or the left coupon strip after a PER treatment. `acquire_case.sh` captures all four replicate frames for one case in a single run.

When several fabric pieces are staged together on one paper and photographed in a single frame, use `acquire_batch.sh` instead — one command per paper. See [§ 2-B](#2-b-multi-piece-batch-acquisition-acquire_batchsh).

---

## 0. Hardware and software prerequisites

| Item | Action |
|---|---|
| Camera | Canon EOS RP, fully charged battery, blank-formatted SD card inserted. |
| Lens | Canon RF 24-105 mm F4-7.1 IS STM at 50 mm. Lens AF/MF switch = **MF**. Lens IS switch = **OFF**. Zoom ring taped at 50 mm. |
| Camera dial | Mode = **M**. |
| Connection | USB-C from camera to MacBook. Camera **off** before plugging in. Turn the camera on **after** the cable is seated. |
| EOS Utility 3 | Must **not** be running. Quit it from the menu bar if you see it. |
| Light box | Fotodiox box LEDs on for ≥ 20 minutes before the first capture (warm-up). |
| Backdrop | BWblue broadcloth, taped flat to the jig surface. |
| ColorChecker | X-Rite ColorChecker Classic, fixed to the right edge of an A3 sheet. Do not move it between cases within a session. |

See [`docs/camera_setup_checklist.md`](camera_setup_checklist.md) for the one-page setup list.

---

## 1. Per-session preflight (once per session)

1. Stage the jig, the A3 sheet, and the ColorChecker on the light-box floor.
2. Confirm the camera optical axis is normal to the sample plane (use a bubble level if you have one).
3. Confirm the camera reports the lens as `RF24-105mm F4-7.1 IS STM` at 50 mm.
4. Run the preflight:
   ```bash
   cd /path/to/fabric-image-capture
   ./scripts/camera/preflight_camera.sh
   ```
5. Watch the output. Every parameter line should end in `OK`. If any line shows `ERROR`, fix the issue (most often EOS Utility 3 is running, or a previous gphoto2 process is still holding the USB) and re-run.

The preflight writes a log to `data/raw/camera_sessions/YYYY-MM-DD/preflight_YYYY-MM-DD-HHMMSS.log`.

If you want to read current camera values without writing anything:

```bash
./scripts/camera/preflight_camera.sh --dry-run
```

---

## 2. Per-case acquisition

For each specimen-stage pair you need to capture:

### 2a. Stage the case on the jig

1. Place the specimen on the BWblue backdrop, **front face up**.
2. Orient the specimen so its top edge (the side with the `C###-top` handwritten label, or the stitched-fiducial edge on a coupon strip) points toward the **top** of the A3 sheet.
3. Keep the ColorChecker at the **right edge** of the A3 sheet. Do not move it between cases.
4. Check that the specimen lies flat — no curling at the edges.

### 2b. Fire the acquisition

```bash
./scripts/camera/acquire_case.sh \
    --test      C187 \
    --coupon    parent \
    --treatment none \
    --stage     pre_exposure
```

See [`docs/vocabulary.md`](vocabulary.md) for the allowed values of each flag and worked examples.

### 2c. What happens during the run

1. The script captures **frame 1** at 0°. Each frame uses a 2 s self-timer — keep your hands clear of the camera and tripod.
2. The script captures **frame 2** at 0°.
3. The script prints a prompt:
   ```
   [acquire_case] PAUSE  ── rotate the specimen 180° (in-plane), keep the
                          ColorChecker at the right edge of the A3 sheet.
                  After the rotation, press <enter> to continue.
   ```
4. You physically rotate the specimen 180° in the jig plane. The ColorChecker normally has to be lifted out of the rotation arc and re-placed at the right edge of the A3 sheet afterwards — that is fine. Do not try to put the ColorChecker, the A3 sheet, or the specimen back in *exactly* the same image-space position. An honest re-placement (ColorChecker at the right edge, specimen flat) is all that matters.
5. Press **enter** at the terminal.
6. The script captures **frames 3 and 4** at 180°.
7. The script writes a `case_manifest.json` next to the captured frames listing all four basenames.

### 2d. Where the captures land

Example for `--test C187 --coupon parent --treatment none --stage pre_exposure`, run at 10:45:30 on 2026-05-21:

```
data/raw/camera_sessions/2026-05-21/
└── C187_parent_none_pre_exposure_104530/
    ├── case_manifest.json
    ├── rot_0deg/
    │   ├── 2026-05-21-104538_C187_parent_none_pre_exposure_0deg_r01.cr3
    │   ├── 2026-05-21-104538_C187_parent_none_pre_exposure_0deg_r01.jpg
    │   ├── 2026-05-21-104538_C187_parent_none_pre_exposure_0deg_r01.log
    │   ├── 2026-05-21-104546_C187_parent_none_pre_exposure_0deg_r02.cr3
    │   └── ...
    └── rot_180deg/
        ├── 2026-05-21-104632_C187_parent_none_pre_exposure_180deg_r01.cr3
        └── ...
```

Each `.cr3` is the raw image. The matching `.jpg` is the in-camera small preview (used only for quick visual QC). The matching `.log` is the per-capture audit trail and is part of the project record.

### 2e. After each case

1. Remove the specimen from the jig.
2. Stage the next case and repeat from step 2a.

---

## 2-B. Multi-piece batch acquisition (`acquire_batch.sh`)

When several fabric pieces are staged together on one paper and photographed in a single frame, use `acquire_batch.sh` instead of the per-case driver — **one command per paper**, regardless of how many pieces are on it. Pieces are identified by sample ID + sub ID: `C205-1` is piece 1 of combustion test C205. Mixed states on one paper are allowed — each position declares its own (piece ID, treatment, stage) tuple.

Batch frames are captured at **0° only** — there is no 180° rotation pass (protocol decision, 2026-07-13). The four-frame rotation protocol applies to single-sample cases, not batch papers.

### 2-B.a Stage the batch on the jig

1. Place the pieces on the BWblue backdrop, front face up, tops up (piece label or stitched-fiducial edge toward the top of the sheet).
2. Arrange them in the order you will declare on the command line: **reading order — top-left → right, row-major** (like reading a page).
3. Keep the ColorChecker at the right edge of the sheet, as for single cases.
4. Verify every piece lies flat with no curling and no overlap.

### 2-B.b Fire the acquisition

```bash
./scripts/camera/acquire_batch.sh \
    --sample C205-1:none:pre_exposure \
    --sample C205-2:none:pre_exposure \
    --sample C205-3:none:pre_exposure \
    --sample C205-4:none:pre_exposure \
    --sample C205-5:none:pre_exposure
```

Each `--sample` is `<pieceID>:<treatment>:<stage>`. The piece ID must match `C<test>-<sub>` (sub = positive integer); treatment and stage use the same controlled vocabulary as `acquire_case.sh` (see [`docs/vocabulary.md`](vocabulary.md) — the coupon axis does not apply to batch pieces).

**Tuple syntax — one word, no spaces.** Each `--sample` value must be a single shell word with no spaces around the colons. A space after a colon splits the tuple into separate arguments and the script aborts with `unknown argument: …`. When continuing a command across lines, keep a space before each trailing `\`:

```
❌  --sample C205-2: as_exposed: post_exposure     # spaces break the tuple
❌  --sample C205-1:as_exposed:post_exposure\      # '\' glued to the text joins
                                                   # this line with the next
✅  --sample C205-1:as_exposed:post_exposure \
```

**Allowed treatment × stage combinations** (any other pair is rejected):

| Stage | Allowed treatment(s) | Piece state being photographed |
|---|---|---|
| `pre_exposure` | `none` | before any smoke exposure |
| `post_exposure` | `as_exposed` | straight out of the smoke chamber |
| `post_exposure_aged` | `env_aging_<N>d` | after an N-day environmental aging step |
| `post_treatment` | `as_exposed`, `env_aging_<N>d`, `PER`, `advanced_cleaning` | after its most-recent treatment (`none` not allowed) |

So a paper of five as-exposed pieces of C205 is:

```bash
./scripts/camera/acquire_batch.sh \
    --sample C205-1:as_exposed:post_exposure \
    --sample C205-2:as_exposed:post_exposure \
    --sample C205-3:as_exposed:post_exposure \
    --sample C205-4:as_exposed:post_exposure \
    --sample C205-5:as_exposed:post_exposure
```

Optional flags:

| Flag | Default | Purpose |
|---|---|---|
| `--reps N`   | 2 | Frames to capture, all at 0°. |
| `--name SLUG`| `batch_<sampleID>` (single sample) or `batch_<first>-<last>` | Batch folder / label slug. |
| `--paper NAME` | `a3` | Sheet identifier recorded in the manifest. |
| `--self-test` | off | Print the layout table and planned frames without firing. |

The script prints the numbered layout table and pauses for `<enter>`. **Check the physical placement against the table before confirming** — this confirmation is the only check that positions and identities agree; the manifest it produces is the only link between pixels and piece identity.

### 2-B.c Filenames produced per batch

```
data/raw/camera_sessions/2026-07-13/
└── batch_C205_105447/
    ├── batch_manifest.json      <- position → identity table + frame list
    ├── 2026-07-13-105502-batch_C205_r01.cr3
    ├── 2026-07-13-105502-batch_C205_r01.jpg
    ├── 2026-07-13-105502-batch_C205_r01.log
    ├── 2026-07-13-105512-batch_C205_r02.cr3
    └── ...
```

The analysis side currently extracts one specimen per frame, so batch frames are acquisition-only for now — the manifest's `positions` array and `reading_order` field carry everything a future multi-piece split needs. Getting the declared order right at capture time is therefore critical.

---

## 3. Which flag combinations to use

The shape of `acquire_case.sh` always boils down to choosing four values. The two combinations you will see most often:

| When | `--coupon` | `--treatment` | `--stage` |
|---|---|---|---|
| Parent specimen straight out of the conditioning chamber (before any smoke exposure) | `parent` | `none` | `pre_exposure` |
| Parent specimen immediately after the smoke chamber (still uncut) | `parent` | `as_exposed` | `post_exposure` |

The full set of allowed combinations and worked examples is in [`docs/vocabulary.md`](vocabulary.md).

---

## 4. End-of-session checks

When all cases for the session are captured:

1. Power off the camera (or unplug the USB cable).
2. Open the dated folder under `data/raw/camera_sessions/YYYY-MM-DD/` and skim the `.log` files for any line starting with `ERROR`. Flag those captures to Fan.
3. Copy the entire dated folder to the lab storage drive (location provided by Fan). The captured `.cr3`, `.jpg`, and `.log` files are **not** committed to git; the storage drive is the authoritative copy.
4. Message Fan when the upload is done.

---

## 5. The whole workflow on one screen

```
Per session (once):
    ./scripts/camera/preflight_camera.sh

Per case (n times):
    Stage specimen on BWblue backdrop, top edge up, ColorChecker at right of A3.
    ./scripts/camera/acquire_case.sh \
        --test C### \
        --coupon  {parent | left | center | right
                   | left_center | center_right | left_center_right} \
        --treatment {none | as_exposed | env_aging_<N>d | PER | advanced_cleaning} \
        --stage   {pre_exposure | post_exposure | post_exposure_aged | post_treatment}
    <when prompted, rotate the specimen 180° and press enter>
    Remove specimen, stage next case.

Per batch paper (several pieces in one frame, 0° only):
    Stage pieces in reading order (top-left → right, row-major), tops up,
    ColorChecker at right of the sheet.
    ./scripts/camera/acquire_batch.sh \
        --sample C###-1:<treatment>:<stage> \
        --sample C###-2:<treatment>:<stage> \
        ...
    <check the layout table against the paper, then press enter>
    Remove pieces, stage next paper.

After session:
    Skim *.log files for ERROR.
    Copy data/raw/camera_sessions/<DATE>/ to lab storage drive.
    Message Fan.
```
