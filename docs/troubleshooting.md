# Troubleshooting

If a script refuses to run or a capture fails, work through the matching section below. Each section ends with a one-line fix. If none of them resolves the issue, message Fan with the **exact** error line from the terminal.

## 1. `gphoto2: Could not claim the USB device (-53)`

macOS's `ptpcamerad` LaunchAgent is winning the USB race against `gphoto2`. The scripts already evict the agent and retry up to three times automatically. If you still see this error after three attempts:

```bash
# Unplug the USB cable, wait three seconds, replug, then re-run.
```

To make the eviction permanent for this user account on this Mac (one-time):

```bash
launchctl disable gui/$(id -u)/com.apple.ptpcamerad
launchctl bootout  gui/$(id -u)/com.apple.ptpcamerad
```

## 2. `EOS Utility 3 is running`

Only one process can own the camera over USB. The scripts refuse to run while EOS Utility 3 is open.

```bash
# Quit EOS Utility from the macOS menu bar (right-click the dock icon → Quit), then re-run.
```

## 3. `Canon EOS RP not found`

The camera is not visible to gphoto2.

```text
Fix order:
  1. Check the USB-C cable is fully seated on both ends.
  2. Check the camera is powered ON.
  3. Camera must be turned OFF before plugging in, then ON after the cable is seated.
  4. Quit Image Capture, Photos, or any other app that auto-grabs cameras on connect.
  5. Unplug, wait 3 s, replug. Re-run.
```

## 4. Captures are saved to a weird date subfolder

This was a known bug fixed on 2026-05-15. `capture.sh` and `acquire_case.sh` now write directly to `rot_0deg/` and `rot_180deg/` under the case folder, with no extra date layer in between. If you see captures landing in `rot_*deg/<DATE>/...`, you are running an old copy — re-pull the repo.

## 5. Shutter does not fire

```text
Check in order:
  1. Battery is charged, or the DC coupler is on mains.
  2. An SD card is inserted (the script will not capture without one).
  3. The mode dial is at M.
  4. The lens AF/MF switch (or camera AF mode) is set to MF.
  5. Camera is awake. If Auto Power Off triggered, half-press the camera shutter to wake it, then re-run.
```

## 6. Where did my captures go?

Captures for one case land here:

```
data/raw/camera_sessions/<DATE>/<case_slug>_<HHMMSS>/
  case_manifest.json
  rot_0deg/   2 frames (.cr3 + .jpg + .log each)
  rot_180deg/ 2 frames (.cr3 + .jpg + .log each)
```

The `case_manifest.json` next to the rotation folders lists every captured basename for that case. Open it with any text editor if you want to confirm all four frames are there before you tear down the jig.
