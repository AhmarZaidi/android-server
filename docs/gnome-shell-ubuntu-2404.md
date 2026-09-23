# Isolated Ubuntu 24.04 GNOME Shell

This trial installs a separate Ubuntu 24.04.5 LTS ARM64 rootfs under the
`ubuntu-gnome-2404` alias. It does not install packages in, edit, stop, or
remove the existing `ubuntu` environment. The current XFCE session remains on
display `:1` / port `5901`; the installed GNOME Flashback trial remains on
display `:2` / port `5902`.

The first transport test uses TigerVNC on display `:3` / port `5903`. The
session runs GNOME Shell 46 in X11 mode with Activities, the overview, dynamic
workspaces, the Ubuntu dock, GNOME Settings, Nautilus, and GNOME Terminal.
Software rendering is enabled initially because it is the safest baseline in
Android PRoot.

## Resource estimate

- Download and installation: usually 45–90 minutes on this device and network.
- Final disk use: approximately 2–3.5 GiB.
- Required free-space safety margin: 6 GiB.
- The environment has its own installed packages and system configuration.
  Selected project directories can be bind-mounted later, after the desktop
  transport is stable.

The installer uses the official
[Ubuntu Base 24.04.5 ARM64 archive](https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/)
and pins its SHA-256 checksum. The desktop is Ubuntu Noble's
[GNOME Shell package](https://packages.ubuntu.com/noble/arm64/gnome-shell).

## Install

All commands in this section run in **native Termux**, where `whoami` returns
the Android app user (for example `u0_a468`) and `$PREFIX` is
`/data/data/com.termux/files/usr`.

```bash
cd ~/gnome-shell-2404
./setup-gnome-shell-ubuntu-2404.sh
```

The script checks for at least 6 GiB free, refuses to touch an unknown rootfs,
and asks for a dedicated VNC password near the end. It is safe to rerun after
a completed installation; it resumes only when its marker exists.

## Start and connect

From native Termux:

```bash
ugnomefull
```

The server binds only to `localhost:5903`. Continue using the SSH port forward
from the laptop, changing its target to port `5903`, then connect the VNC
client to `localhost:5903`.

Stop only this GNOME session with:

```bash
ugnomefullstop
```

XFCE and this session use separate VNC displays and may run at the same time.
They still share the phone's CPU, RAM, GPU, and thermal limits, so simultaneous
use can reduce performance.

If startup fails, inspect the native launcher log:

```bash
cat ~/.local/state/gnome-shell-ubuntu-2404/server.log
```

The launcher also prints the end of TigerVNC's guest log after a failed start.

## Complete rollback

Stop and remove only the isolated environment from native Termux:

```bash
ugnomefullremove --confirm
```

This deletes the `ubuntu-gnome-2404` rootfs and data stored inside it, its
dedicated `proot-distro` plug-in, three launch commands, and its launcher log.
It checks the private marker before deletion and refuses an unrecognized
rootfs. It does not remove either the existing `ubuntu` rootfs or the GNOME
Flashback packages previously added there.

## Transport fallback

If GNOME Shell itself works but TigerVNC is visually incomplete or too slow,
keep this rootfs and replace only its display path with Termux:X11 plus VirGL.
Termux:X11 officially supports PRoot sessions through `--shared-tmp`; remote
access can then be layered through `x11vnc` or Android screen streaming. That
phase is intentionally deferred until the VNC result is measured, so the first
test adds no Android app, display service, or remote-access dependency.
