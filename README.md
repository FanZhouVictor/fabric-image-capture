# Fabric Image Capture

Operator-facing repo for capturing fabric specimen photographs with a Canon EOS RP tethered to a MacBook over USB-C. You will run a per-session preflight that pushes a fixed camera profile, then a per-case acquisition that shoots four replicate frames of one specimen (two at 0°, two after a 180° rotation). Captured images are written to `data/raw/camera_sessions/` and handed off to the research team for analysis.

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
4. Stage one specimen on the jig and acquire its four frames:
   ```bash
   ./scripts/camera/acquire_case.sh \
       --test C187 
       --coupon parent 
       --treatment none 
       --stage pre_exposure
   ```
   The script captures two frames, then prompts you to physically rotate the specimen 180° and press enter, then captures two more.
5. Captured images land under `data/raw/camera_sessions/YYYY-MM-DD/<case>_HHMMSS/rot_0deg/` and `rot_180deg/`.

## Per-session workflow

For full detail see [`docs/acquisition_workflow.md`](docs/acquisition_workflow.md). The short version:

1. Warm up the light-box LEDs for at least 20 minutes.
2. Confirm the lens AF/MF switch is at **MF**, the lens IS switch is at **OFF**, the mode dial is at **M**, and the zoom ring is taped at 50 mm. See [`docs/camera_setup_checklist.md`](docs/camera_setup_checklist.md) for the full one-page setup list.
3. Plug in the camera, power it on, keep EOS Utility 3 closed.
4. Run `./scripts/camera/preflight_camera.sh`. Read the on-screen banner. Every parameter line should end in `OK`.
5. For each specimen-stage pair, run `./scripts/camera/acquire_case.sh` with the right four CLI flags.
6. At the end of the session, power off the camera and copy the day's `data/raw/camera_sessions/<DATE>/` folder to the lab storage drive.

## Vocabulary

`acquire_case.sh` takes four CLI flags: `--test`, `--coupon`, `--treatment`, `--stage`. See [`docs/vocabulary.md`](docs/vocabulary.md) for the allowed values, a one-line meaning for each, and worked examples covering the combinations you will see in your first week.

## Troubleshooting

If anything refuses to capture, see [`docs/troubleshooting.md`](docs/troubleshooting.md). The most common issues are EOS Utility 3 being open, the macOS PTPCamera daemon claiming the USB device, and a power-cycle being needed after a long pause.

## What to do with captured images

- Captured `.cr3` and `.jpg` files are **not** committed to git — the `.gitignore` blocks them. The same goes for the `.log` files alongside each capture.
- At the end of each session, copy the dated folder `data/raw/camera_sessions/YYYY-MM-DD/` to the lab storage drive (location provided by Fan).
- Email or message Fan when the day's captures are uploaded so the analysis side can ingest them.

## License / authorship

Internal Iowa State University lab tool. Primary contact: Fan Zhou &lt;fanzhou@iastate.edu&gt;.
