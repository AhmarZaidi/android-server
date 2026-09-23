# Isolated GNOME Flashback trial

This trial installs GNOME Flashback in a new PRoot environment named
`ubuntu-gnome-flashback`. It does not install packages or change configuration
inside the existing `ubuntu` environment used by XFCE.

The trial uses TigerVNC display `:2`, TCP port `5902`, and the Metacity window
manager. The existing XFCE session remains on display `:1`, TCP port `5901`.

The installed PRoot-Distro 4.37.0 plug-in is pinned to Ubuntu 25.10. The setup
disables the plug-in's unused Mozilla PPA but otherwise retains Ubuntu's
official ARM package sources. Ubuntu 25.10 no longer receives new security
updates, so use the environment only for this local, localhost-bound desktop
evaluation.

GNOME 49 normally starts desktop components through a systemd user manager,
which PRoot does not provide. The setup therefore runs the essential Flashback
components directly in one D-Bus session: Metacity, GNOME Panel, the Flashback
helper, and the XSettings and keyboard settings services. This is a focused
compatibility trial rather than a complete GDM-managed GNOME login session.

## Before setup

- Run every command in this guide from native Termux, outside Ubuntu.
- Allow at least 6 GiB of free storage.
- Do not run the setup while another package or PRoot backup/restore operation
  is active.
- The setup downloads a fresh Ubuntu root filesystem and packages, so it can
  take a while on the phone.

## Install the trial

From the repository in native Termux:

```bash
bash scripts/setup-gnome-flashback-trial.sh
```

The script asks for a separate VNC password. Answer `n` if TigerVNC asks for a
view-only password.

The setup is resumable after a package-download or package-install failure. It
will only resume an environment carrying its own trial marker, and refuses to
modify an unrecognized directory with the same name.

## Start and connect

Start the trial from native Termux:

```bash
ugnome
```

On the client, create a separate SSH tunnel:

```powershell
ssh -N -L 5902:127.0.0.1:5902 -p 8022 u0_a468@sanders.lan
```

Connect TigerVNC Viewer to:

```text
127.0.0.1::5902
```

The existing XFCE tunnel and session can remain on port `5901`, although
running both desktops at once uses more memory. Stop XFCE first if Android is
under memory pressure.

## Stop and switch back to XFCE

Close the GNOME viewer and its port-5902 SSH tunnel, then run:

```bash
ugnomestop
```

Reconnect the usual XFCE viewer to `127.0.0.1::5901`. If XFCE was stopped,
start it with `ugui` first. Switching back does not require restoring or
changing either environment.

## Logs and checks

From native Termux:

```bash
tail -n 100 "$HOME/.local/state/gnome-flashback-trial/server.log"
```

Detailed guest VNC logs:

```bash
tail -n 100 \
  "$PREFIX/var/lib/proot-distro/installed-rootfs/ubuntu-gnome-flashback/home/desktop/.config/tigervnc/"*.log
```

Confirm that only localhost port `5902` is reachable:

```bash
timeout 3 bash -c 'exec 3<>/dev/tcp/127.0.0.1/5902' \
  && echo "GNOME VNC reachable" \
  || echo "GNOME VNC unavailable"
```

## Removing the trial later

Removal is optional. Keeping the stopped environment does not affect XFCE,
apart from its storage use. Before removal, stop the trial and verify that the
environment name is exactly `ubuntu-gnome-flashback` with
`proot-distro list`. Then it can be removed from native Termux with:

```bash
proot-distro remove ubuntu-gnome-flashback
```

That command permanently removes the trial environment. It does not target the
existing environment named `ubuntu`.
