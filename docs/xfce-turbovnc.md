# XFCE TurboVNC trial

This trial adds TurboVNC beside the existing TigerVNC setup. It uses the same Ubuntu environment and `desktop` home directory, but it has separate commands, display, state, and TCP port.

| Path | Existing TigerVNC | TurboVNC trial |
|---|---:|---:|
| Start command | `ugui ...` | `uturbo` |
| Stop command | `uguistop` | `uturbostop` |
| X display | `:1` | `:5` |
| Localhost port | `5901` | `5905` |
| Server installation | Ubuntu packages | `/opt/TurboVNC` |

Do not run the two XFCE sessions concurrently. They use the same home directory, so simultaneous XFCE settings daemons can overwrite each other's settings. Save work and stop one server before starting the other.

## Install the ARM64 server

Run inside the existing Ubuntu PRoot:

```bash
cd ~/Coding/android-server
./scripts/install-xfce-turbovnc.sh
```

The installer downloads the official TurboVNC 3.3 AArch64 RPM and verifies its SHA-256 checksum before extracting only its `/opt/TurboVNC` installation. It does not replace TigerVNC packages. It reuses the existing VNC password when available and installs `uturbo` and `uturbostop` into native Termux's `~/.local/bin`.

## Start the trial

Save work in XFCE, then run these commands from native Termux:

```bash
uguistop
uturbo
```

Create a separate Windows SSH tunnel:

```powershell
ssh -N -L 5905:127.0.0.1:5905 -p 8022 u0_a468@sanders.lan
```

Install the official TurboVNC 3.3 Windows viewer, then connect from PowerShell:

```powershell
& 'C:\Program Files\TurboVNC\vncviewer.bat' `
  -FullScreen `
  -DesktopSize Server `
  -Scale FixedRatio `
  -Encoding Tight `
  -CompressLevel 1 `
  -JPEG `
  -Quality 80 `
  -Subsampling 2X `
  127.0.0.1::5905
```

This mixed-workload profile uses multithreaded Tight/JPEG encoding without the extra CPU cost of interframe comparison. It favors responsive motion while retaining better text quality than a low-quality video-only preset.

## Return to TigerVNC

Close the TurboVNC viewer and run in native Termux:

```bash
uturbostop
ugui ultra
```

No package removal or configuration restoration is needed to return to TigerVNC.
