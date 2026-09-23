# Accelerated GNOME Shell through Termux:X11

This mode runs GNOME Shell in the isolated `ubuntu-gnome-2404` environment and renders it through VirGL to the Termux:X11 Android app. It does not modify the original Ubuntu/XFCE environment.

The display path is:

```text
GNOME Shell -> virpipe -> VirGL -> Termux:X11 Android surface -> scrcpy
```

`x11vnc` was tested as a remote capture layer, but it receives an unchanged black X framebuffer because GNOME's accelerated content is presented directly to the Android surface. `scrcpy` captures that Android surface and avoids this limitation.

## Prepare the launcher

Run from native Termux:

```bash
cd ~/gnome-shell-2404
./setup-gnome-shell-termux-x11.sh
```

## Start GNOME

Run from native Termux:

```bash
ugnomex11
```

The launcher opens the Termux:X11 Android activity at 1280x720 in landscape mode and starts GNOME with the `virpipe` Mesa driver. It enables Termux:X11 legacy drawing because the standard Android presentation path produces a black surface on this device. The software VNC session on port 5903 must be stopped first.

## View it from Windows

Connect ADB and mirror the Android display from PowerShell:

```powershell
adb connect 192.168.31.249:5555
scrcpy --serial 192.168.31.249:5555 --turn-screen-off --stay-awake --window-title "GNOME Termux-X11"
```

The phone runs ADB on TCP port 5555. The first connection from a new Windows ADB key may require Android authorization.

## Stop GNOME

Run from native Termux:

```bash
ugnomex11stop
```

The software-rendered GNOME VNC mode remains available with `ugnomefull` on localhost port 5903.
