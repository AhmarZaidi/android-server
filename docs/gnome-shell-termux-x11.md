# Accelerated GNOME through Termux:X11

This optional transport reuses the isolated `ubuntu-gnome-2404` rootfs. It
does not alter the existing `ubuntu` / XFCE environment or replace the working
software-rendered GNOME VNC launcher.

The display path is:

```text
GNOME Shell -> Mesa virpipe -> native VirGL -> Termux:X11 :4
            -> x11vnc localhost:5904 -> SSH tunnel -> TigerVNC Viewer
```

TigerVNC/Xvnc remains on port `5903` as the safe software-rendered fallback.
Only one GNOME mode should run at a time.

## Setup

Run from native Termux:

```bash
cd ~/gnome-shell-2404
./setup-gnome-shell-termux-x11.sh
```

The setup adds `x11vnc` and `x11-utils` only inside the isolated GNOME rootfs,
then installs `ugnomex11` and `ugnomex11stop` into the native Termux command
path. The existing VNC password is reused.

## Start and connect

```bash
ugnomex11
```

The launcher temporarily sets Termux:X11 to 1280x720, starts display `:4`,
starts or reuses the native VirGL server, launches GNOME with `virpipe`, and
exposes the rendered display through `x11vnc` bound to localhost port `5904`.

On Windows, forward the new port:

```powershell
ssh -N -L 5904:127.0.0.1:5904 -p 8022 u0_a468@sanders.lan
```

Connect TigerVNC Viewer to `localhost:5904`.

Stop this mode with:

```bash
ugnomex11stop
```

Stopping closes the Termux:X11 app and restores the Termux:X11 preferences
captured before launch. It leaves the VirGL server running because other PRoot
desktops may share it.

Logs are stored under:

```text
~/.local/state/gnome-shell-termux-x11/
```

If this transport fails, stop it and return to the independent software mode:

```bash
ugnomex11stop
ugnomefull
```
