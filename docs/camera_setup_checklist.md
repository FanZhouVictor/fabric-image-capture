# Camera setup checklist

Walk through this list **in order** at the start of every shooting session. The preflight script (`./scripts/camera/preflight_camera.sh`) pushes the scriptable settings automatically — the rows below are the ones you must confirm on the camera body, the lens, or in the camera menu by hand. Most of them stay set between sessions; once correct, they only need a glance.

If a value has drifted from the column on the right, return it to the listed value before continuing.

| # | Setting | Value | Where to set it |
|---|---|---|---|
| 1 | Mode dial | **M** | Top mode dial on the camera body |
| 2 | Focus mode | **MF** | Quick menu → AF operation → MF; *and* the lens ring switch on the barrel → **Focus** (not Control) |
| 3 | Lens IS switch | **OFF** | `STABILIZER` switch on the lens barrel |
| 4 | Lens zoom ring | **50 mm, taped in place** | Rotate to 50 mm, wrap gaffer tape around the zoom ring |
| 5 | Lens hood | **Attached** | Twist-lock the matching hood onto the front of the lens |
| 6 | SD card | **Inserted and formatted in-camera** | `MENU → SET UP1 → Format card`; also confirm `MENU → SHOOT1 → Release shutter w/o card = Disable` |
| 7 | Power source | **DC coupler on mains** (preferred) **or** fully-charged LP-E17 battery | Camera battery door |
| 8 | USB-C cable | Camera **off** when plugging in, **on** afterwards | Side port under the rubber cover labelled `DIGITAL` |
| 9 | Anti-flicker shooting | **Enable** | `MENU → SHOOT3 → Anti-flicker shoot.` |
| 10 | Shutter mode | **Elec. 1st-curtain** | `MENU → SHOOT3 → Shutter mode` (if hidden, EFCS is already the default) |
| 11 | In-camera tone/noise adjustments | **All Disable / OFF** | `MENU → SHOOT1 → Highlight tone priority = Disable`; `MENU → SHOOT3 → Long exp. noise reduction = OFF`; `MENU → SHOOT3 → High ISO speed NR = Disable`; `MENU → SHOOT2 → Auto Lighting Optimizer = Disable` |
| 12 | Lens aberration correction | **All Disable** (every sub-row OFF) | `MENU → SHOOT1 → Lens aberration correction` |
| 13 | Multi-exposure / HDR / Focus bracketing / Interval / Bulb timers | **All Disable** | `MENU → SHOOT3`, step through each entry |
| 14 | Wi-Fi / Bluetooth | **Disable** | `MENU → SET UP` wireless tab |
| 15 | Picture Style detail sliders | **Strength 0, Contrast 0, Saturation 0, Color Tone 0** | Picture Style → Neutral → press `INFO` → zero every slider |

After the rows above are confirmed, run the preflight script — it pushes ISO, aperture, shutter, WB selector, color space, Picture Style preset, image quality, metering, drive mode, capture target, exposure compensation, auto-power-off, and Auto Lighting Optimizer in one shot:

```bash
./scripts/camera/preflight_camera.sh
```

Every line of its output should end in `OK`. If any line shows `WARN` or `ERROR`, check [`docs/troubleshooting.md`](troubleshooting.md) before continuing.

## Manual focus lock (once per day, or after any rig bump)

1. Enter Live View on the camera.
2. Press the magnify button to zoom to 10× on the jig surface (a scale bar or fabric edge works).
3. Rotate the lens focus ring until the magnified view is sharpest.
4. Exit magnification **without touching the focus ring** afterwards.

The focus lock is what keeps every frame for the rest of the session on the same focal plane.
