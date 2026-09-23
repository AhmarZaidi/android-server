# Isolated Ubuntu 24.04 GNOME Shell

This setup installs a separate Ubuntu 24.04.5 LTS ARM64 rootfs under the `ubuntu-gnome-2404` alias. It does not modify the original Ubuntu/XFCE environment. XFCE remains on display `:1` and GNOME Flashback remains on display `:2`.

The dependable desktop path is GNOME Shell 46 in X11 mode through TigerVNC on display `:3`, localhost port `5903`. It uses Mesa software rendering because GNOME compositing through VirGL did not produce a capturable framebuffer in either Xvnc or Termux:X11 on this device.

## Install or refresh

Run in native Termux:

```bash
cd ~/gnome-shell-2404
./setup-gnome-shell-ubuntu-2404.sh
```

The installer is resumable. On an existing environment it refreshes the GNOME startup wrapper, installs the complete Yaru and Adwaita icon sets plus Ubuntu, Cantarell, and emoji fonts, rebuilds their caches, and preserves the existing VNC password.

## Start and stop

Run in native Termux:

```bash
ugnomefull
```

Stop only this session with:

```bash
ugnomefullstop
```

The default framebuffer is 1280x720 at 96 DPI and scale 1. Override it for a launch with, for example:

```bash
GNOME_VNC_GEOMETRY=1920x1080 ugnomefull
```

## TigerVNC viewer quality

Lossy JPEG encoding and client-side enlargement can make icons look pixelated even when the guest rendered them correctly. For the local SSH-forwarded connection, use full color, Tight encoding, JPEG disabled, and no remote resizing. A ready profile is stored at `config/tigervnc/gnome-local.tigervnc`.

Equivalent viewer options are:

```text
Auto select: off
Encoding: Tight
Color level: Full
Custom compression: on, level 1
Allow JPEG compression: off
Remote resize: off
```

Display the 1280x720 framebuffer at 100% scale when judging icon sharpness. Increase `GNOME_VNC_GEOMETRY` if a larger native framebuffer is needed.

## Current rendering status

The session explicitly enables GNOME animations, uses the Yaru GTK, shell, cursor, and icon themes, fixes scale and DPI, and enables dynamic workspaces. Animation smoothness remains limited by CPU software rendering and VNC update latency, but transitions should be present rather than disabled.

The Termux:X11 and scrcpy path remains an experimental diagnostic path. It displays the X server cursor but not GNOME Shell's compositor output on this device, so it is not the default.

## Future remote access

The planned transport selector can use the same TigerVNC desktop backend: connect directly over the local SSH tunnel when the phone is reachable, fall back to noVNC through Cloudflare Tunnel when it is not, and accept a flag to force either route for testing.

## Rollback

Run in native Termux:

```bash
ugnomefullremove --confirm
```

This removes only the isolated `ubuntu-gnome-2404` environment and its launchers.
