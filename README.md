# Sanders Ubuntu GUI

Sanders is an Android phone repurposed as a small home server. This project documents how to add an optional remote Linux desktop to its existing Termux and Ubuntu PRoot setup.

The desktop uses XFCE because it is lightweight enough for a phone while still providing a familiar graphical environment. TigerVNC carries the desktop session, and an SSH tunnel keeps remote access private without exposing a VNC port directly to the network.

## What this provides

- A familiar Ubuntu desktop accessible from another computer
- A separate `desktop` user inside the existing Ubuntu PRoot
- Manual start and stop commands, so the GUI consumes resources only when needed
- Encrypted access through the server's existing SSH connection
- No changes to the existing Tuvu application, status monitor, battery alerts, or SSH service

## How it works

```text
Windows PC
  └─ TigerVNC Viewer
       └─ encrypted SSH tunnel
            └─ Termux on Sanders
                 └─ Ubuntu PRoot
                      └─ XFCE desktop
```

TigerVNC listens only on the phone's local interface. The Windows computer reaches it through an SSH tunnel, so port `5901` is never exposed directly to the local network or internet.

## Documentation

- [Backup and recovery](docs/backup-and-restore.md) — full baseline, verification and rollback; complete before stability changes
- [Complete setup guide](docs/termux-proot-ubuntu-xfce-vnc-guide.md) — one-time installation, configuration, appearance, shortcuts, security notes, and troubleshooting
- [Daily quick-start guide](docs/sanders-ubuntu-gui-quick-start.md) — the short start, connect, and shutdown routine after setup

## Everyday workflow

1. Run `ugui` in Termux on Sanders.
2. Start the SSH tunnel from Windows.
3. Connect TigerVNC Viewer to `127.0.0.1::5901`.
4. When finished, close the viewer and tunnel, then run `uguistop` in Termux.

## Intended use

This GUI is useful for lightweight administration, file management, terminal work, editors, and occasional graphical Linux applications. It is not intended to turn the phone into a high-performance workstation or replace native Android system management.

For routine server work, SSH remains faster and more efficient. The GUI is an optional convenience layer that can be started only when needed.

## Security

- VNC is bound to localhost only.
- Remote connections should always use the documented SSH tunnel.
- Do not expose port `5901` directly on the LAN or internet.
- The GUI remains manually controlled and is not automatically started at boot.

## Platform

The documented setup uses:

- An unrooted Android phone
- Termux
- Ubuntu running through PRoot Distro
- XFCE
- TigerVNC Server and Viewer
- A Windows client connected over SSH
