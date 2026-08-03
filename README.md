# Fabric Image Capture

Operator-facing repo for capturing fabric specimen photographs with a Canon EOS RP tethered to a MacBook over USB-C. You will run a per-session preflight that pushes a fixed camera profile, then either a per-case acquisition that shoots four replicate frames of one specimen (two at 0°, two after a 180° rotation) or a batch acquisition that shoots several pieces staged on one paper in a single frame (0° only). Captured images are written to `data/raw/camera_sessions/` and handed off to the research team for analysis.

## Prerequisites

Hardware:

- Canon EOS RP body
- Canon RF 24-105 mm F4-7.1 IS STM lens
- MacBook with a USB-C port and a USB-C to USB-C cable
- Fotodiox light tent with LED panels
- X-Rite ColorChecker Classic, permanently mounted at the right edge of an A3 sheet
- BWblue cotton broadcloth backdrop, taped flat on the jig surface
- One sheet of A3 paper (297 × 420 mm) as the substrate underneath every specimen

Software:

- macOS **Monterey (12.0)** or newer
- Xcode Command Line Tools (`xcode-select --install`)
- [Homebrew](https://brew.sh)
- `gphoto2` (`brew install gphoto2`)
- `python3` (preinstalled on macOS Monterey+)

If this is the first time the MacBook has been set up for this study, walk through [`docs/environment_setup.md`](docs/environment_setup.md) once — it covers Homebrew, gphoto2, macOS permissions, sleep / notification settings, and an optional permanent fix for the `ptpcamerad` USB-claim race.

You must **quit EOS Utility 3** before running anything. Only one process can own the camera over USB at a time, and the scripts refuse to run while EOS Utility is open.

## Quick start

1. Clone this repo and `cd` into it.
   ```bash
   git clone <repo-url> fabric-image-capture
   cd fabric-image-capture
   ```
2. Plug the camera into the MacBook with USB-C **while the camera is off**, then power the camera on.
3. Run the per-session preflight (once per session):
   ```bash
   ./scripts/camera/preflight_camera.sh
   ```
4. Stage the specimen (or the batch paper) on the jig and run the matching capture script — see [Which script do I use?](#which-script-do-i-use) just below.

## Which script do I use?

There are two capture scripts. Pick by what is physically in the frame:

| What is in the frame | Script | Frames captured |
|---|---|---|
| **One** specimen alone — identified without a sub number, e.g. parent `C187` or one coupon strip | `acquire_case.sh` | 4 per case: 2 at 0°, then 2 after you rotate the specimen 180° |
| **Several** sub-numbered pieces of one test staged together on one paper, e.g. `C205-1` … `C205-5` | `acquire_batch.sh` | 2 per paper (default), all at 0° — no rotation |

A single sub-numbered piece alone in the frame is supported by neither script — message Fan if you run into that.

### Mode 1 — one specimen per frame: `acquire_case.sh`

Identify the specimen with four flags (see [`docs/vocabulary.md`](docs/vocabulary.md) for every allowed value and more worked examples):

```bash
./scripts/camera/acquire_case.sh \
    --test C187 \
    --coupon parent \
    --treatment none \
    --stage pre_exposure
```

Keep a space before each trailing `\` — it tells the shell the command continues on the next line.

The script shoots two frames, prompts you to physically rotate the specimen 180° and press enter, then shoots two more. Captures land under:

```
data/raw/camera_sessions/YYYY-MM-DD/<case_slug>_<HHMMSS>/
  case_manifest.json
  rot_0deg/    2 frames (.cr3 + .jpg + .log each)
  rot_180deg/  2 frames (.cr3 + .jpg + .log each)
```

Full procedure: [`docs/acquisition_workflow.md`](docs/acquisition_workflow.md) § 2.

### Mode 2 — several pieces on one paper: `acquire_batch.sh`

Stage the pieces in **reading order** — top-left → right, row-major, tops up, ColorChecker at the right edge of the sheet. Then declare each piece as one `--sample <pieceID>:<treatment>:<stage>` tuple, in that same order — **one command per paper**, however many pieces are on it:

```bash
./scripts/camera/acquire_batch.sh \
    --sample C205-1:none:pre_exposure \
    --sample C205-2:none:pre_exposure \
    --sample C205-3:none:pre_exposure
```

Each tuple is one shell word — no spaces around the colons (`C205-1: none: pre_exposure` breaks the command). Treatment and stage use the same vocabulary as `acquire_case.sh`.

The script echoes a numbered layout table and waits for enter. **Check the physical placement against that table before confirming** — the manifest it writes is the only record of which piece sits at which position in the frame. Captures land under:

```
data/raw/camera_sessions/YYYY-MM-DD/<batch_slug>_<HHMMSS>/
  batch_manifest.json      <- position → identity table + frame list
  <date>-<time>-<batch_slug>_r01.{cr3,jpg,log}
  <date>-<time>-<batch_slug>_r02.{cr3,jpg,log}
```

Not sure the placement is right? Add `--self-test` to the end of the command to print the layout table and planned frames without firing the camera.

Full procedure: [`docs/acquisition_workflow.md`](docs/acquisition_workflow.md) § 2-B.

## Per-session workflow

For full detail see [`docs/acquisition_workflow.md`](docs/acquisition_workflow.md). The short version:

1. Warm up the light-box LEDs for at least 20 minutes.
2. Confirm the lens AF/MF switch is at **MF**, the lens IS switch is at **OFF**, the mode dial is at **M**, and the zoom ring is taped at 50 mm. See [`docs/camera_setup_checklist.md`](docs/camera_setup_checklist.md) for the full one-page setup list.
3. Plug in the camera, power it on, keep EOS Utility 3 closed.
4. Run `./scripts/camera/preflight_camera.sh`. Read the on-screen banner. Every parameter line should end in `OK`.
5. For each specimen-stage pair, run `./scripts/camera/acquire_case.sh` with the right four CLI flags. For a multi-piece paper, run `./scripts/camera/acquire_batch.sh` with one `--sample` tuple per piece.
6. At the end of the session, power off the camera and copy the day's `data/raw/camera_sessions/<DATE>/` folder to the lab storage drive.

## Vocabulary

`acquire_case.sh` takes four CLI flags: `--test`, `--coupon`, `--treatment`, `--stage`. `acquire_batch.sh` reuses the same `--treatment` and `--stage` values inside its `--sample` tuples. See [`docs/vocabulary.md`](docs/vocabulary.md) for the allowed values, a one-line meaning for each, and worked examples covering the combinations you will see in your first week.

## Troubleshooting

If anything refuses to capture, see [`docs/troubleshooting.md`](docs/troubleshooting.md). The most common issues are EOS Utility 3 being open, the macOS PTPCamera daemon claiming the USB device, and a power-cycle being needed after a long pause.

## What to do with captured images

- Captured `.cr3` and `.jpg` files are **not** committed to git — the `.gitignore` blocks them. The same goes for the `.log` files alongside each capture.
- At the end of each session, copy the dated folder `data/raw/camera_sessions/YYYY-MM-DD/` to the lab storage drive (location provided by Fan).
- Email or message Fan when the day's captures are uploaded so the analysis side can ingest them.

## License / authorship

Internal Iowa State University lab tool. Primary contact: Fan Zhou &lt;fanzhou@iastate.edu&gt;.
