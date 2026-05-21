# Acquisition workflow

Step-by-step procedure for the operator. Read this once end-to-end before your first session. After that, you only need to keep this open as a checklist.

A **case** is one (specimen, imaging stage) pair — for example: the parent specimen C187 before exposure, or the left coupon strip after a PER treatment. `acquire_case.sh` captures all four replicate frames for one case in a single run.

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
        --coupon  {parent | left | center | right} \
        --treatment {none | as_exposed | env_aging_<N>d | PER | advanced_cleaning} \
        --stage   {pre_exposure | post_exposure | post_exposure_aged | post_treatment}
    <when prompted, rotate the specimen 180° and press enter>
    Remove specimen, stage next case.

After session:
    Skim *.log files for ERROR.
    Copy data/raw/camera_sessions/<DATE>/ to lab storage drive.
    Message Fan.
```
