# Environment setup

One-time setup for a fresh MacBook before you run your first capture. Work through every section once. After that, only the per-session preflight in [`acquisition_workflow.md`](acquisition_workflow.md) is needed.

If you are reusing a MacBook that has already been set up by someone else for this study, you only need to verify the **Verify** subsections.

---

## 1. Operating system

- macOS **Monterey (12.0) or newer**. Confirm with:
  ```bash
  sw_vers -productVersion
  ```
- If the Mac is older than Monterey, stop and ask Fan — earlier macOS versions ship a different USB stack that the capture scripts are not tested against.

---

## 2. Xcode Command Line Tools

Required for Homebrew. Install with:

```bash
xcode-select --install
```

Click **Install** in the dialog that appears (no full Xcode needed — only the Command Line Tools). Verify with:

```bash
xcode-select -p
# should print: /Library/Developer/CommandLineTools
```

---

## 3. Homebrew

If `brew --version` already prints a version, skip ahead. Otherwise install Homebrew with the official one-liner from <https://brew.sh>:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Follow the on-screen instructions at the end of the installer (it usually asks you to add a `eval "$(/opt/homebrew/bin/brew shellenv)"` line to your shell profile). Open a fresh terminal afterwards.

**Verify:**

```bash
brew --version
# should print: Homebrew x.y.z
```

---

## 4. gphoto2

The only project-specific dependency. Install with:

```bash
brew install gphoto2
```

**Verify:**

```bash
gphoto2 --version
# should print: gphoto2 2.x.y and a list of supported camera models
```

Run a quick camera-detection check with the camera plugged in and powered on (EOS Utility 3 closed):

```bash
gphoto2 --auto-detect
# should list: Canon EOS RP   usb:xxx,yyy
```

If the camera is not detected, see [`troubleshooting.md`](troubleshooting.md).

---

## 5. python3

The driver script `acquire_case.sh` calls `python3` once per case to write a small JSON manifest. macOS Monterey and newer ship a working `python3` out of the box.

**Verify:**

```bash
python3 --version
# should print: Python 3.x.y
```

If `python3` is missing, install it via Homebrew: `brew install python@3.12`.

---

## 6. macOS permissions and prompts

The first time the camera is plugged in:

- macOS may show **"Allow [your terminal app] to access the camera"** — click **Allow**.
- If the **Photos** app or **Image Capture** auto-launches and asks to import images — click **No** / **Stop importing** and quit those apps. They will fight `gphoto2` for the USB connection.
- If **EOS Utility 3** is installed and auto-launches when the camera connects, quit it from the menu bar. The capture scripts refuse to run while EOS Utility is open.

To stop Image Capture from auto-launching on camera connect, open the **Image Capture** app once, plug in the camera, then in the bottom-left set **"Connecting this camera opens"** to **No application**.

---

## 7. Disable macOS sleep and notifications during a session

A Mac sleep mid-session will disconnect the camera tether. Notifications can steal focus from the terminal and disrupt the capture.

- **Display / sleep:** `System Settings → Lock Screen → Turn display off on power adapter when inactive → Never`.
- **Do Not Disturb:** Click the Control Center icon in the menu bar → **Focus** → **Do Not Disturb**.
- **Caffeinate (optional, terminal-level):** Run `caffeinate -d &` at the start of a long session and `kill %1` at the end. Keeps the display on regardless of the System Settings choice.

---

## 8. (Optional but recommended) Permanently disable `ptpcamerad`

macOS has a per-user LaunchAgent called `ptpcamerad` that wakes up every time a camera is connected and races `gphoto2` for the USB device, producing `Could not claim the USB device (-53)` errors. The capture scripts already evict it on every run and retry up to three times, but you can disable it permanently for your user account so the eviction is one-shot:

```bash
launchctl disable gui/$(id -u)/com.apple.ptpcamerad
launchctl bootout  gui/$(id -u)/com.apple.ptpcamerad
```

**Side effect:** Image Capture and Photos will no longer auto-import from cameras until you re-enable the agent. This is the explicit goal during a tethered shoot.

To revert (next time you want Image Capture's auto-import back):

```bash
launchctl bootstrap gui/$(id -u) /System/Library/LaunchAgents/com.apple.ptpcamerad.plist
launchctl enable    gui/$(id -u)/com.apple.ptpcamerad
```

---

## 9. Final dry-run

After all of the above, plug in the camera, power it on, and run the preflight in dry-run mode:

```bash
cd /path/to/fabric-image-capture
./scripts/camera/preflight_camera.sh --dry-run
```

`--dry-run` reads current camera values without writing anything. A clean run means the environment is good and you are ready to follow [`acquisition_workflow.md`](acquisition_workflow.md) for the first real session.

---

## Quick reference — what you should be able to run

```bash
sw_vers -productVersion   # macOS 12.0 or newer
xcode-select -p           # /Library/Developer/CommandLineTools
brew --version            # Homebrew x.y.z
gphoto2 --version         # gphoto2 2.x.y
python3 --version         # Python 3.x.y
gphoto2 --auto-detect     # lists Canon EOS RP
```
